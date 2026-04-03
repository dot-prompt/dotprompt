package dotprompt

import (
	"context"
	"encoding/json"
	"io"
)

type EventStream struct {
	decoder *json.Decoder
}

func NewEventStream(resp io.Reader) *EventStream {
	return &EventStream{
		decoder: json.NewDecoder(resp),
	}
}

func (es *EventStream) Next() (*DotPromptEvent, error) {
	var event DotPromptEvent
	if err := es.decoder.Decode(&event); err != nil {
		return nil, err
	}
	return &event, nil
}

func CreateEventStream(ctx context.Context, baseURL string, apiKey string) (<-chan DotPromptEvent, error) {
	transport := NewTransport(TransportOptions{
		BaseURL: baseURL,
		APIKey:  apiKey,
	})

	resp, err := transport.stream(ctx, "/api/events")
	if err != nil {
		return nil, err
	}

	ch := make(chan DotPromptEvent, 10)

	go func() {
		defer resp.Body.Close()
		defer close(ch)

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

	return ch, nil
}
