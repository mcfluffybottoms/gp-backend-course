package main

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"strconv"
	"strings"
)

type ParseErrorType int

const (
	bad_start_line ParseErrorType = iota
	bad_header
	incomplete_body
	bad_chunk
)

type HttpParseError struct {
	line string
	typ  ParseErrorType
}

func (e HttpParseError) Error() string {
	switch e.typ {
	case bad_start_line:
		return "bad_start_line"
	case bad_header:
		return "bad_header"
	case incomplete_body:
		return "incomplete_body"
	case bad_chunk:
		return "bad_chunk"
	default:
		return "unknown"
	}
}

type Header struct {
	name  string
	value string
}

type Http struct {
	typ     string
	method  string
	target  string
	version string

	status int
	reason string

	headers          []Header
	headerOptions    map[string]string
	transferEncoding string
	contentLength    int
	content          []byte
}

func (r *Http) applyFirstLine(requestLine string) *HttpParseError {
	parts := strings.SplitN(requestLine, " ", 3)

	if len(parts) != 3 {
		return &HttpParseError{
			line: fmt.Sprintf("len(parts) != 3: %s", requestLine),
			typ:  bad_start_line,
		}
	}

	if parts[0] == "HTTP/1.1" {
		status, err := strconv.Atoi(parts[1])
		if err != nil {
			return &HttpParseError{
				line: fmt.Sprintf("status should be a number: %s", requestLine),
				typ:  bad_start_line,
			}
		}

		r.typ = "response"
		r.version = parts[0]
		r.status = status
		r.reason = parts[2]

		return nil
	}

	if strings.TrimSpace(parts[2]) != "HTTP/1.1" {
		return &HttpParseError{
			line: fmt.Sprintf("Wrong version in request: %s, got %s", requestLine, parts[2]),
			typ:  bad_start_line,
		}
	}

	r.typ = "request"
	r.method = parts[0]
	r.target = parts[1]
	r.version = parts[2]

	return nil
}

func (r *Http) applyLine(line string) *HttpParseError {
	parts := strings.SplitN(line, ":", 2)

	if len(parts) != 2 {
		return &HttpParseError{
			line: fmt.Sprintf("header line of wrong format: %s", line),
			typ:  bad_header,
		}
	}

	name := strings.ToLower(parts[0])
	value := strings.TrimSpace(parts[1])

	if name == "" {
		return &HttpParseError{
			line: fmt.Sprintf("name is empty: %s", line),
			typ:  bad_header,
		}
	}

	r.headers = append(r.headers, Header{
		name:  name,
		value: value,
	})

	if name == "content-length" {
		n, err := strconv.Atoi(value)
		if err != nil || n < 0 {
			return &HttpParseError{
				line: fmt.Sprintf("content-length of wrong format: %s,\n error text: %s", line, err.Error()),
				typ:  bad_header,
			}
		}

		r.contentLength = n
	}

	if name == "transfer-encoding" {
		r.transferEncoding = strings.ToLower(value)
	}

	return nil
}

func (request *Http) ReadHeaderFromStream(r *bufio.Reader) *HttpParseError {
	line, err := r.ReadString('\n')
	if err != nil {
		return &HttpParseError{
			line: fmt.Sprintf("error while reading start line: %s", err.Error()),
			typ:  bad_start_line,
		}
	}

	fmt.Printf("DEBUG: %q\n", line)
	if !strings.HasSuffix(line, "\r\n") {
		return &HttpParseError{
			line: fmt.Sprintf("line without carriage return is rejected: %s", line),
			typ:  bad_start_line,
		}
	}

	line = strings.TrimSuffix(line, "\r\n")

	if err := request.applyFirstLine(line); err != nil {
		return err
	}

	for {
		line, err := r.ReadString('\n')
		if err == io.EOF {
			break
		}
		if err != nil {
			return &HttpParseError{
				line: fmt.Sprintf("error while reading header line: %s", err.Error()),
				typ:  bad_header,
			}
		}

		if !strings.HasSuffix(line, "\r\n") {
			return &HttpParseError{
				line: fmt.Sprintf("line without carriage return is rejected: %s", line),
				typ:  bad_header,
			}
		}

		line = strings.TrimSpace(line)

		if line == "" {
			break
		}

		if err := request.applyLine(line); err != nil {
			return err
		}
	}

	return nil
}

func (request *Http) readChunkedBody(r *bufio.Reader) *HttpParseError {
	for {
		line, err := r.ReadString('\n')
		if err != nil {
			return &HttpParseError{
				line: fmt.Sprintf("error while reading chunk: %s", err.Error()),
				typ:  bad_chunk,
			}
		}

		if !strings.HasSuffix(line, "\r\n") {
			return &HttpParseError{
				line: fmt.Sprintf("line without carriage return is rejected: %s", line),
				typ:  bad_header,
			}
		}

		line = strings.TrimSuffix(line, "\r\n")

		sizeText, _, _ := strings.Cut(line, ";")

		size, err := strconv.ParseUint(sizeText, 16, 64)
		if err != nil {
			return &HttpParseError{
				line: fmt.Sprintf("error while parsing chunk size: %s", err.Error()),
				typ:  bad_chunk,
			}
		}

		if size == 0 {
			for {
				line, err := r.ReadString('\n')
				if err != nil {
					return &HttpParseError{
						line: fmt.Sprintf("error while reading chunk content: %s", err.Error()),
						typ:  bad_chunk,
					}
				}

				// if !strings.HasSuffix(line, "\r\n") {
				// 	return &HttpParseError{
				// 		line: fmt.Sprintf("error while parsing chunk size: %s", err.Error()),
				// 		typ:  bad_chunk,
				// 	}
				// }

				line = strings.TrimSuffix(line, "\r\n")

				if line == "" {
					return nil
				}
			}
		}

		chunk := make([]byte, int(size))

		_, err = io.ReadFull(r, chunk)
		if err != nil {
			return &HttpParseError{
				line: fmt.Sprintf("error while reading chunk: %s", err.Error()),
				typ:  bad_chunk,
			}
		}

		line, err = r.ReadString('\n')
		if err != nil {
			return &HttpParseError{
				line: fmt.Sprintf("error while reading chunk: %s", err.Error()),
				typ:  bad_chunk,
			}
		}

		// if line != "\r\n" {
		// 	return &HttpParseError{
		// 		line: fmt.Sprintf("error while reading chunk content: %s", err.Error()),
		// 		typ:  bad_chunk,
		// 	}
		// }

		request.content = append(request.content, chunk...)
	}
}

func (request *Http) ReadContentFromStream(r *bufio.Reader) *HttpParseError {
	if request.transferEncoding == "chunked" {
		return request.readChunkedBody(r)
	}

	if request.contentLength == 0 {
		return nil
	}

	request.content = make([]byte, request.contentLength)

	_, err := io.ReadFull(r, request.content)
	if err != nil {
		return &HttpParseError{
			line: fmt.Sprintf("error while reading body: %s", err.Error()),
			typ:  incomplete_body,
		}
	}

	return nil
}

func CreateHttp(r *bufio.Reader) (Http, *HttpParseError) {
	request := &Http{}
	err := request.ReadHeaderFromStream(r)
	if err != nil {
		return Http{}, err
	}
	err = request.ReadContentFromStream(r)
	if err != nil {
		return Http{}, err
	}
	return *request, nil
}

func isPrintable(content []byte) bool {
	for _, b := range content {
		if b < 32 || b > 126 {
			return false
		}
	}
	return true
}

func (r *Http) Print() {
	fmt.Printf("type %s\n", r.typ)

	if r.typ == "request" {
		fmt.Printf("method %s\n", r.method)
		fmt.Printf("target %s\n", r.target)
	} else {
		fmt.Printf("status %d\n", r.status)
		fmt.Printf("reason %s\n", r.reason)
	}

	fmt.Printf("version %s\n", r.version)

	for _, h := range r.headers {
		fmt.Printf("header %s %s\n", h.name, h.value)
	}

	fmt.Printf("body.length %d\n", len(r.content))

	if len(r.content) > 0 && isPrintable(r.content) {
		fmt.Printf("body.text %s\n", r.content)
	}
}

func main() {
	stream := bufio.NewReader(os.Stdin)

	r, err := CreateHttp(stream)
	if err != nil {
		fmt.Fprintln(os.Stdout, "error", err.Error())
		fmt.Fprintln(os.Stderr, err.line)
		os.Exit(1)
	}

	r.Print()
}
