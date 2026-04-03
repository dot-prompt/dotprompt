package dotprompt

import (
	"context"
	"sync"
)

type Client struct {
	asyncClient *AsyncClient
	eventChan   chan DotPromptEvent
	mu          sync.Mutex
}

func NewClient(opts ...ClientOptions) *Client {
	var clientOpts ClientOptions
	if len(opts) > 0 {
		clientOpts = opts[0]
	}

	return &Client{
		asyncClient: NewAsyncClient(clientOpts),
		eventChan:   make(chan DotPromptEvent, 10),
	}
}

func (c *Client) ListPrompts(ctx context.Context) ([]string, error) {
	return c.asyncClient.ListPrompts(ctx)
}

func (c *Client) ListCollections(ctx context.Context) ([]string, error) {
	return c.asyncClient.ListCollections(ctx)
}

func (c *Client) GetSchema(ctx context.Context, prompt string, major ...int) (*PromptSchema, error) {
	return c.asyncClient.GetSchema(ctx, prompt, major...)
}

func (c *Client) Compile(ctx context.Context, prompt string, params map[string]any, opts ...CompileOptions) (*CompileResult, error) {
	return c.asyncClient.Compile(ctx, prompt, params, opts...)
}

func (c *Client) Render(ctx context.Context, prompt string, params map[string]any, runtime map[string]any, opts ...CompileOptions) (*RenderResult, error) {
	return c.asyncClient.Render(ctx, prompt, params, runtime, opts...)
}

func (c *Client) Inject(ctx context.Context, template string, runtime map[string]string) (*InjectResult, error) {
	return c.asyncClient.Inject(ctx, template, runtime)
}

func (c *Client) ValidateResponse(response map[string]any, contract *ResponseContract) bool {
	return c.asyncClient.ValidateResponse(response, contract)
}

func (c *Client) Events(ctx context.Context) <-chan DotPromptEvent {
	return c.asyncClient.Events(ctx)
}

func (c *Client) Close() error {
	return c.asyncClient.Close()
}
