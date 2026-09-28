package main

import (
	"encoding/binary"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"strings"
)

func pop(q []byte) (byte, bool) {
	if len(q) == 0 {
		return 0, false
	}
	v := q[0]
	q = q[1:]
	return v, true
}

func skip(r rune) bool {
	switch r {
	case ' ', '\t', '\n', '\r', ':':
		return true
	}
	return false
}

// ETHERNET //

type ethernet struct {
	Dst       []byte
	Src       []byte
	EtherType uint16
}

func EthernetLevel(bytes []byte) (ethernet, error) {
	if len(bytes) < 14 {
		return ethernet{}, errors.New("not enough data for Ethernet header")
	}
	return ethernet{
		Dst:       bytes[0:6],
		Src:       bytes[6:12],
		EtherType: binary.BigEndian.Uint16(bytes[12:14]),
	}, nil
}

func (eth ethernet) Print() {
	fmt.Println("Ethernet:")
	fmt.Printf("  eth.dst       %02x:%02x:%02x:%02x:%02x:%02x\n",
		eth.Dst[0], eth.Dst[1], eth.Dst[2], eth.Dst[3], eth.Dst[4], eth.Dst[5])
	fmt.Printf("  eth.src       %02x:%02x:%02x:%02x:%02x:%02x\n",
		eth.Src[0], eth.Src[1], eth.Src[2], eth.Src[3], eth.Src[4], eth.Src[5])
	fmt.Printf("  eth.ethertype 0x%04x\n", eth.EtherType)
}

// IPv4 //

type IPv4 struct {
	version        byte
	ihl_bytes      byte
	total_length   uint16
	id             uint16
	flags          string
	frag_offset    uint16
	ttl            byte
	protocol       byte
	src            uint32
	dst            uint32
	checksum_valid bool
}

func verifyChecksum(header []byte) bool {
	if len(header)%2 != 0 {
		return false
	}
	var sum uint32
	for i := 0; i < len(header); i += 2 {
		sum += uint32(binary.BigEndian.Uint16(header[i : i+2]))
	}

	for sum>>16 != 0 {
		sum = (sum & 0xFFFF) + (sum >> 16)
	}
	return uint16(sum) == 0xFFFF
}

func IPv4Level(dump []byte) (IPv4, error) {
	if len(dump) < 20 {
		return IPv4{}, errors.New("not enough data for ip4 header")
	}
	bytes := dump[14:]

	DF := bytes[6]&64 != 0
	MF := bytes[6]&32 != 0
	var flag string
	if DF && MF {
		flag = "DF,MF"
	} else if DF {
		flag = "DF"
	} else if MF {
		flag = "MF"
	} else {
		flag = "none"
	}

	ihl_bytes := (bytes[0] & 0x0F) * 4
	frag_offset := (binary.BigEndian.Uint16(bytes[6:8]) & 0x1FFF) * 8

	src := binary.BigEndian.Uint32(bytes[12:16])
	dst := binary.BigEndian.Uint32(bytes[16:20])

	return IPv4{
		version:        (bytes[0] >> 4) & 0x0F,
		ihl_bytes:      ihl_bytes,
		total_length:   binary.BigEndian.Uint16(bytes[2:4]),
		id:             binary.BigEndian.Uint16(bytes[4:6]),
		flags:          flag,
		frag_offset:    frag_offset,
		ttl:            bytes[8],
		protocol:       bytes[9],
		src:            src,
		dst:            dst,
		checksum_valid: verifyChecksum(bytes[:ihl_bytes]),
	}, nil
}

func u32ToIP(v uint32) net.IP {
	return net.IPv4(byte(v>>24), byte(v>>16), byte(v>>8), byte(v))
}

func (ip IPv4) Print() {
	fmt.Println("IPv4:")
	fmt.Printf("  ip.version        %d\n", ip.version)
	fmt.Printf("  ip.ihl_bytes      %d\n", ip.ihl_bytes)
	fmt.Printf("  ip.total_length   %d\n", ip.total_length)
	fmt.Printf("  ip.id             0x%04x\n", ip.id)
	fmt.Printf("  ip.flags          %s\n", ip.flags)
	fmt.Printf("  ip.frag_offset    %d\n", ip.frag_offset)
	fmt.Printf("  ip.ttl            %d\n", ip.ttl)
	fmt.Printf("  ip.protocol       %d\n", ip.protocol)
	fmt.Printf("  ip.src            %s\n", u32ToIP(ip.src))
	fmt.Printf("  ip.dst            %s\n", u32ToIP(ip.dst))
	fmt.Printf("  ip.checksum_valid %t\n", ip.checksum_valid)
}

// transport level protocols //

type udp struct {
	src_port uint16
	dst_port uint16
	length   uint16
}

func UDPLevel(ip IPv4, dump []byte) (udp, error) {
	if ip.protocol != 17 {
		return udp{}, errors.New("ip.protocol != 17")
	}
	if len(dump) < 14+int(ip.ihl_bytes) {
		return udp{}, errors.New("not enough data for udp")
	}
	bytes := dump[14+ip.ihl_bytes:]
	return udp{
		src_port: binary.BigEndian.Uint16(bytes[:2]),
		dst_port: binary.BigEndian.Uint16(bytes[2:4]),
		length:   binary.BigEndian.Uint16(bytes[4:6]),
	}, nil
}

func (udp udp) Print() {
	fmt.Println("UDP:")
	fmt.Printf("  udp.src_port      %d\n", udp.src_port)
	fmt.Printf("  udp.dst_port      %d\n", udp.dst_port)
	fmt.Printf("  udp.length        %d\n", udp.length)
}

type tcp struct {
	src_port          uint16
	dst_port          uint16
	seq               uint32
	ack               uint32
	data_offset_bytes byte
	flags             string
	window            uint16
}

func TCPLevel(ip IPv4, dump []byte) (tcp, error) {
	if ip.protocol != 6 {
		return tcp{}, errors.New("ip.protocol != 6")
	}
	if len(dump) < 14+int(ip.ihl_bytes) {
		return tcp{}, errors.New("not enough data for tcp")
	}
	bytes := dump[14+ip.ihl_bytes:]

	URG := bytes[13]&32 != 0
	ACK := bytes[13]&16 != 0
	PSH := bytes[13]&8 != 0
	RST := bytes[13]&4 != 0
	SYN := bytes[13]&2 != 0
	FIN := bytes[13]&1 != 0
	var parts []string
	if FIN {
		parts = append(parts, "FIN")
	}
	if SYN {
		parts = append(parts, "SYN")
	}
	if RST {
		parts = append(parts, "RST")
	}
	if PSH {
		parts = append(parts, "PSH")
	}
	if ACK {
		parts = append(parts, "ACK")
	}
	if URG {
		parts = append(parts, "URG")
	}
	flags := strings.Join(parts, ",")

	return tcp{
		src_port:          binary.BigEndian.Uint16(bytes[:2]),
		dst_port:          binary.BigEndian.Uint16(bytes[2:4]),
		seq:               binary.BigEndian.Uint32(bytes[4:8]),
		ack:               binary.BigEndian.Uint32(bytes[8:12]),
		data_offset_bytes: (bytes[12] & 0xf0) / 4,
		flags:             flags,
		window:            binary.BigEndian.Uint16(bytes[14:16]),
	}, nil
}

func (tcp tcp) Print() {
	fmt.Println("TCP:")
	fmt.Printf("  tcp.src_port          %d\n", tcp.src_port)
	fmt.Printf("  tcp.dst_port          %d\n", tcp.dst_port)
	fmt.Printf("  tcp.seq               %d\n", tcp.seq)
	fmt.Printf("  tcp.ack               %d\n", tcp.ack)
	fmt.Printf("  tcp.data_offset_bytes %d\n", tcp.data_offset_bytes)
	fmt.Printf("  tcp.flags             %s\n", tcp.flags)
	fmt.Printf("  tcp.window            %d\n", tcp.window)
}

func (udp udp) PrintPayload(dump int, ip IPv4) {
	fmt.Printf("  payload.length        %d\n", int(ip.total_length)-int(ip.ihl_bytes)-8)
}
func (tcp tcp) PrintPayload(dump int, ip IPv4) {
	fmt.Printf("  payload.length        %d\n", int(ip.total_length)-int(ip.ihl_bytes)-int(tcp.data_offset_bytes))
}

// MAIN //

func main() {
	bytes := make([]byte, 0)
	args, err := io.ReadAll(os.Stdin)
	if err != nil {
		fmt.Fprintln(os.Stderr, "read stdin:", err)
		os.Exit(1)
	}

	cleaned := strings.Map(func(r rune) rune {
		if !skip(r) {
			return r
		}
		return -1
	}, string(args))
	raw, err := hex.DecodeString(cleaned)
	if err != nil {
		fmt.Fprintln(os.Stderr, "bad hex:", cleaned)
		os.Exit(1)
	}
	bytes = append(bytes, raw...)

	// ethernet
	ethernet, err := EthernetLevel(bytes)
	if err != nil {
		fmt.Fprintln(os.Stderr, "ethernet:", err.Error())
		os.Exit(1)
	}
	ethernet.Print()

	// IPv4
	if ethernet.EtherType != 0x0800 {
		return
	}

	ip4, err := IPv4Level(bytes)
	if err != nil {
		fmt.Fprintln(os.Stderr, "ip4:", err.Error())
		os.Exit(1)
	}
	ip4.Print()

	// transport level protocols
	switch ip4.protocol {
	case 6:
		tcp, err := TCPLevel(ip4, bytes)
		tcp.Print()
		if err != nil {
			fmt.Fprintln(os.Stderr, "protocol:", err.Error())
			os.Exit(1)
		}
		tcp.PrintPayload(len(bytes), ip4)
	case 17:
		udp, err := UDPLevel(ip4, bytes)
		udp.Print()
		if err != nil {
			fmt.Fprintln(os.Stderr, "protocol:", err.Error())
			os.Exit(1)
		}
		udp.PrintPayload(len(bytes), ip4)
	}
}
