package dotprompt

import (
	"fmt"
	"strings"
)

func Parse(tokens []Token) (*AST, error) {
	ast := &AST{
		Schema: PromptSchema{
			Params:    make(map[string]ParamSpec),
			Fragments: make(map[string]FragmentSpec),
		},
		Body: make([]Node, 0),
	}

	var err error
	for i := 0; i < len(tokens); i++ {
		token := tokens[i]

		switch token.Type {
		case TokenBlockStart:
			if token.Value == "init" {
				i, err = parseInitBlock(ast, tokens, i+1)
			} else if token.Value == "docs" {
				i, err = parseDocsBlock(ast, tokens, i+1)
			} else if token.Value == "response" {
				i, err = parseResponseBlock(ast, tokens, i+1)
			}
			if err != nil {
				return nil, err
			}
		case TokenIf:
			var node IfChainNode
			node, i, err = parseIfChain(tokens, i)
			if err != nil {
				return nil, err
			}
			ast.Body = append(ast.Body, node)
		case TokenCaseStart:
			var node CaseNode
			node, i, err = parseCaseBlock(tokens, i)
			if err != nil {
				return nil, err
			}
			ast.Body = append(ast.Body, node)
		case TokenVaryStart:
			var node VaryNode
			node, i, err = parseVaryBlock(tokens, i)
			if err != nil {
				return nil, err
			}
			ast.Body = append(ast.Body, node)
		case TokenFragmentStatic:
			ast.Body = append(ast.Body, FragmentNode{Name: strings.Trim(token.Value, "{}"), IsDynamic: false})
		case TokenFragmentDynamic:
			ast.Body = append(ast.Body, FragmentNode{Name: strings.Trim(token.Value, "{}"), IsDynamic: true})
		case TokenText:
			ast.Body = append(ast.Body, parseLine(token.Value)...)
		}
	}

	return ast, nil
}

func parseInitBlock(ast *AST, tokens []Token, start int) (int, error) {
	section := ""
	i := start
	for ; i < len(tokens); i++ {
		t := tokens[i]
		if t.Type == TokenBlockEnd && (t.Value == "init" || t.Value == "") {
			return i, nil
		}

		switch t.Type {
		case TokenCaseLabel:
			section = t.Value
		case TokenInitItem:
			key := t.Value
			val := t.Meta
			switch section {
			case "def":
				if key == "mode" {
					ast.Schema.Mode = val
				} else if key == "match" {
					ast.Schema.Name = val
				}
			case "params":
				ast.Schema.Params[strings.TrimPrefix(key, "@")] = ParamSpec{Type: val}
			case "fragments":
				cleanKey := strings.Trim(key, "{}")
				ast.Schema.Fragments[cleanKey] = FragmentSpec{From: strings.TrimPrefix(val, "from: ")}
			}
		case TokenParamDef:
			ast.Schema.Params[strings.TrimPrefix(t.Value, "@")] = ParamSpec{Type: t.Meta}
		case TokenFragmentDef:
			cleanKey := strings.Trim(t.Value, "{}")
			ast.Schema.Fragments[cleanKey] = FragmentSpec{From: strings.TrimPrefix(t.Meta, "from: ")}
		}
	}
	return i, fmt.Errorf("unexpected EOF: missing end init")
}

func parseDocsBlock(ast *AST, tokens []Token, start int) (int, error) {
	var builder strings.Builder
	i := start
	for ; i < len(tokens); i++ {
		t := tokens[i]
		if t.Type == TokenBlockEnd && (t.Value == "docs" || t.Value == "") {
			ast.Schema.Docs = builder.String()
			return i, nil
		}
		if t.Type == TokenText {
			builder.WriteString(t.Value + "\n")
		}
	}
	return i, fmt.Errorf("unexpected EOF: missing end docs")
}

func parseResponseBlock(ast *AST, tokens []Token, start int) (int, error) {
	var builder strings.Builder
	i := start
	for ; i < len(tokens); i++ {
		t := tokens[i]
		if t.Type == TokenBlockEnd && (t.Value == "response" || t.Value == "") {
			ast.Body = append(ast.Body, ResponseNode{Content: builder.String(), Line: t.Line})
			return i, nil
		}
		if t.Type == TokenText {
			builder.WriteString(t.Value + "\n")
		}
	}
	return i, fmt.Errorf("unexpected EOF: missing end response")
}

func parseIfChain(tokens []Token, start int) (IfChainNode, int, error) {
	node := IfChainNode{}
	node.If = IfBranch{Variable: strings.TrimPrefix(tokens[start].Value, "@"), Condition: tokens[start].Meta}
	
	i := start + 1
	content, nextI := collectUntilBoundary(tokens, i, []TokenType{TokenElif, TokenElse, TokenBlockEnd})
	subAST, err := Parse(content)
	if err != nil {
		return node, nextI, err
	}
	node.If.Then = subAST.Body
	i = nextI

	for i < len(tokens) {
		t := tokens[i]
		if t.Type == TokenElif {
			branch := IfBranch{Variable: strings.TrimPrefix(t.Value, "@"), Condition: t.Meta}
			i++
			c, ni := collectUntilBoundary(tokens, i, []TokenType{TokenElif, TokenElse, TokenBlockEnd})
			sAST, err := Parse(c)
			if err != nil {
				return node, ni, err
			}
			branch.Then = sAST.Body
			node.Elifs = append(node.Elifs, branch)
			i = ni
		} else if t.Type == TokenElse {
			i++
			c, ni := collectUntilBoundary(tokens, i, []TokenType{TokenBlockEnd})
			sAST, err := Parse(c)
			if err != nil {
				return node, ni, err
			}
			node.Else = sAST.Body
			i = ni
		} else if t.Type == TokenBlockEnd {
			return node, i, nil
		} else {
			break
		}
	}
	return node, i, fmt.Errorf("unexpected EOF: missing end for if")
}

func parseCaseBlock(tokens []Token, start int) (CaseNode, int, error) {
	node := CaseNode{Variable: strings.TrimPrefix(tokens[start].Value, "@")}
	i := start + 1
	for i < len(tokens) {
		t := tokens[i]
		if t.Type == TokenBlockEnd {
			return node, i, nil
		}
		
		if t.Type == TokenInitItem || t.Type == TokenCaseLabel {
			branch := CaseBranch{ID: t.Value, Label: t.Meta}
			i++
			content, ni := collectUntilBoundary(tokens, i, []TokenType{TokenInitItem, TokenCaseLabel, TokenBlockEnd})
			sAST, err := Parse(content)
			if err != nil {
				return node, ni, err
			}
			branch.Then = sAST.Body
			node.Branches = append(node.Branches, branch)
			i = ni
			continue
		}
		
		if t.Type == TokenText && strings.Contains(t.Value, ":") {
			parts := strings.SplitN(t.Value, ":", 2)
			branch := CaseBranch{ID: strings.TrimSpace(parts[0]), Label: strings.TrimSpace(parts[1])}
			i++
			content, ni := collectUntilBoundary(tokens, i, []TokenType{TokenText, TokenBlockEnd}) 
			sAST, err := Parse(content)
			if err != nil {
				return node, ni, err
			}
			branch.Then = sAST.Body
			node.Branches = append(node.Branches, branch)
			i = ni
			continue
		}
		i++
	}
	return node, i, fmt.Errorf("unexpected EOF: missing end for case")
}

func parseVaryBlock(tokens []Token, start int) (VaryNode, int, error) {
	node := VaryNode{Variable: strings.TrimPrefix(tokens[start].Value, "@")}
	caseNode, nextI, err := parseCaseBlock(tokens, start)
	if err != nil {
		return node, nextI, err
	}
	node.Branches = caseNode.Branches
	return node, nextI, nil
}

func collectUntilBoundary(tokens []Token, start int, boundaries []TokenType) ([]Token, int) {
	depth := 0
	var collected []Token
	i := start
	for ; i < len(tokens); i++ {
		t := tokens[i]
		
		isBoundary := false
		if depth == 0 {
			for _, b := range boundaries {
				if t.Type == b {
					isBoundary = true
					break
				}
			}
		}

		if isBoundary {
			return collected, i
		}
		
		if isStartBlock(t.Type) {
			depth++
		} else if t.Type == TokenBlockEnd {
			depth--
		}

		collected = append(collected, t)
	}
	return collected, i
}

func isStartBlock(t TokenType) bool {
	return t == TokenIf || t == TokenCaseStart || t == TokenVaryStart || t == TokenBlockStart
}

func parseLine(line string) []Node {
	var nodes []Node
	last := 0
	for i := 0; i < len(line); i++ {
		if line[i] == '@' {
			start := i
			i++
			for i < len(line) && isAlphaNum(line[i]) {
				i++
			}
			if i > start+1 {
				if last < start {
					nodes = append(nodes, TextNode{Value: line[last:start]})
				}
				nodes = append(nodes, VariableNode{Name: line[start+1 : i]})
				last = i
				i--
			}
		} else if line[i] == '{' {
			start := i
			i++
			isDynamic := false
			if i < len(line) && line[i] == '{' {
				isDynamic = true
				i++
			}
			for i < len(line) && line[i] != '}' {
				i++
			}
			if i < len(line) && line[i] == '}' {
				if isDynamic && i+1 < len(line) && line[i+1] == '}' {
					i++
				}
				if last < start {
					nodes = append(nodes, TextNode{Value: line[last:start]})
				}
				cleanFrag := strings.Trim(line[start:i+1], "{} ")
				nodes = append(nodes, FragmentNode{Name: cleanFrag, IsDynamic: isDynamic})
				last = i + 1
				i--
			}
		}
	}
	if last < len(line) {
		nodes = append(nodes, TextNode{Value: line[last:]})
	}
	return nodes
}

func isAlphaNum(c byte) bool {
	return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_'
}
