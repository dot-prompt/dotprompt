package dotprompt

import (
	"regexp"
	"strings"
)

type TokenType int

const (
	TokenText TokenType = iota
	TokenBlockStart
	TokenBlockEnd
	TokenVariable
	TokenFragmentStatic
	TokenFragmentDynamic
	TokenIf
	TokenElif
	TokenElse
	TokenCaseStart
	TokenVaryStart
	TokenCaseLabel
	TokenInitItem
	TokenDoc
	TokenParamDef
	TokenFragmentDef
)

type Token struct {
	Type   TokenType
	Value  string
	Line   int
	Indent int
	Meta   string
}

var (
	reBlockStart      = regexp.MustCompile(`^(init|docs|response)\s+do`)
	reBlockEnd        = regexp.MustCompile(`^end\s*(.*)$`)
	reIf              = regexp.MustCompile(`^(if|elif)\s+(@\w+)\s*(.*?)\sdo$`)
	reCaseStart       = regexp.MustCompile(`^case\s+(@\w+)\s+do$`)
	reVaryStart       = regexp.MustCompile(`^vary\s+(@\w+)\s+do$`)
	reVarySimpleStart = regexp.MustCompile(`^vary\s+do$`)
	reFragmentStatic  = regexp.MustCompile(`^\{[\w\-\.\/]+\}$`)
	reFragmentDynamic = regexp.MustCompile(`^\{\{[\w\-\.\/]+\}\}$`)
	reParamDef        = regexp.MustCompile(`^(@[\w\d_]+):\s*(.*)$`)
	reFragmentDef     = regexp.MustCompile(`^(\{{1,2}[\w\-\.\/]+\}{1,2}):\s*(.*)$`)
	reInitLabel       = regexp.MustCompile(`^(def|params|fragments):\s*(.*)$`)
	reGenericInitItem = regexp.MustCompile(`^([a-zA-Z0-9_\-\.]+):\s*(.*)$`)
)

func Tokenize(content string) []Token {
	lines := strings.Split(content, "\n")
	tokens := make([]Token, 0, len(lines))

	for i, line := range lines {
		lineTokens := tokenizeLine(line, i+1)
		tokens = append(tokens, lineTokens...)
	}

	return tokens
}

func tokenizeLine(line string, lineNo int) []Token {
	// Extract documentation if present
	doc := ""
	if idx := strings.Index(line, "->"); idx != -1 {
		doc = strings.TrimSpace(line[idx+2:])
		line = line[:idx]
	}

	trimmed := strings.TrimSpace(line)
	indent := len(line) - len(strings.TrimLeft(line, " \t"))

	tokens := []Token{}

	if trimmed == "" {
		tokens = append(tokens, Token{Type: TokenText, Value: "", Line: lineNo, Indent: indent})
		if doc != "" {
			tokens = append(tokens, Token{Type: TokenDoc, Value: doc, Line: lineNo, Indent: indent})
		}
		return tokens
	}

	if strings.HasPrefix(trimmed, "#") {
		return tokens
	}

	// Match block starts
	if reBlockStart.MatchString(trimmed) {
		match := reBlockStart.FindStringSubmatch(trimmed)
		tokens = append(tokens, Token{Type: TokenBlockStart, Value: match[1], Line: lineNo, Indent: indent})
	} else if reBlockEnd.MatchString(trimmed) {
		match := reBlockEnd.FindStringSubmatch(trimmed)
		tokens = append(tokens, Token{Type: TokenBlockEnd, Value: strings.TrimSpace(match[1]), Line: lineNo, Indent: indent})
	} else if reIf.MatchString(trimmed) {
		match := reIf.FindStringSubmatch(trimmed)
		tokens = append(tokens, Token{Type: getIfToken(match[1]), Value: match[2], Meta: match[3], Line: lineNo, Indent: indent})
	} else if trimmed == "else" || trimmed == "else do" {
		tokens = append(tokens, Token{Type: TokenElse, Line: lineNo, Indent: indent})
	} else if reCaseStart.MatchString(trimmed) {
		match := reCaseStart.FindStringSubmatch(trimmed)
		tokens = append(tokens, Token{Type: TokenCaseStart, Value: match[1], Line: lineNo, Indent: indent})
	} else if reVaryStart.MatchString(trimmed) {
		match := reVaryStart.FindStringSubmatch(trimmed)
		tokens = append(tokens, Token{Type: TokenVaryStart, Value: match[1], Line: lineNo, Indent: indent})
	} else if reVarySimpleStart.MatchString(trimmed) {
		tokens = append(tokens, Token{Type: TokenVaryStart, Value: "", Line: lineNo, Indent: indent})
	} else if reParamDef.MatchString(trimmed) {
		match := reParamDef.FindStringSubmatch(trimmed)
		tokens = append(tokens, Token{Type: TokenParamDef, Value: match[1], Meta: match[2], Line: lineNo, Indent: indent})
	} else if reFragmentDef.MatchString(trimmed) {
		match := reFragmentDef.FindStringSubmatch(trimmed)
		tokens = append(tokens, Token{Type: TokenFragmentDef, Value: match[1], Meta: match[2], Line: lineNo, Indent: indent})
	} else if reInitLabel.MatchString(trimmed) {
		match := reInitLabel.FindStringSubmatch(trimmed)
		if strings.TrimSpace(match[2]) == "" {
			tokens = append(tokens, Token{Type: TokenCaseLabel, Value: match[1], Line: lineNo, Indent: indent})
		} else {
			tokens = append(tokens, Token{Type: TokenInitItem, Value: match[1], Meta: match[2], Line: lineNo, Indent: indent})
		}
	} else if reGenericInitItem.MatchString(trimmed) {
		match := reGenericInitItem.FindStringSubmatch(trimmed)
		tokens = append(tokens, Token{Type: TokenInitItem, Value: match[1], Meta: match[2], Line: lineNo, Indent: indent})
	} else if reFragmentStatic.MatchString(trimmed) && trimmed != "{response_contract}" {
		tokens = append(tokens, Token{Type: TokenFragmentStatic, Value: trimmed, Line: lineNo, Indent: indent})
	} else if reFragmentDynamic.MatchString(trimmed) {
		tokens = append(tokens, Token{Type: TokenFragmentDynamic, Value: trimmed, Line: lineNo, Indent: indent})
	} else {
		// Just text, but may contain variables/fragments within
		tokens = append(tokens, Token{Type: TokenText, Value: line, Line: lineNo, Indent: indent})
	}

	if doc != "" {
		tokens = append(tokens, Token{Type: TokenDoc, Value: doc, Line: lineNo, Indent: indent})
	}

	return tokens
}

func getIfToken(kind string) TokenType {
	if kind == "if" {
		return TokenIf
	}
	return TokenElif
}
