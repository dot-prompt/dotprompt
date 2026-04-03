package dotprompt

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

type Transport struct {
	baseURL    string
	apiKey     string
	timeout    time.Duration
	maxRetries int
	httpClient *http.Client
}

type TransportOptions struct {
	BaseURL    string
	APIKey     string
	Timeout    time.Duration
	MaxRetries int
}

func NewTransport(opts TransportOptions) *Transport {
	if opts.BaseURL == "" {
		opts.BaseURL = "http://localhost:4041"
	}
	if opts.Timeout == 0 {
		opts.Timeout = 30 * time.Second
	}
	if opts.MaxRetries == 0 {
		opts.MaxRetries = 3
	}

	return &Transport{
		baseURL:    strings.TrimRight(opts.BaseURL, "/"),
		apiKey:     opts.APIKey,
		timeout:    opts.Timeout,
		maxRetries: opts.MaxRetries,
		httpClient: &http.Client{Timeout: opts.Timeout},
	}
}

func (t *Transport) request(ctx context.Context, method, path string, body any) (map[string]any, error) {
	var reqBody io.Reader
	if body != nil {
		jsonBody, err := json.Marshal(body)
		if err != nil {
			return nil, fmt.Errorf("failed to marshal request body: %w", err)
		}
		reqBody = strings.NewReader(string(jsonBody))
	}

	url := t.baseURL + path
	var req *http.Request
	var err error

	if reqBody != nil {
		req, err = http.NewRequestWithContext(ctx, method, url, reqBody)
	} else {
		req, err = http.NewRequestWithContext(ctx, method, url, nil)
	}
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	if t.apiKey != "" {
		req.Header.Set("Authorization", "Bearer "+t.apiKey)
	}

	var lastErr error
	for attempt := 0; attempt <= t.maxRetries; attempt++ {
		if attempt > 0 {
			sleepDuration := time.Duration(1<<uint(attempt-1)) * 200 * time.Millisecond
			time.Sleep(sleepDuration)
		}

		resp, err := t.httpClient.Do(req)
		if err != nil {
			lastErr = err
			if ctx.Err() != nil {
				return nil, ctx.Err()
			}
			continue
		}
		defer resp.Body.Close()

		if resp.StatusCode >= 400 {
			return nil, t.handleError(resp)
		}

		var result map[string]any
		if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
			return nil, fmt.Errorf("failed to decode response: %w", err)
		}
		return result, nil
	}

	return nil, fmt.Errorf("request failed after %d attempts: %w", t.maxRetries+1, lastErr)
}

func (t *Transport) handleError(resp *http.Response) error {
	status := resp.StatusCode
	body, _ := io.ReadAll(resp.Body)
	message := string(body)

	var errType string
	var errMsg string
	if len(body) > 0 {
		var errData map[string]any
		if json.Unmarshal(body, &errData) == nil {
			if v, ok := errData["error"].(string); ok {
				errType = v
			}
			if v, ok := errData["message"].(string); ok {
				errMsg = v
			}
		}
	}

	if errMsg == "" {
		errMsg = message
	}
	if errMsg == "" {
		errMsg = "Unknown error"
	}

	switch status {
	case 404:
		return &PromptNotFoundError{PromptName: path, Message: errMsg}
	case 422:
		if strings.Contains(errMsg, "missing") || strings.Contains(errMsg, "required") {
			return &MissingRequiredParamsError{Message: errMsg}
		}
		return &ValidationError{Message: errMsg}
	case 500, 502, 503:
		return &ServerError{StatusCode: status, Message: errMsg}
	default:
		return &APIClientError{StatusCode: status, Message: errMsg}
	}
}

func (t *Transport) stream(ctx context.Context, path string) (*http.Response, error) {
	url := t.baseURL + path
	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
	if err != nil {
		return nil, err
	}

	if t.apiKey != "" {
		req.Header.Set("Authorization", "Bearer "+t.apiKey)
	}

	resp, err := t.httpClient.Do(req)
	if err != nil {
		return nil, err
	}

	if resp.StatusCode >= 400 {
		return nil, t.handleError(resp)
	}

	return resp, nil
}
