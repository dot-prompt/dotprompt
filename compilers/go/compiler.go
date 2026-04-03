package dotprompt

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

type Compiler struct {
	BaseDir string
}

func NewCompiler(baseDir string) *Compiler {
	return &Compiler{BaseDir: baseDir}
}

func (c *Compiler) Compile(promptPath string, params map[string]interface{}) (string, error) {
	return c.compileWithDepth(promptPath, params, 0)
}

func (c *Compiler) compileWithDepth(promptPath string, params map[string]interface{}, depth int) (string, error) {
	if depth > 10 {
		return "", fmt.Errorf("recursion limit exceeded for fragment %s", promptPath)
	}

	fullPath := filepath.Join(c.BaseDir, promptPath+".prompt")
	content, err := os.ReadFile(fullPath)
	if err != nil {
		fullPath = filepath.Join(c.BaseDir, "fragments", promptPath+".prompt")
		content, err = os.ReadFile(fullPath)
		if err != nil {
			return "", fmt.Errorf("could not load prompt %s: %w", promptPath, err)
		}
	}

	return c.CompileStringWithDepth(string(content), params, depth)
}

func (c *Compiler) CompileString(content string, params map[string]interface{}) (string, error) {
	return c.CompileStringWithDepth(content, params, 0)
}

func (c *Compiler) CompileStringWithDepth(content string, params map[string]interface{}, depth int) (string, error) {
	tokens := Tokenize(content)
	ast, err := Parse(tokens)
	if err != nil {
		return "", fmt.Errorf("parsing failed: %w", err)
	}

	var builder strings.Builder
	for _, node := range ast.Body {
		builder.WriteString(c.resolveNodeWithDepth(node, params, ast, depth))
	}
	return builder.String(), nil
}

func (c *Compiler) resolveNodeWithDepth(node Node, params map[string]interface{}, ast *AST, depth int) string {
	switch n := node.(type) {
	case TextNode:
		return n.Value
	case VariableNode:
		if val, ok := params[n.Name]; ok {
			return fmt.Sprintf("%v", val)
		}
		return "@" + n.Name
	case FragmentNode:
		fragPath := n.Name
		if spec, ok := ast.Schema.Fragments[n.Name]; ok {
			fragPath = spec.From
		}
		compiled, err := c.compileWithDepth(fragPath, params, depth+1)
		if err != nil {
			return fmt.Sprintf("{{FRAGMENT ERROR: %v}}", err)
		}
		return compiled
	case IfChainNode:
		if c.evaluate(n.If, params) {
			return c.resolveNodesWithDepth(n.If.Then, params, ast, depth)
		}
		for _, elif := range n.Elifs {
			if c.evaluate(elif, params) {
				return c.resolveNodesWithDepth(elif.Then, params, ast, depth)
			}
		}
		return c.resolveNodesWithDepth(n.Else, params, ast, depth)
	case CaseNode:
		val, ok := params[n.Variable]
		if !ok {
			return ""
		}
		sVal := fmt.Sprintf("%v", val)
		for _, b := range n.Branches {
			if b.ID == sVal {
				return c.resolveNodesWithDepth(b.Then, params, ast, depth)
			}
		}
	case VaryNode:
		val, ok := params[n.Variable]
		if ok {
			sVal := fmt.Sprintf("%v", val)
			for _, b := range n.Branches {
				if b.ID == sVal {
					return c.resolveNodesWithDepth(b.Then, params, ast, depth)
				}
			}
		}
		if len(n.Branches) > 0 {
			return c.resolveNodesWithDepth(n.Branches[0].Then, params, ast, depth)
		}
	}
	return ""
}

func (c *Compiler) resolveNodesWithDepth(nodes []Node, params map[string]interface{}, ast *AST, depth int) string {
	var b strings.Builder
	for _, n := range nodes {
		b.WriteString(c.resolveNodeWithDepth(n, params, ast, depth))
	}
	return b.String()
}

func (c *Compiler) evaluate(branch IfBranch, params map[string]interface{}) bool {
	val, ok := params[branch.Variable]
	if !ok {
		return false
	}

	cond := strings.TrimSpace(branch.Condition)
	if cond == "" {
		return val != nil && val != false && val != "" && val != 0
	}

	if strings.HasPrefix(cond, "is ") {
		expected := strings.TrimSpace(cond[3:])
		return compare(val, expected)
	}
	if strings.HasPrefix(cond, "not ") {
		expected := strings.TrimSpace(cond[4:])
		return !compare(val, expected)
	}
	if strings.HasPrefix(cond, "above ") {
		limit, _ := strconv.Atoi(strings.TrimSpace(cond[6:]))
		v, _ := strconv.Atoi(fmt.Sprintf("%v", val))
		return v > limit
	}
	if strings.HasPrefix(cond, "below ") {
		limit, _ := strconv.Atoi(strings.TrimSpace(cond[6:]))
		v, _ := strconv.Atoi(fmt.Sprintf("%v", val))
		return v < limit
	}
	if strings.HasPrefix(cond, "min ") {
		limit, _ := strconv.Atoi(strings.TrimSpace(cond[4:]))
		v, _ := strconv.Atoi(fmt.Sprintf("%v", val))
		return v >= limit
	}
	if strings.HasPrefix(cond, "max ") {
		limit, _ := strconv.Atoi(strings.TrimSpace(cond[4:]))
		v, _ := strconv.Atoi(fmt.Sprintf("%v", val))
		return v <= limit
	}
	if strings.HasPrefix(cond, "between ") {
		parts := strings.Split(cond[8:], " and ")
		if len(parts) == 2 {
			low, _ := strconv.Atoi(strings.TrimSpace(parts[0]))
			high, _ := strconv.Atoi(strings.TrimSpace(parts[1]))
			v, _ := strconv.Atoi(fmt.Sprintf("%v", val))
			return v >= low && v <= high
		}
	}
	if strings.HasPrefix(cond, "includes ") {
		expected := strings.Trim(cond[9:], "'\"")
		sVal := fmt.Sprintf("%v", val)
		return strings.Contains(sVal, expected)
	}
	return false
}

func compare(actual interface{}, expectedStr string) bool {
	if expectedStr == "true" {
		return actual == true || actual == "true"
	}
	if expectedStr == "false" {
		return actual == false || actual == "false"
	}
	if expectedStr == "nil" || expectedStr == "null" {
		return actual == nil
	}
	return fmt.Sprintf("%v", actual) == strings.Trim(expectedStr, "'\"")
}

func Compile(promptPath string, params map[string]interface{}, baseDir string) (string, error) {
	comp := NewCompiler(baseDir)
	return comp.Compile(promptPath, params)
}
