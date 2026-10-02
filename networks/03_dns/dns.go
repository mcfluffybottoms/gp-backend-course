package main

import (
	"bufio"
	"encoding/binary"
	"fmt"
	"math/rand/v2"
	"net"
	"os"
	"strings"
	"time"
)

// header

type DNSHeader struct {
	id     uint16
	qr     bool
	opcode byte
	AA     bool
	TC     bool
	RD     bool
	RA     bool
	// Z = 0
	RCODE   byte
	QCount  uint16
	ANCount uint16
	NSCOUNT uint16
	ARCOUNT uint16
}

func NewDNSHeader(id uint16, qCount uint16) DNSHeader {
	return DNSHeader{
		id:     id,
		qr:     false,
		opcode: 0,
		RD:     true,
		QCount: qCount,
	}
}

func (h DNSHeader) packFlags() uint16 {
	var f uint16
	if h.qr {
		f |= 1 << 15
	}
	f |= uint16(h.opcode&0x0F) << 11
	if h.AA {
		f |= 1 << 10
	}
	if h.TC {
		f |= 1 << 9
	}
	if h.RD {
		f |= 1 << 8
	}
	if h.RA {
		f |= 1 << 7
	}

	f |= uint16(h.RCODE & 0x0F)
	return f
}

func (h DNSHeader) Encode() []byte {
	buf := make([]byte, 12)
	binary.BigEndian.PutUint16(buf[0:2], h.id)
	binary.BigEndian.PutUint16(buf[2:4], h.packFlags())
	binary.BigEndian.PutUint16(buf[4:6], h.QCount)
	binary.BigEndian.PutUint16(buf[6:8], h.ANCount)
	binary.BigEndian.PutUint16(buf[8:10], h.NSCOUNT)
	binary.BigEndian.PutUint16(buf[10:12], h.ARCOUNT)
	return buf
}

func (h *DNSHeader) Decode(buf []byte) error {
	if len(buf) < 12 {
		return fmt.Errorf("header needs 12 bytes, got %d", len(buf))
	}
	h.id = binary.BigEndian.Uint16(buf[0:2])
	flags := binary.BigEndian.Uint16(buf[2:4])
	h.qr = flags&(1<<15) != 0
	h.opcode = byte((flags >> 11) & 0x0F)
	h.AA = flags&(1<<10) != 0
	h.TC = flags&(1<<9) != 0
	h.RD = flags&(1<<8) != 0
	h.RA = flags&(1<<7) != 0
	h.RCODE = byte(flags & 0x0F)
	h.QCount = binary.BigEndian.Uint16(buf[4:6])
	h.ANCount = binary.BigEndian.Uint16(buf[6:8])
	h.NSCOUNT = binary.BigEndian.Uint16(buf[8:10])
	h.ARCOUNT = binary.BigEndian.Uint16(buf[10:12])
	return nil
}

// encode
type DNSQuestion struct {
	QNAME  string
	QTYPE  string
	QCLASS string
}

func NewDNSQuestion(url string, typ string) DNSQuestion {
	return DNSQuestion{
		QNAME:  url,
		QTYPE:  typ,
		QCLASS: "IN",
	}
}

func typeToUint16(t string) uint16 {
	switch strings.ToUpper(t) {
	case "A":
		return 1
	case "NS":
		return 2
	case "CNAME":
		return 5
	case "SOA":
		return 6
	case "PTR":
		return 12
	case "MX":
		return 15
	case "TXT":
		return 16
	case "AAAA":
		return 28
	default:
		return 1
	}
}

func classToUint16(c string) uint16 {
	switch strings.ToUpper(c) {
	case "", "IN":
		return 1
	default:
		return 1
	}
}

func (q DNSQuestion) Encode() []byte {
	name := strings.TrimSuffix(q.QNAME, ".")
	if name == "" {
		return []byte{0x00}
	}
	var buf []byte
	for _, label := range strings.Split(name, ".") {
		buf = append(buf, byte(len(label)))
		buf = append(buf, label...)
	}
	buf = append(buf, 0x00)

	buf = append(buf, 0x00, 0x00, 0x00, 0x00)
	nameBuf := len(buf) - 4
	binary.BigEndian.PutUint16(buf[nameBuf:], typeToUint16(q.QTYPE))
	binary.BigEndian.PutUint16(buf[nameBuf+2:], classToUint16(q.QCLASS))
	return buf
}

// func (q DNSQuestion) Decode(buf []byte) error {

// 	return nil
// }

// query
type DNSquery struct {
	Header   DNSHeader
	Question DNSQuestion
}

func NewDNSquery(id uint16, url, typ string) DNSquery {
	return DNSquery{
		Header:   NewDNSHeader(id, 1),
		Question: NewDNSQuestion(url, typ),
	}
}

func (q DNSquery) Send(server string, port string, timeout time.Duration) ([]byte, error) {
	addr := net.JoinHostPort(server, port)
	conn, err := net.Dial("udp", addr)
	if err != nil {
		return nil, fmt.Errorf("dial %s: %w", server, err)
	}
	defer conn.Close()

	if err := conn.SetDeadline(time.Now().Add(timeout)); err != nil {
		return nil, err
	}

	header := q.Header.Encode()
	question := q.Question.Encode()
	query := append(header, question...)

	if _, err := conn.Write(query); err != nil {
		return nil, fmt.Errorf("write: %w", err)
	}

	buf := make([]byte, 512)
	n, err := conn.Read(buf)
	if err != nil {
		return nil, fmt.Errorf("read: %w", err)
	}
	return buf[:n], nil
}

// url string, typ string
type response struct {
	NAME     string
	TYPE     uint16
	CLASS    uint16
	TTL      uint32
	RDLENGTH uint16
	RDATA    []byte
}

func main() {
	if len(os.Args) < 3 {
		fmt.Fprintln(os.Stderr, "usage: run.sh <server> <port>")
		os.Exit(2)
	}
	server := os.Args[1]
	port := os.Args[2]

	scanner := bufio.NewScanner(os.Stdin)
	queries := make([]DNSquery, 0)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}
		fields := strings.Fields(line)
		if len(fields) != 2 {
			fmt.Fprintf(os.Stderr, "Too much args in line %s -- skipping\n", line)
		}
		queries = append(queries, NewDNSquery(uint16(rand.Uint32()), fields[0], fields[1]))
	}
	if scanner.Err() != nil {
		fmt.Fprintln(os.Stderr, scanner.Err().Error())
		os.Exit(1)
	}

	b, err := queries[0].Send(server, port, 5*time.Second)
	// cache := make(map[string]response)
	if err != nil {
		fmt.Fprintln(os.Stderr, err.Error())
		os.Exit(1)
	}
	fmt.Println(b)
}
