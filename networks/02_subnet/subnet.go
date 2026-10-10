package main

import (
	"bufio"
	"fmt"
	"os"
	"strconv"
	"strings"
)

// IPv4

type IPv4 uint32

func (addr IPv4) prevAddress() IPv4 {
	return addr - 1
}

func (addr IPv4) nextAddress() IPv4 {
	return addr + 1
}

func (addr IPv4) String() string {
	ip := uint32(addr)
	return fmt.Sprintf("%d.%d.%d.%d", ip>>24, byte(ip>>16), byte(ip>>8), byte(ip))
}

func parseIPv4(arg string) (IPv4, error) {
	octetStrings := strings.Split(arg, ".")
	if len(octetStrings) != 4 {
		return 0, fmt.Errorf("Bad IPv4 for %s\n", arg)
	}

	var ip uint32
	for _, s := range octetStrings {
		for _, c := range s {
			if c < '0' || c > '9' {
				return 0, fmt.Errorf("Bad IPv4 for %s", s)
			}
		}
		n, err := strconv.Atoi(s)
		if err != nil || n < 0 || n > 255 {
			return 0, fmt.Errorf("Bad IPv4 for: %s\n", arg)
		}
		ip = (ip << 8) | uint32(n)
	}
	return IPv4(ip), nil
}

func parseCIDR(arg string) (IPv4, byte, error) {
	parts := strings.SplitN(arg, "/", 2)
	if len(parts) != 2 {
		return 0, 0, fmt.Errorf("Bad IPv4 for %s\n", arg)
	}

	ip, err := parseIPv4(parts[0])
	if err != nil {
		return 0, 0, err
	}

	prefix, err := strconv.Atoi(parts[1])
	if err != nil || prefix < 0 || prefix > 32 {
		return 0, 0, fmt.Errorf("Bad prefix %q", parts[1])
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
	fmt.Printf("network %s\n", a.network)
	fmt.Printf("broadcast %s\n", a.broadcast)
	fmt.Printf("netmask %s\n", a.netmask)
	fmt.Printf("prefix %d\n", a.prefix)
	fmt.Printf("first %s\n", a.first)
	fmt.Printf("last %s\n", a.last)
	fmt.Printf("hosts %d\n", a.hosts)
}

func getMask(prefix byte) (mask IPv4) {
	if prefix == 0 {
		return 0
	}
	return IPv4(^uint32(0) << (32 - prefix))
}

func GetNetwork(a IPv4, mask IPv4) (network IPv4) {
	return a & mask
}

func GetBroadcast(a IPv4, mask IPv4) (broadcast IPv4) {
	return a | ^mask
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
		fst = network.String()
		lst = fst
		hosts = 1
	case 31:
		bct = "none"
		fst = network.String()
		lst = network.nextAddress().String()
		hosts = 2
	default:
		broadcast := GetBroadcast(a, mask)
		hosts = uint64(1)<<uint(32-prefix) - 2
		bct = broadcast.String()
		fst = network.nextAddress().String()
		lst = broadcast.prevAddress().String()
	}

	return SubnetInfo{
		network:   network.String(),
		broadcast: bct,
		netmask:   mask.String(),
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
	m := getMask(r.prefix)
	return (r.ip & m) == (dst & m)
}

func GetBestRoute(ip IPv4, routes []route) (route, bool) {
	found := false
	best := route{}
	for _, r := range routes {
		if (!found || r.prefix > best.prefix) && matches(r, ip) {
			found = true
			best = r
		}
	}

	return best, found
}

// MAIN
func ExtractIPs(file string) ([]route, error) {
	f, err := os.Open(file)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	scanner := bufio.NewScanner(f)
	routes := make([]route, 0)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || line[0] == '#' {
			continue
		}
		routeStr := strings.Fields(line)
		if len(routeStr) != 2 {
			return nil, fmt.Errorf("bad route line: %q", line)
		}
		ip, prefix, err := parseCIDR(routeStr[0])
		if err != nil {
			return nil, fmt.Errorf("bad route line %q: %w", line, err)
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
		if len(args) < 2 {
			fmt.Fprintln(os.Stderr, "Not enough args for subnet")
			os.Exit(1)
		}
		a, err := AddressProps(args[1])
		if err != nil {
			fmt.Fprintln(os.Stderr, err.Error())
			os.Exit(1)
		}
		a.Print()
	case "route":
		if len(args) < 3 {
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
		} else {
			fmt.Println("unreachable true")
			os.Exit(1)
		}
	default:
		fmt.Fprintf(os.Stderr, "Command not supported: %s\n", args[0])
		os.Exit(1)
	}
}
