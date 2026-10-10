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
	version       byte
	ihlBytes      byte
	totalLength   uint16
	id            uint16
	flags         string
	fragOffset    uint16
	ttl           byte
	protocol      byte
	src           uint32
	dst           uint32
	checksumValid bool
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
	if len(dump) < 20+14 {
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

	ihlBytes := (bytes[0] & 0x0F) * 4
	if ihlBytes < 20 {
		return IPv4{}, errors.New("invalid ip4 header length")
	}
	if len(dump) < 14+int(ihlBytes) {
		return IPv4{}, errors.New("not enough data for full ip4 header")
	}

	fragOffset := (binary.BigEndian.Uint16(bytes[6:8]) & 0x1FFF) * 8

	src := binary.BigEndian.Uint32(bytes[12:16])
	dst := binary.BigEndian.Uint32(bytes[16:20])

	return IPv4{
		version:       (bytes[0] >> 4) & 0x0F,
		ihlBytes:      ihlBytes,
		totalLength:   binary.BigEndian.Uint16(bytes[2:4]),
		id:            binary.BigEndian.Uint16(bytes[4:6]),
		flags:         flag,
		fragOffset:    fragOffset,
		ttl:           bytes[8],
		protocol:      bytes[9],
		src:           src,
		dst:           dst,
		checksumValid: verifyChecksum(bytes[:ihlBytes]),
	}, nil
}

func u32ToIP(v uint32) net.IP {
	return net.IPv4(byte(v>>24), byte(v>>16), byte(v>>8), byte(v))
}

func (ip IPv4) Print() {
	fmt.Println("IPv4:")
	fmt.Printf("  ip.version        %d\n", ip.version)
	fmt.Printf("  ip.ihl_bytes      %d\n", ip.ihlBytes)
	fmt.Printf("  ip.total_length   %d\n", ip.totalLength)
	fmt.Printf("  ip.id             0x%04x\n", ip.id)
	fmt.Printf("  ip.flags          %s\n", ip.flags)
	fmt.Printf("  ip.frag_offset    %d\n", ip.fragOffset)
	fmt.Printf("  ip.ttl            %d\n", ip.ttl)
	fmt.Printf("  ip.protocol       %d\n", ip.protocol)
	fmt.Printf("  ip.src            %s\n", u32ToIP(ip.src))
	fmt.Printf("  ip.dst            %s\n", u32ToIP(ip.dst))
	fmt.Printf("  ip.checksum_valid %t\n", ip.checksumValid)
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
	if len(dump) < 14+int(ip.ihlBytes)+8 {
		return udp{}, errors.New("not enough data for udp")
	}
	bytes := dump[14+ip.ihlBytes:]
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
	srcPort         uint16
	dstPort         uint16
	seq             uint32
	ack             uint32
	dataOffsetBytes byte
	flags           string
	window          uint16
}

func TCPLevel(ip IPv4, dump []byte) (tcp, error) {
	if ip.protocol != 6 {
		return tcp{}, errors.New("ip.protocol != 6")
	}

	tcpStart := 14 + int(ip.ihlBytes)

	if len(dump) < tcpStart+20 {
		return tcp{}, errors.New("not enough data for tcp")
	}

	bytes := dump[tcpStart:]

	dataOffsetBytes := (bytes[12] & 0xf0) / 4
	if dataOffsetBytes < 20 {
		return tcp{}, errors.New("invalid tcp data offset")
	}

	if len(bytes) < int(dataOffsetBytes) {
		return tcp{}, errors.New("not enough data for full tcp header")
	}

	b := bytes[13]
	names := []string{"FIN", "SYN", "RST", "PSH", "ACK", "URG"}
	var parts []string
	for i, name := range names {
		if b&(1<<i) != 0 {
			parts = append(parts, name)
		}
	}
	flags := strings.Join(parts, ",")

	return tcp{
		srcPort:         binary.BigEndian.Uint16(bytes[:2]),
		dstPort:         binary.BigEndian.Uint16(bytes[2:4]),
		seq:             binary.BigEndian.Uint32(bytes[4:8]),
		ack:             binary.BigEndian.Uint32(bytes[8:12]),
		dataOffsetBytes: dataOffsetBytes,
		flags:           flags,
		window:          binary.BigEndian.Uint16(bytes[14:16]),
	}, nil
}

func (tcp tcp) Print() {
	fmt.Println("TCP:")
	fmt.Printf("  tcp.src_port          %d\n", tcp.srcPort)
	fmt.Printf("  tcp.dst_port          %d\n", tcp.dstPort)
	fmt.Printf("  tcp.seq               %d\n", tcp.seq)
	fmt.Printf("  tcp.ack               %d\n", tcp.ack)
	fmt.Printf("  tcp.data_offset_bytes %d\n", tcp.dataOffsetBytes)
	fmt.Printf("  tcp.flags             %s\n", tcp.flags)
	fmt.Printf("  tcp.window            %d\n", tcp.window)
}

func PrintPayload(ip IPv4, transportHeaderLen int) {
	headerLen := int(ip.ihlBytes) + 8
	payloadLen := int(ip.totalLength) - headerLen
	if payloadLen < 0 {
		fmt.Println("  payload.length        -12")
		return
	}
	fmt.Printf("  payload.length        %d\n", int(ip.totalLength)-int(ip.ihlBytes)-transportHeaderLen)
}

// MAIN //

func main() {
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
	bytes, err := hex.DecodeString(cleaned)
	if err != nil {
		fmt.Fprintln(os.Stderr, "bad hex:", cleaned)
		os.Exit(1)
	}

	// ethernet
	eth, err := EthernetLevel(bytes)
	if err != nil {
		fmt.Fprintln(os.Stderr, "ethernet:", err.Error())
		os.Exit(1)
	}
	eth.Print()

	// IPv4
	if eth.EtherType != 0x0800 {
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
		t, err := TCPLevel(ip4, bytes)
		if err != nil {
			fmt.Fprintln(os.Stderr, "protocol:", err.Error())
			os.Exit(1)
		}
		t.Print()
		PrintPayload(ip4, int(t.dataOffsetBytes))
	case 17:
		u, err := UDPLevel(ip4, bytes)
		if err != nil {
			fmt.Fprintln(os.Stderr, "protocol:", err.Error())
			os.Exit(1)
		}
		u.Print()
		PrintPayload(ip4, 8)
	default:
		PrintPayload(ip4, 0)
	}
}
