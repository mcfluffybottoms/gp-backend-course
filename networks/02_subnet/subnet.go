package main

import (
	"bufio"
	"errors"
	"fmt"
	"os"
	"strconv"
	"strings"
)

// IPv4

type IPv4 struct {
	data [4]byte
}

func (addr IPv4) prevAddress() IPv4 {
	prev := addr
	prev.data[3]--
	for i := 2; i >= 0 && prev.data[i+1] == 0; i-- {
		prev.data[i]--
	}
	return prev
}

func (addr IPv4) nextAddress() IPv4 {
	next := addr
	next.data[3]++
	for i := 2; i >= 0 && next.data[i+1] == 0; i-- {
		next.data[i]++
	}
	return next
}

func (addr IPv4) ToString() string {
	return fmt.Sprintf("%d.%d.%d.%d", addr.data[0], addr.data[1], addr.data[2], addr.data[3])
}

func parseIPv4(arg string) (IPv4, error) {
	octetStrings := strings.Split(arg, ".")
	if len(octetStrings) != 4 {
		return IPv4{}, fmt.Errorf("bad IPv4 for %s\n", arg)
	}

	var ip [4]byte
	for i, s := range octetStrings {
		n, err := strconv.Atoi(s)
		if err != nil || n < 0 || n > 255 {
			return IPv4{}, fmt.Errorf("Incorrect ip format for %s\n", arg)
		}
		ip[i] = byte(n)
	}
	return IPv4{data: ip}, nil
}

func parseCIDR(arg string) (IPv4, byte, error) {
	parts := strings.SplitN(arg, "/", 2)
	if len(parts) != 2 {
		return IPv4{}, 0, fmt.Errorf("Incorrect ip format for %s\n", arg)
	}

	ip, err := parseIPv4(parts[0])
	if err != nil {
		return IPv4{}, 0, err
	}

	prefix, err := strconv.Atoi(parts[1])
	if err != nil || prefix < 0 || prefix > 32 {
		return IPv4{}, 0, errors.New("bad prefix")
	}
	return ip, byte(prefix), nil
}

// GET SUBNET INFO

type SubnetInfo struct {
	network   string
	broadcast string
	netmask   string
	prefix    byte
	first     string
	last      string
	hosts     uint64
}

func (a SubnetInfo) Print() {
	fmt.Printf("network   %s\n", a.network)
	fmt.Printf("broadcast %s\n", a.broadcast)
	fmt.Printf("netmask   %s\n", a.netmask)
	fmt.Printf("prefix    %d\n", a.prefix)
	fmt.Printf("first     %s\n", a.first)
	fmt.Printf("last      %s\n", a.last)
	fmt.Printf("hosts     %d\n", a.hosts)
}

func getMask(prefix byte) (mask IPv4) {
	for i := range 4 {
		bitsHere := int(prefix) - i*8
		switch {
		case bitsHere >= 8:
			mask.data[i] = 0xFF
		case bitsHere <= 0:
			mask.data[i] = 0x00
		default:
			mask.data[i] = byte(0xff << (8 - bitsHere))
		}
	}
	return mask
}

func GetNetwork(a IPv4, mask IPv4) (network IPv4) {
	for i := range 4 {
		network.data[i] = a.data[i] & mask.data[i]
	}
	return network
}

func GetBroadcast(a IPv4, mask IPv4) (broadcast IPv4) {
	for i := range 4 {
		broadcast.data[i] = (a.data[i] & mask.data[i]) | ^mask.data[i]
	}
	return broadcast
}

func AddressProps(arg string) (SubnetInfo, error) {
	a, prefix, err := parseCIDR(arg)
	if err != nil {
		return SubnetInfo{}, err
	}

	mask := getMask(prefix)

	network := GetNetwork(a, mask)

	var bct, fst, lst string
	var hosts uint64
	switch prefix {
	case 32:
		bct = "none"
		fst = network.ToString()
		lst = fst
		hosts = 1
	case 31:
		bct = "none"
		fst = network.ToString()
		lst = network.nextAddress().ToString()
		hosts = 2
	default:
		broadcast := GetBroadcast(a, mask)
		hosts = uint64(1)<<uint(32-prefix) - 2
		bct = broadcast.ToString()
		fst = network.nextAddress().ToString()
		lst = broadcast.prevAddress().ToString()
	}

	return SubnetInfo{
		network:   network.ToString(),
		broadcast: bct,
		netmask:   mask.ToString(),
		prefix:    prefix,
		first:     fst,
		last:      lst,
		hosts:     hosts,
	}, nil
}

// ROUTE
type route struct {
	ip     IPv4
	prefix byte
	eth    string
}

func matches(r route, dst IPv4) bool {
	m := getMask(r.prefix).data
	for i := range 4 {
		if r.ip.data[i]&m[i] != dst.data[i]&m[i] {
			return false
		}
	}
	return true
}

func GetBestRoute(ip IPv4, routes []route) (route, bool) {
	found := false
	route := route{}
	for _, r := range routes {
		if (!found || r.prefix > route.prefix) && matches(r, ip) {
			found = true
			route = r
		}
	}

	return route, found
}

// MAIN
func ExtractIPs(file string) ([]route, error) {
	f, err := os.Open(file)
	if err != nil {
		return make([]route, 0), err
	}

	scanner := bufio.NewScanner(f)
	routes := make([]route, 0)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || line[0] == '#' {
			continue
		}
		routeStr := strings.Fields(line)
		if len(routeStr) != 2 {
			return make([]route, 0), fmt.Errorf("bad route line: %q", line)
		}
		ip, prefix, err := parseCIDR(routeStr[0])
		if err != nil {
			return make([]route, 0), fmt.Errorf("incorrect ip: %q", line)
		}
		routes = append(routes, route{
			ip:     ip,
			prefix: prefix,
			eth:    routeStr[1],
		})
	}
	if err := scanner.Err(); err != nil {
		return nil, err
	}
	return routes, nil
}

func main() {
	args := os.Args[1:]
	// fmt.Println(args)
	fmt.Fprintf(os.Stderr, "%q\n", args)
	if len(args) < 1 {
		fmt.Fprintln(os.Stderr, "Not enough args")
		os.Exit(1)
	}

	switch args[0] {
	case "subnet":
		a, err := AddressProps(args[1])
		if err != nil {
			fmt.Fprintln(os.Stderr, err.Error())
			os.Exit(1)
		}
		a.Print()
	case "route":
		if len(args) < 2 {
			fmt.Fprintln(os.Stderr, "Not enough args")
			os.Exit(1)
		}

		ip, err := parseIPv4(args[2])
		if err != nil {
			fmt.Fprintln(os.Stderr, err.Error())
			os.Exit(1)
		}
		routes, err := ExtractIPs(args[1])
		if err != nil {
			fmt.Fprintln(os.Stderr, err.Error())
			os.Exit(1)
		}

		route, found := GetBestRoute(ip, routes)
		if found {
			fmt.Printf("via %s\n", route.eth)
			fmt.Printf("prefix %d\n", route.prefix)
			os.Exit(0)
		} else {
			fmt.Println("unreachable true")
			os.Exit(1)
		}
	default:
		fmt.Fprintf(os.Stderr, "Command not supported: %s\n", args[0])
		os.Exit(1)
	}
}
