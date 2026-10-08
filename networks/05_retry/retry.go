package main

import (
	"errors"
	"fmt"
	"math/rand/v2"
	"net"
	"net/http"
	"os"
	"strconv"
	"time"
)

type Interval struct {
	baseInterval int
	multiplier int
	upperBound int
}
var interval = Interval{
	baseInterval: 100,
	multiplier:   2,
	upperBound:   1000,
}
func (i Interval) duration(n int) int {
	result := 200
	for i := 1; i < n; i++ {
		result *= 2
		if result >= 2000 {
			return 2000
		}
	}
	return rand.IntN(result + 1)
}

type HttpRequest struct {
	Url string
	Method string
	MaxAttempts int
	IdempotencyKey string
}

func (req *HttpRequest) ifNeedToRerun(prevAttempt Attempt) bool {
    if req.Method == "POST" && req.IdempotencyKey == "" {
        return false
    }

    var netErr net.Error
    status := prevAttempt.Response.StatusCode
    return prevAttempt.Attempt < prevAttempt.Request.MaxAttempts &&
        (errors.As(prevAttempt.err, &netErr) ||
            status == 429 ||
            status == 500 ||
            status == 502 ||
            status == 503 ||
            status == 504)
}

type Attempt struct {
	Request HttpRequest
	Response http.Response
	Attempt int
	SleepMs time.Duration
	err error
}

func (a Attempt) Print() {
	if a.err != nil {
		fmt.Printf("attempt %d error %s\n", a.Attempt, a.err.Error())
	} else {
		fmt.Printf("attempt %d status %d\n", a.Attempt, a.Response.StatusCode)
	}
	if a.Request.ifNeedToRerun(a) && a.Attempt < a.Request.MaxAttempts {
		fmt.Printf("sleep_ms %d\n", a.SleepMs.Milliseconds())
	}
}

func (a Attempt) isSuccessful() bool {
	return a.err == nil && a.Response.StatusCode >= 200 && a.Response.StatusCode <= 399
}

func (req HttpRequest) send(interval Interval, attempt int) Attempt {
	request, err := http.NewRequest(req.Method, req.Url, nil)
	if err != nil {
		return Attempt{ Request: req, Attempt: attempt + 1, err: err }
	}
	if req.IdempotencyKey != "" {
		request.Header.Set("Idempotency-Key", req.IdempotencyKey)
	}
	client := &http.Client{
		Timeout: 5 * time.Second,
	}

	var netErr net.Error
	resp, err := client.Do(request)
	if err != nil && errors.As(err, &netErr) {
		sleepMs := interval.duration(attempt)
		return Attempt{ Request: req, Attempt: attempt + 1, SleepMs: time.Millisecond * time.Duration(sleepMs), err: err }
	} else if err != nil {
		return Attempt{ Request: req, Attempt: attempt + 1, err: err }
	}

	var sleepMs int
	if value := resp.Header.Get("Retry-After"); value != "" {
		seconds, err := strconv.Atoi(value)
		if err != nil {
			return Attempt{ Request: req, Attempt: attempt + 1, err: err }
		}
		sleepMs = seconds * 1000
	} else {
		sleepMs = interval.duration(attempt)
	}

	return Attempt{
		Request: req,
		Response: *resp,
		Attempt: attempt + 1,
		SleepMs: time.Millisecond * time.Duration(sleepMs),
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

	request := HttpRequest {
		Url: args[0],
		Method: method,
		MaxAttempts: maxAttempts,
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