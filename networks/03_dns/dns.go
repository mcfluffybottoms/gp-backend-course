package main

import (
	"bufio"
	"encoding/binary"
	"errors"
	"fmt"
	"math/rand/v2"
	"net"
	"os"
	"strings"
	"time"
)

const dnsHeaderSize = 12

// ----------- HEADER ----------- //
type DNSHeader struct {
	id     uint16
	qr     bool
	opcode byte
	aa     bool
	tc     bool
	rd     bool
	ra     bool
	// Z = 0
	rCODE   byte
	qCount  uint16
	anCount uint16
	nsCOUNT uint16
	arCOUNT uint16
}

func NewDNSHeader(id uint16, qCount uint16) DNSHeader {
	return DNSHeader{
		id:     id,
		qr:     false,
		opcode: 0,
		rd:     true,
		qCount: qCount,
	}
}

func (h DNSHeader) packFlags() uint16 {
	var f uint16
	if h.qr {
		f |= 1 << 15
	}
	f |= uint16(h.opcode&0x0F) << 11
	if h.aa {
		f |= 1 << 10
	}
	if h.tc {
		f |= 1 << 9
	}
	if h.rd {
		f |= 1 << 8
	}
	if h.ra {
		f |= 1 << 7
	}

	f |= uint16(h.rCODE & 0x0F)
	return f
}

func (h DNSHeader) Encode() []byte {
	buf := make([]byte, dnsHeaderSize)
	binary.BigEndian.PutUint16(buf[0:2], h.id)
	binary.BigEndian.PutUint16(buf[2:4], h.packFlags())
	binary.BigEndian.PutUint16(buf[4:6], h.qCount)
	binary.BigEndian.PutUint16(buf[6:8], h.anCount)
	binary.BigEndian.PutUint16(buf[8:10], h.nsCOUNT)
	binary.BigEndian.PutUint16(buf[10:12], h.arCOUNT)
	return buf
}

func (h *DNSHeader) Decode(buf []byte) error {
	if len(buf) < dnsHeaderSize {
		return fmt.Errorf("header needs 12 bytes, got %d", len(buf))
	}
	h.id = binary.BigEndian.Uint16(buf[0:2])
	flags := binary.BigEndian.Uint16(buf[2:4])
	h.qr = flags&(1<<15) != 0
	h.opcode = byte((flags >> 11) & 0x0F)
	h.aa = flags&(1<<10) != 0
	h.tc = flags&(1<<9) != 0
	h.rd = flags&(1<<8) != 0
	h.ra = flags&(1<<7) != 0
	h.rCODE = byte(flags & 0x0F)
	h.qCount = binary.BigEndian.Uint16(buf[4:6])
	h.anCount = binary.BigEndian.Uint16(buf[6:8])
	h.nsCOUNT = binary.BigEndian.Uint16(buf[8:10])
	h.arCOUNT = binary.BigEndian.Uint16(buf[10:12])
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

func typeToUint16(t string) (uint16, error) {
	switch strings.ToUpper(t) {
	case "A":
		return 1, nil
	case "NS":
		return 2, nil
	case "CNAME":
		return 5, nil
	case "MX":
		return 15, nil
	case "TXT":
		return 16, nil
	case "AAAA":
		return 28, nil
	default:
		return 0, fmt.Errorf("unsupported DNS type %q", t)
	}
}

func classToUint16(c string) (uint16, error) {
	switch strings.ToUpper(c) {
	case "", "IN":
		return 1, nil
	default:
		return 0, fmt.Errorf("unsupported DNS class %q", c)
	}
}

func encodeDNSName(name string) ([]byte, error) {
	name = strings.TrimSuffix(name, ".")
	if name == "" {
		return []byte{0x00}, nil
	}
	var out []byte
	for _, label := range strings.Split(name, ".") {
		if label == "" || len(label) > 63 {
			return nil, fmt.Errorf("invalid DNS name %q", name)
		}
		out = append(out, byte(len(label)))
		out = append(out, label...)
	}
	out = append(out, 0x00)
	if len(out) > 255 {
		return nil, errors.New("DNS name exceeds 255 bytes")
	}
	return out, nil
}

func (q DNSQuestion) Encode() ([]byte, error) {
	name, err := encodeDNSName(q.QNAME)
	if err != nil {
		return nil, err
	}
	typ, err := typeToUint16(q.QTYPE)
	if err != nil {
		return nil, err
	}
	class, err := classToUint16(q.QCLASS)
	if err != nil {
		return nil, err
	}
	out := append([]byte{}, name...)
	var tail [4]byte
	binary.BigEndian.PutUint16(tail[0:2], typ)
	binary.BigEndian.PutUint16(tail[2:4], class)
	out = append(out, tail[:]...)
	return out, nil
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

func (q DNSquery) cacheKey() string {
	return strings.ToLower(strings.TrimSuffix(q.Question.QNAME, ".")) + "|" + strings.ToUpper(q.Question.QTYPE) + "|IN"
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
	question, err := q.Question.Encode()
	if err != nil {
		return nil, err
	}
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
		if n < dnsHeaderSize {
			continue
		}
		var header DNSHeader
		if err := header.Decode(buf[:n]); err != nil {
			continue
		}
		if header.id != q.Header.id || !header.qr {
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

func (r *DNSResponse) RDATA() []byte {
	if r == nil || r.RDATA_OFFSET < 0 || r.RDATA_OFFSET+int(r.RDLENGTH) > len(r.originalPacket) {
		return nil
	}
	return r.originalPacket[r.RDATA_OFFSET : r.RDATA_OFFSET+int(r.RDLENGTH)]
}

func readDNSName(bytes []byte, offset int) (int, string, error) {
	if offset < 0 || offset >= len(bytes) {
		return 0, "", errors.New("DNS name offset out of bounds")
	}
	pos := offset
	nameEnd := -1
	jumps := 0
	labels := make([]string, 0, 4)
	for {
		if pos < 0 || pos >= len(bytes) {
			return 0, "", errors.New("truncated DNS name")
		}
		length := int(bytes[pos])
		if length&0xC0 == 0xC0 {
			if pos+1 >= len(bytes) {
				return 0, "", errors.New("truncated compression pointer")
			}
			pointer := (length&0x3F)<<8 | int(bytes[pos+1])
			if pointer >= len(bytes) {
				return 0, "", errors.New("DNS compression pointer out of bounds")
			}
			if nameEnd < 0 {
				nameEnd = pos + 2
			}
			pos = pointer
			jumps++
			if jumps > len(bytes) {
				return 0, "", errors.New("DNS compression pointer loop")
			}
			continue
		}
		if length&0xC0 != 0 {
			return 0, "", errors.New("invalid DNS label type")
		}
		pos++
		if length == 0 {
			if nameEnd < 0 {
				nameEnd = pos
			}
			break
		}
		if length > 63 || pos+length > len(bytes) {
			return 0, "", errors.New("invalid or truncated DNS label length")
		}
		if length+1 > 255 {
			return 0, "", errors.New("DNS name exceeds 255 bytes")
		}
		labels = append(labels, string(bytes[pos:pos+length]))
		pos += length
	}
	return nameEnd, strings.Join(labels, "."), nil
}

func NewDNSResponse(packet []byte, offset int) (*DNSResponse, error) {
	pos, name, err := readDNSName(packet, offset)
	if err != nil {
		return nil, err
	}
	if pos < 0 || pos+10 > len(packet) {
		return nil, fmt.Errorf("DNS response truncated")
	}
	typ := binary.BigEndian.Uint16(packet[pos : pos+2])
	clss := binary.BigEndian.Uint16(packet[pos+2 : pos+4])
	ttl := binary.BigEndian.Uint32(packet[pos+4 : pos+8])
	rdlength := binary.BigEndian.Uint16(packet[pos+8 : pos+10])
	rdataOffset := pos + 10
	if rdataOffset+int(rdlength) > len(packet) {
		return nil, errors.New("DNS RDATA exceeds packet")
	}
	return &DNSResponse{NAME: name, TYPE: typ, CLASS: clss, TTL: ttl, RDLENGTH: rdlength, RDATA_OFFSET: rdataOffset, originalPacket: packet}, nil
}

func formatRData(recordType uint16, data *DNSResponse) (string, string, error) {
	rdata := data.RDATA()
	switch recordType {
	case 1:
		if len(rdata) != 4 {
			return "", "", errors.New("invalid A record length")
		}
		return "A", net.IP(rdata).String(), nil
	case 28:
		if len(rdata) != 16 {
			return "", "", errors.New("invalid AAAA record length")
		}
		return "AAAA", net.IP(rdata).String(), nil
	case 2, 5:
		_, name, err := readDNSName(data.originalPacket, data.RDATA_OFFSET)
		if err != nil {
			return "", "", fmt.Errorf("Error while reading RDATA: %s", name)
		}
		if recordType == 2 {
			return "NS", name + ".", nil
		}
		return "CNAME", name + ".", nil
	case 15:
		if len(rdata) < 3 {
			return "", "", errors.New("invalid MX RDATA length")
		}
		preference := binary.BigEndian.Uint16(rdata[:2])
		_, name, err := readDNSName(data.originalPacket, data.RDATA_OFFSET+2)
		if err != nil {
			return "", "", fmt.Errorf("Error while reading RDATA: %s", name)
		}
		return "MX", fmt.Sprintf("%d %s.", preference, name), nil
	case 16:
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
	default:
		return "", "", nil
	}
}

func (r *DNSResponse) Print() error {
	typ, value, err := formatRData(r.TYPE, r)
	if err != nil {
		return err
	}
	fmt.Printf("answer %s %s %d\n", typ, value, r.TTL)
	return nil
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

func processQuery(query DNSquery, server, port string, cache map[string]CacheEntry) bool {
	query.Question.Print()
	key := query.cacheKey()
	var packet []byte
	if entry, ok := cache[key]; ok && time.Now().Before(entry.expiresAt) {
		packet = append([]byte(nil), entry.response...)
	} else {
		delete(cache, key)
		var err error
		packet, err = query.Send(server, port, 5*time.Second)
		if err != nil {
			var netErr net.Error
			if errors.As(err, &netErr) && netErr.Timeout() {
				fmt.Println("status TIMEOUT")
				fmt.Println("end")
				return true
			}
			fmt.Fprintln(os.Stderr, err)
			fmt.Println("status ERROR")
			fmt.Println("end")
			return false
		}
	}

	var header DNSHeader
	if err := header.Decode(packet); err != nil {
		fmt.Fprintln(os.Stderr, err)
		fmt.Println("status ERROR")
		fmt.Println("end")
		return false
	}
	fmt.Printf("status %s\n", statusString(header.rCODE))

	offset := dnsHeaderSize
	for i := 0; i < int(header.qCount); i++ {
		nameEnd, _, err := readDNSName(packet, offset)
		if err != nil || nameEnd+4 > len(packet) {
			if err == nil {
				err = errors.New("truncated DNS question")
			}
			fmt.Fprintln(os.Stderr, err)
			fmt.Println("end")
			return false
		}
		offset = nameEnd + 4
	}

	minTTL := uint32(0)
	haveTTL := false
	answerCount := 0
	for i := 0; i < int(header.anCount); i++ {
		record, err := NewDNSResponse(packet, offset)
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			fmt.Println("end")
			return false
		}
		answerCount++
		if record.TYPE == 1 || record.TYPE == 2 || record.TYPE == 5 || record.TYPE == 15 || record.TYPE == 16 || record.TYPE == 28 {
			if err := record.Print(); err != nil {
				fmt.Fprintln(os.Stderr, err)
			}
		}
		offset = record.RDATA_OFFSET + int(record.RDLENGTH)
		if !haveTTL || record.TTL < minTTL {
			minTTL = record.TTL
			haveTTL = true
		}
	}
	if header.rCODE == 0 && answerCount > 0 && haveTTL && minTTL > 0 {
		cache[key] = CacheEntry{response: append([]byte(nil), packet...), expiresAt: time.Now().Add(time.Duration(minTTL) * time.Second)}
	}
	fmt.Println("end")
	return false
}

func main() {
	if len(os.Args) < 3 {
		fmt.Fprintln(os.Stderr, "usage: run.sh <server> <port>")
		os.Exit(2)
	}
	server := os.Args[1]
	port := os.Args[2]
	scanner := bufio.NewScanner(os.Stdin)
	scanner.Buffer(make([]byte, 1024), 1024*1024)
	cache := make(map[string]CacheEntry)
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
		if _, err := typeToUint16(fields[1]); err != nil {
			fmt.Fprintf(os.Stderr, "%v\n", err)
			continue
		}
		query := NewDNSquery(uint16(rand.Uint32()), fields[0], fields[1])
		if _, err := query.Question.Encode(); err != nil {
			fmt.Fprintln(os.Stderr, err)
			continue
		}
		if processQuery(query, server, port, cache) {
			os.Exit(1)
		}
	}
	if err := scanner.Err(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
