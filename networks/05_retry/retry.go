package main

import (
	"errors"
	"fmt"
	"io"
	"math/rand/v2"
	"net"
	"net/http"
	"net/url"
	"os"
	"strconv"
	"strings"
	"time"
)

type Interval struct {
	baseInterval int
	multiplier   int
	upperBound   int
}

var interval = Interval{
	baseInterval: 100,
	multiplier:   2,
	upperBound:   1000,
}

func (i *Interval) duration(n int) int {
	result := i.baseInterval

	for attempt := 1; attempt < n; attempt++ {
		if result >= i.upperBound/i.multiplier {
			result = i.upperBound
			break
		}
		result *= i.multiplier
	}

	return rand.IntN(result + 1)
}

type HttpRequest struct {
	Url            string
	Method         string
	MaxAttempts    int
	IdempotencyKey string
}

func (req *HttpRequest) ifNeedToRerun(prevAttempt Attempt) bool {
	if strings.EqualFold(req.Method, "POST") && req.IdempotencyKey == "" {
		return false
	}

	var netErr net.Error
	status := prevAttempt.StatusCode
	return prevAttempt.Attempt < prevAttempt.Request.MaxAttempts &&
		(errors.As(prevAttempt.err, &netErr) ||
			errors.Is(prevAttempt.err, io.ErrUnexpectedEOF) ||
			status == 429 ||
			status == 500 ||
			status == 502 ||
			status == 503 ||
			status == 504)
}

type Attempt struct {
	Request    HttpRequest
	StatusCode int
	Attempt    int
	SleepMs    time.Duration
	err        error
}

func (a Attempt) Print() {
	if a.err != nil {
		fmt.Printf("attempt %d error %s\n", a.Attempt, a.err.Error())
	} else {
		fmt.Printf("attempt %d status %d\n", a.Attempt, a.StatusCode)
	}
}

func (a Attempt) isSuccessful() bool {
	return a.err == nil && a.StatusCode >= 200 && a.StatusCode <= 399
}

func (req HttpRequest) send(interval Interval, attempt int) Attempt {
	request, err := http.NewRequest(req.Method, req.Url, nil)
	if err != nil {
		return Attempt{Request: req, Attempt: attempt + 1, err: err}
	}
	if req.IdempotencyKey != "" {
		request.Header.Set("Idempotency-Key", req.IdempotencyKey)
	}
	request.Close = true

	client := &http.Client{
		Timeout: 5 * time.Second,
	}

	var urlErr *url.Error
	var netErr net.Error
	resp, err := client.Do(request)
	if err != nil {
		if errors.As(err, &urlErr) && errors.As(urlErr.Err, &netErr) {
			sleepMs := interval.duration(attempt)
			return Attempt{
				Request: req,
				Attempt: attempt + 1,
				SleepMs: time.Millisecond * time.Duration(sleepMs),
				err:     err,
			}
		}
		return Attempt{
			Request: req,
			Attempt: attempt + 1,
			err:     err,
		}
	}
	_, copyErr := io.Copy(io.Discard, resp.Body)
	if copyErr != nil {
		if errors.Is(copyErr, io.ErrUnexpectedEOF) {
			sleepMs := interval.duration(attempt)
			return Attempt{
				Request: req,
				Attempt: attempt + 1,
				SleepMs: time.Millisecond * time.Duration(sleepMs),
				err:     copyErr,
			}
		}

		return Attempt{
			Request: req,
			Attempt: attempt + 1,
			err:     copyErr,
		}
	}

	closeErr := resp.Body.Close()
	if closeErr != nil {
		return Attempt{
			Request:    req,
			StatusCode: resp.StatusCode,
			Attempt:    attempt + 1,
			err:        closeErr,
		}
	}

	var sleepMs int
	if value := resp.Header.Get("Retry-After"); value != "" {
		seconds, err := strconv.Atoi(value)
		if err != nil || seconds < 0 {
			sleepMs = interval.duration(attempt)
		} else {
			sleepMs = seconds * 1000
		}
	} else {
		sleepMs = interval.duration(attempt)
	}

	return Attempt{
		Request:    req,
		StatusCode: resp.StatusCode,
		Attempt:    attempt + 1,
		SleepMs:    time.Millisecond * time.Duration(sleepMs),
	}
}

func (req HttpRequest) SendWithRetry(interval Interval) Attempt {
	var attempt Attempt
	for i := range req.MaxAttempts {
		attempt = req.send(interval, i)
		attempt.Print()
		if !req.ifNeedToRerun(attempt) {
			return attempt
		}

		fmt.Printf("sleep_ms %d\n", attempt.SleepMs.Milliseconds())
		time.Sleep(attempt.SleepMs)
	}
	return attempt
}

func main() {
	args := os.Args[1:]

	if len(args) < 1 {
		fmt.Fprintf(os.Stderr, "No url present\n")
		os.Exit(1)
	}

	method := "GET"
	idempotencyKey := ""
	maxAttempts := 5

	if strings.HasPrefix(args[0], "-") {
		fmt.Fprintf(os.Stderr, "No url present\n")
		os.Exit(1)
	}

	u, err := url.Parse(args[0])
	if err != nil {
		fmt.Fprintf(os.Stderr, "invalid http URL: %w\n", err)
		os.Exit(1)
	}

	if u.Scheme != "http" {
		fmt.Fprintf(os.Stderr, "only http URLs are supported\n")
		os.Exit(1)
	}

	if u.Host == "" {
		fmt.Fprintf(os.Stderr, "URL must include a host\n")
		os.Exit(1)
	}

	for i := 1; i < len(args); i++ {
		switch args[i] {
		case "--method":
			if i+1 >= len(args) {
				fmt.Fprintln(os.Stderr, "--method has no args to use")
				os.Exit(1)
			}
			method = args[i+1]
			i++

		case "--max-attempts":
			if i+1 >= len(args) {
				fmt.Fprintln(os.Stderr, "--max-attempts has no args to use")
				os.Exit(1)
			}

			val, err := strconv.Atoi(args[i+1])
			if err != nil {
				fmt.Fprintf(
					os.Stderr,
					"Error while reading max-attempts: %s\n",
					err,
				)
				os.Exit(1)
			}

			if val < 1 {
				fmt.Fprintf(
					os.Stderr,
					"max-attempts should be bigger than 0\n",
				)
				os.Exit(1)
			}

			maxAttempts = val
			i++

		case "--idempotency-key":
			if i+1 >= len(args) {
				fmt.Fprintln(os.Stderr, "--idempotency-key has no args to use")
				os.Exit(1)
			}

			idempotencyKey = args[i+1]
			i++

		default:
			fmt.Fprintf(
				os.Stderr,
				"Argument %s not supported -- skipping\n",
				args[i],
			)
		}
	}

	request := HttpRequest{
		Url:            args[0],
		Method:         method,
		MaxAttempts:    maxAttempts,
		IdempotencyKey: idempotencyKey,
	}

	lastAttempt := request.SendWithRetry(interval)
	if lastAttempt.isSuccessful() {
		fmt.Printf("result success attempts %d\n", lastAttempt.Attempt)
	} else {
		fmt.Printf("result failure attempts %d\n", lastAttempt.Attempt)
		os.Exit(1)
	}
}
