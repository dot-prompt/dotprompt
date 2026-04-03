package dotprompt

type ContractField struct {
	Type     string `json:"type"`
	Doc      string `json:"doc,omitempty"`
	Required bool   `json:"required,omitempty"`
	Default  any    `json:"default,omitempty"`
}

type ResponseContract struct {
	Type       string                    `json:"type,omitempty"`
	Properties map[string]ContractField  `json:"properties,omitempty"`
	Fields     map[string]ContractField  `json:"fields,omitempty"`
	Compatible bool                      `json:"compatible,omitempty"`
}

type ParamSpec struct {
	Type      string `json:"type"`
	Lifecycle string `json:"lifecycle,omitempty"`
	Doc       string `json:"doc,omitempty"`
	Default   any    `json:"default,omitempty"`
	Values    []any  `json:"values,omitempty"`
	Range     []any  `json:"range,omitempty"`
}

type FragmentSpec struct {
	Type     string `json:"type"`
	Doc      string `json:"doc,omitempty"`
	FromPath string `json:"from_path,omitempty"`
}

type PromptSchema struct {
	Name        string                    `json:"name"`
	Version     int                       `json:"version"`
	Description string                    `json:"description,omitempty"`
	Mode        string                    `json:"mode,omitempty"`
	Docs        string                    `json:"docs,omitempty"`
	Params      map[string]ParamSpec     `json:"params,omitempty"`
	Fragments   map[string]FragmentSpec `json:"fragments,omitempty"`
	Contract    *ResponseContract        `json:"contract,omitempty"`
}

type CompileResult struct {
	Template         string          `json:"template"`
	CacheHit         bool            `json:"cache_hit"`
	CompiledTokens   int             `json:"compiled_tokens"`
	VarySelections   map[string]any  `json:"vary_selections,omitempty"`
	ResponseContract any             `json:"response_contract,omitempty"`
	Version          int             `json:"version,omitempty"`
	Major            int             `json:"major,omitempty"`
	Params           map[string]any  `json:"params,omitempty"`
	Warnings         []string        `json:"warnings"`
}

type RenderResult struct {
	Prompt            string          `json:"prompt"`
	ResponseContract  any             `json:"response_contract,omitempty"`
	CacheHit          bool            `json:"cache_hit"`
	CompiledTokens    int             `json:"compiled_tokens"`
	InjectedTokens    int             `json:"injected_tokens"`
	VarySelections    map[string]any  `json:"vary_selections,omitempty"`
}

type InjectResult struct {
	Prompt         string `json:"prompt"`
	InjectedTokens int    `json:"injected_tokens"`
}

type DotPromptEvent struct {
	Type      string `json:"type"`
	Timestamp int64  `json:"timestamp,omitempty"`
	Payload   any    `json:"payload,omitempty"`
	Prompt    string `json:"prompt,omitempty"`
}
