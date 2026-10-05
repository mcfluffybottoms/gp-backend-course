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

// ----------- HEADER ----------- //
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

// ----------- QUESTION ----------- //
type DNSQuestion struct {
	QNAME  string
	QTYPE  string
	QCLASS string
}

func (q DNSQuestion) Print() {
	fmt.Printf("query %s %s \n", q.QNAME, q.QTYPE)
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

// ----------- QUERY ----------- //

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

func (q DNSquery) Send(server, port string, timeout time.Duration) ([]byte, error) {
	addr := net.JoinHostPort(server, port)
	conn, err := net.Dial("udp", addr)
	if err != nil {
		return nil, err
	}
	defer conn.Close()

	if err := conn.SetDeadline(time.Now().Add(timeout)); err != nil {
		return nil, err
	}

	header := q.Header.Encode()
	question := q.Question.Encode()
	query := append(header, question...)

	if _, err := conn.Write(query); err != nil {
		return nil, err
	}

	buf := make([]byte, 512)
	for {
		n, err := conn.Read(buf)
		if err != nil {
			return nil, err
		}

		var header DNSHeader
		if err := header.Decode(buf[:n]); err != nil {
			continue
		}

		if header.id != q.Header.id {
			continue
		}

		return buf[:n], nil
	}
}

// ----------- RESPONSE ----------- //

type DNSResponse struct {
	NAME           string
	TYPE           uint16
	CLASS          uint16
	TTL            uint32
	RDLENGTH       uint16
	RDATA_OFFSET   int
	originalPacket []byte
}

func (r DNSResponse) RDATA() []byte {
	return r.originalPacket[r.RDATA_OFFSET : r.RDATA_OFFSET+int(r.RDLENGTH)]
}

func readDNSName(bytes []byte, offset int) (int, string) {
	var name strings.Builder
	pos := offset
	nameEnd := -1
	for {
		if pos >= len(bytes) {
			return -1, "invalid DNS name"
		}

		labelSize := int(bytes[pos])

		if labelSize&0xC0 == 0xC0 {
			if pos >= len(bytes) {
				return -1, "invalid compression pointer"
			}
			pointer := int(labelSize&0x3F)<<8 | int(bytes[pos+1])
			if nameEnd == -1 {
				nameEnd = pos + 2
			}
			pos = pointer
			continue
		}

		if labelSize == 0x00 {
			if nameEnd == -1 {
				nameEnd = pos + 1
			}
			break
		}
		if labelSize > 63 {
			return -1, "invalid DNS label length"
		}
		if pos+1+labelSize > len(bytes) {
			return -1, "DNS label exceeds packet"
		}
		if name.Len() > 0 {
			name.WriteByte('.')
		}

		name.Write(bytes[pos+1 : pos+1+labelSize])
		pos += labelSize + 1
	}

	if name.Len() > 0 {
		name.WriteByte('.')
	}

	return nameEnd, name.String()
}

func NewDNSResponse(packet []byte, offset int) (DNSResponse, error) {
	pos, name := readDNSName(packet, offset)
	if pos == -1 {
		return DNSResponse{}, fmt.Errorf("%s", name)
	}

	if pos+10 > len(packet) {
		return DNSResponse{}, fmt.Errorf("DNS response too short")
	}

	typ := binary.BigEndian.Uint16(packet[pos : pos+2])
	clss := binary.BigEndian.Uint16(packet[pos+2 : pos+4])
	ttl := binary.BigEndian.Uint32(packet[pos+4 : pos+8])
	rdlength := binary.BigEndian.Uint16(packet[pos+8 : pos+10])

	return DNSResponse{
		NAME:           name,
		TYPE:           typ,
		CLASS:          clss,
		TTL:            ttl,
		RDLENGTH:       rdlength,
		RDATA_OFFSET:   pos + 10,
		originalPacket: packet,
	}, nil
}

func formatRData(recordType uint16, data DNSResponse) (string, string, error) {
	switch recordType {
	case 1:
		return "A", net.IP(data.RDATA()).String(), nil
	case 28:
		return "AAAA", net.IP(data.RDATA()).String(), nil
	case 5:
		pos, name := readDNSName(data.originalPacket, data.RDATA_OFFSET)
		if pos == -1 {
			return "", "", fmt.Errorf("Error while reading RDATA: %s", name)
		}
		return "CNAME", name, nil
	case 15:
		preference := binary.BigEndian.Uint16(data.RDATA()[:2])
		pos, name := readDNSName(data.originalPacket, data.RDATA_OFFSET+2)
		if pos == -1 {
			return "", "", fmt.Errorf("Error while reading RDATA: %s", name)
		}
		return "MX", fmt.Sprintf("%d %s", preference, name), nil
	case 16:
		rdata := data.RDATA()
		var parts strings.Builder
		pos := 0
		for pos < len(rdata) {
			length := int(rdata[pos])
			pos++
			if pos+length > len(rdata) {
				return "", "", fmt.Errorf("Error while reading RDATA: invalid TXT RDATA")
			}
			parts.Write(rdata[pos : pos+length])
			pos += length
		}
		return "TXT", parts.String(), nil
	case 2:
		pos, name := readDNSName(data.originalPacket, data.RDATA_OFFSET)
		if pos == -1 {
			return "", "", fmt.Errorf("Error while reading RDATA: %s", name)
		}
		return "NS", name, nil
	default:
		return "OTHER", fmt.Sprintf("%x", data.RDATA()), nil
	}
}

func (response DNSResponse) Print() {
	typ, ip, err := formatRData(response.TYPE, response)
	if err != nil {
		fmt.Fprintln(os.Stderr, "usage: run.sh <server> <port>")
		return
	}
	fmt.Printf("answer %s %s %d \n",
		typ,
		ip,
		response.TTL,
	)
}

func statusString(rcode byte) string {
	switch rcode {
	case 0:
		return "NOERROR"
	case 1:
		return "FORMERR"
	case 2:
		return "SERVFAIL"
	case 3:
		return "NXDOMAIN"
	case 4:
		return "NOTIMP"
	case 5:
		return "REFUSED"
	default:
		return fmt.Sprintf("RCODE%d", rcode)
	}
}

type CacheEntry struct {
	response  []byte
	expiresAt time.Time
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

	cache := make(map[DNSquery]CacheEntry)
	uniqueQueries := make(map[string]DNSquery)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}
		fields := strings.Fields(line)
		if len(fields) != 2 {
			fmt.Fprintf(os.Stderr, "Too much args in line %s -- skipping\n", line)
			continue
		}

		var query DNSquery
		if val, ok := uniqueQueries[line]; ok {
			query = val
		} else {
			query = NewDNSquery(uint16(rand.Uint32()), fields[0], fields[1])
			uniqueQueries[line] = query
		}
		queries = append(queries, query)
	}
	if scanner.Err() != nil {
		fmt.Fprintln(os.Stderr, scanner.Err().Error())
		os.Exit(1)
	}

	for _, query := range queries {
		query.Question.Print()
		var b []byte
		if val, ok := cache[query]; !ok || val.expiresAt.Before(time.Now()) {
			var err error
			b, err = query.Send(server, port, 5*time.Second)
			if err != nil {
				if netErr, ok := err.(net.Error); ok && netErr.Timeout() {
					fmt.Println("status TIMEOUT")
					fmt.Println("end")
					os.Exit(1)
				}

				fmt.Fprintln(os.Stderr, err)
				os.Exit(1)
			}
		} else {
			b = val.response
		}

		var header DNSHeader
		if err := header.Decode(b); err != nil {
			fmt.Fprintln(os.Stderr, err)
			return
		}
		fmt.Printf("status %s\n", statusString(header.RCODE))

		answerOffset := 12 + len(query.Question.Encode())
		var minTTL uint32 = 0
		haveTTL := false
		for range header.ANCount {
			response, err := NewDNSResponse(b, answerOffset)
			if err != nil {
				fmt.Fprintln(os.Stderr, err)
				return
			}
			response.Print()
			answerOffset = response.RDATA_OFFSET + int(response.RDLENGTH)

			if !haveTTL || response.TTL < minTTL {
				minTTL = response.TTL
				haveTTL = true
			}
		}

		if haveTTL && minTTL > 0 {
			cache[query] = CacheEntry{
				response:  b,
				expiresAt: time.Now().Add(time.Duration(minTTL) * time.Second),
			}
		}

		fmt.Printf("end\n")
	}
}
