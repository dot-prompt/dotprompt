package dotprompt

import "fmt"

type ParamSpec struct {
	Type     string      `json:"type"`
	Doc      string      `json:"doc,omitempty"`
	Default  interface{} `json:"default,omitempty"`
	Lifecycle string     `json:"lifecycle,omitempty"`
	Vary     bool        `json:"vary,omitempty"`
}

type FragmentSpec struct {
	Type string `json:"type,omitempty"`
	From string `json:"from"`
	Doc  string `json:"doc,omitempty"`
}

type PromptSchema struct {
	Name             string                  `json:"name"`
	Version          int                     `json:"version"`
	Description      string                  `json:"description,omitempty"`
	Mode             string                  `json:"mode,omitempty"`
	Params           map[string]ParamSpec    `json:"params"`
	Fragments        map[string]FragmentSpec `json:"fragments"`
	Docs             string                  `json:"docs,omitempty"`
	ResponseContract interface{}             `json:"response_contract,omitempty"`
}

type Node interface {
	isNode()
}

type TextNode struct {
	Value string
}

func (TextNode) isNode() {}

type VariableNode struct {
	Name string
}

func (VariableNode) isNode() {}

type FragmentNode struct {
	Name      string
	IsDynamic bool
}

func (FragmentNode) isNode() {}

type IfChainNode struct {
	If    IfBranch
	Elifs []IfBranch
	Else  []Node
}

func (IfChainNode) isNode() {}

type IfBranch struct {
	Variable  string
	Condition string
	Then      []Node
}

type CaseNode struct {
	Variable string
	Branches []CaseBranch
}

func (CaseNode) isNode() {}

type CaseBranch struct {
	ID    string
	Label string
	Then  []Node
}

type VaryNode struct {
	Variable string // May be empty for purely random vary
	Branches []CaseBranch
}

func (VaryNode) isNode() {}

type ResponseNode struct {
	Content string
	Line    int
}

func (ResponseNode) isNode() {}

type AST struct {
	Schema PromptSchema
	Body   []Node
}

func (a *AST) String() string {
	return fmt.Sprintf("Schema: %+v, Body nodes: %d", a.Schema, len(a.Body))
}
