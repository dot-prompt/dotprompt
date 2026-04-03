package dotprompt

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"strings"
	"time"
)

type AsyncClient struct {
	transport *Transport
}

type ClientOptions struct {
	BaseURL    string
	APIKey     string
	Timeout    int
	MaxRetries int
}

func NewAsyncClient(opts ClientOptions) *AsyncClient {
	timeout := 30 * time.Second
	if opts.Timeout > 0 {
		timeout = time.Duration(opts.Timeout) * time.Second
	}
	t := NewTransport(TransportOptions{
		BaseURL:    opts.BaseURL,
		APIKey:     opts.APIKey,
		MaxRetries: opts.MaxRetries,
	})
	t.httpClient.Timeout = timeout
	return &AsyncClient{transport: t}
}

func (c *AsyncClient) Close() error {
	return nil
}

func (c *AsyncClient) ListPrompts(ctx context.Context) ([]string, error) {
	resp, err := c.transport.request(ctx, "GET", "/api/prompts", nil)
	if err != nil {
		return nil, err
	}

	prompts, ok := resp["prompts"].([]string)
	if !ok {
		if arr, ok := resp["prompts"].([]any); ok {
			prompts = make([]string, len(arr))
			for i, v := range arr {
				prompts[i] = fmt.Sprintf("%v", v)
			}
			return prompts, nil
		}
		return nil, fmt.Errorf("unexpected response format")
	}
	return prompts, nil
}

func (c *AsyncClient) ListCollections(ctx context.Context) ([]string, error) {
	resp, err := c.transport.request(ctx, "GET", "/api/collections", nil)
	if err != nil {
		return nil, err
	}

	collections, ok := resp["collections"].([]string)
	if !ok {
		if arr, ok := resp["collections"].([]any); ok {
			collections = make([]string, len(arr))
			for i, v := range arr {
				collections[i] = fmt.Sprintf("%v", v)
			}
			return collections, nil
		}
		return nil, fmt.Errorf("unexpected response format")
	}
	return collections, nil
}

func (c *AsyncClient) GetSchema(ctx context.Context, prompt string, major ...int) (*PromptSchema, error) {
	path := "/api/schema/" + prompt
	if len(major) > 0 && major[0] > 0 {
		path = fmt.Sprintf("/api/schema/%s/%d", prompt, major[0])
	}

	resp, err := c.transport.request(ctx, "GET", path, nil)
	if err != nil {
		return nil, err
	}

	var schema PromptSchema
	if err := mapToStruct(resp, &schema); err != nil {
		return nil, err
	}
	return &schema, nil
}

func (c *AsyncClient) Compile(ctx context.Context, prompt string, params map[string]any, opts ...CompileOptions) (*CompileResult, error) {
	body := map[string]any{
		"prompt": prompt,
		"params": params,
	}

	for _, o := range opts {
		if o.Seed != nil {
			body["seed"] = *o.Seed
		}
		if o.Major != nil {
			body["major"] = *o.Major
		}
	}

	resp, err := c.transport.request(ctx, "POST", "/api/compile", body)
	if err != nil {
		return nil, err
	}

	var result CompileResult
	if err := mapToStruct(resp, &result); err != nil {
		return nil, err
	}
	return &result, nil
}

type CompileOptions struct {
	Seed  *int
	Major *int
}

func (c *AsyncClient) Render(ctx context.Context, prompt string, params map[string]any, runtime map[string]any, opts ...CompileOptions) (*RenderResult, error) {
	body := map[string]any{
		"prompt":   prompt,
		"params":   params,
		"runtime":  runtime,
	}

	for _, o := range opts {
		if o.Seed != nil {
			body["seed"] = *o.Seed
		}
		if o.Major != nil {
			body["major"] = *o.Major
		}
	}

	resp, err := c.transport.request(ctx, "POST", "/api/render", body)
	if err != nil {
		return nil, err
	}

	var result RenderResult
	if err := mapToStruct(resp, &result); err != nil {
		return nil, err
	}
	return &result, nil
}

func (c *AsyncClient) Inject(ctx context.Context, template string, runtime map[string]string) (*InjectResult, error) {
	body := map[string]any{
		"template": template,
		"runtime":  runtime,
	}

	resp, err := c.transport.request(ctx, "POST", "/api/inject", body)
	if err != nil {
		return nil, err
	}

	var result InjectResult
	if err := mapToStruct(resp, &result); err != nil {
		return nil, err
	}
	return &result, nil
}

func (c *AsyncClient) ValidateResponse(response map[string]any, contract *ResponseContract) bool {
	properties := contract.Properties
	if properties == nil {
		properties = contract.Fields
	}

	for name, field := range properties {
		val, ok := response[name]
		if !ok {
			return false
		}

		expectedType := field.Type
		if !checkType(val, expectedType) {
			return false
		}
	}
	return true
}

func checkType(val any, typeStr string) bool {
	typeMap := map[string]string{
		"string":  "string",
		"number":  "float64",
		"integer": "int",
		"boolean": "bool",
		"array":   "array",
		"object":  "map",
		"null":    "nil",
	}

	expected, ok := typeMap[typeStr]
	if !ok {
		return true
	}

	switch expected {
	case "string":
		_, ok := val.(string)
		return ok
	case "float64":
		_, ok := val.(float64)
		return ok
	case "int":
		_, ok := val.(int)
		return ok
	case "bool":
		_, ok := val.(bool)
		return ok
	case "array":
		_, ok := val.([]any)
		return ok
	case "map":
		_, ok := val.(map[string]any)
		return ok
	case "nil":
		return val == nil
	}
	return true
}

func (c *AsyncClient) Events(ctx context.Context) <-chan DotPromptEvent {
	ch := make(chan DotPromptEvent, 10)

	go func() {
		defer close(ch)

		resp, err := c.transport.stream(ctx, "/api/events")
		if err != nil {
			return
		}
		defer resp.Body.Close()

		decoder := json.NewDecoder(resp.Body)
		for {
			select {
			case <-ctx.Done():
				return
			default:
			}

			var event DotPromptEvent
			if err := decoder.Decode(&event); err != nil {
				if err == io.EOF {
					return
				}
				return
			}
			ch <- event
		}
	}()

	return ch
}

type Event struct {
	Type      string `json:"type"`
	Timestamp int64  `json:"timestamp,omitempty"`
	Payload   any    `json:"payload,omitempty"`
	Prompt    string `json:"prompt,omitempty"`
}

func (e *Event) EventType() string {
	return e.Type
}

func mapToStruct(m map[string]any, v any) error {
	data, err := json.Marshal(m)
	if err != nil {
		return err
	}
	return json.Unmarshal(data, v)
}
