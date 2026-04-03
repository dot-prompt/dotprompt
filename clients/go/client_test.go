package dotprompt

import (
	"testing"
)

func TestNewClient(t *testing.T) {
	client := NewClient()
	if client == nil {
		t.Error("expected non-nil client")
	}
}

func TestNewAsyncClient(t *testing.T) {
	client := NewAsyncClient(ClientOptions{})
	if client == nil {
		t.Error("expected non-nil async client")
	}
}

func TestClientOptions(t *testing.T) {
	opts := ClientOptions{
		BaseURL:    "http://localhost:4041",
		APIKey:     "test-key",
		Timeout:    30,
		MaxRetries: 3,
	}

	if opts.BaseURL != "http://localhost:4041" {
		t.Errorf("expected BaseURL to be set, got %s", opts.BaseURL)
	}
}

func TestCompileOptions(t *testing.T) {
	seed := 42
	major := 1
	opts := CompileOptions{
		Seed:  &seed,
		Major: &major,
	}

	if *opts.Seed != 42 {
		t.Errorf("expected Seed to be 42, got %d", *opts.Seed)
	}
	if *opts.Major != 1 {
		t.Errorf("expected Major to be 1, got %d", *opts.Major)
	}
}

func TestCheckType(t *testing.T) {
	tests := []struct {
		name     string
		val      any
		typeStr  string
		expected bool
	}{
		{"string type", "hello", "string", true},
		{"string type fail", 123, "string", false},
		{"number type", 3.14, "number", true},
		{"boolean type", true, "boolean", true},
		{"array type", []any{1, 2}, "array", true},
		{"object type", map[string]any{"a": 1}, "object", true},
		{"null type", nil, "null", true},
		{"unknown type", "foo", "unknown", true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := checkType(tt.val, tt.typeStr)
			if result != tt.expected {
				t.Errorf("checkType(%v, %s) = %v, want %v", tt.val, tt.typeStr, result, tt.expected)
			}
		})
	}
}
