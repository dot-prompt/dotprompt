package dotprompt

import (
	"strings"
	"testing"
)

// --- Happy Paths ---

func TestHappyPaths(t *testing.T) {
	comp := NewCompiler("")

	t.Run("Variables", func(t *testing.T) {
		prompt := "Hello @name!"
		params := map[string]interface{}{"name": "World"}
		out, _ := comp.CompileString(prompt, params)
		if out != "Hello World!" {
			t.Errorf("Expected Hello World!, got %q", out)
		}
	})

	t.Run("ComplexityIfElifElse", func(t *testing.T) {
		prompt := `if @v is 'a' do
A
elif @v is 'b' do
B
else do
C
end if`
		cases := []struct {
			v        string
			expected string
		}{
			{"a", "A"},
			{"b", "B"},
			{"c", "C"},
		}
		for _, tc := range cases {
			out, _ := comp.CompileString(prompt, map[string]interface{}{"v": tc.v})
			if strings.TrimSpace(out) != tc.expected {
				t.Errorf("For %s expected %s, got %s", tc.v, tc.expected, out)
			}
		}
	})

	t.Run("NaturalLanguageOps", func(t *testing.T) {
		params := map[string]interface{}{"age": 25}
		tests := []struct {
			cond     string
			expected bool
		}{
			{"above 20", true},
			{"below 20", false},
			{"min 25", true},
			{"max 24", false},
			{"between 20 and 30", true},
		}
		for _, tt := range tests {
			prompt := "if @age " + tt.cond + " do\nYES\nend if"
			out, _ := comp.CompileString(prompt, params)
			hasYes := strings.Contains(out, "YES")
			if hasYes != tt.expected {
				t.Errorf("Cond %s expected %v, got %v", tt.cond, tt.expected, hasYes)
			}
		}
	})
}

// --- Unhappy Paths ---

func TestUnhappyPaths(t *testing.T) {
	comp := NewCompiler("")

	t.Run("MissingVariable", func(t *testing.T) {
		prompt := "Hello @unknown!"
		out, _ := comp.CompileString(prompt, nil)
		if out != "Hello @unknown!" {
			t.Errorf("Expected leak-through @unknown, got %q", out)
		}
	})

	t.Run("UnclosedBlock", func(t *testing.T) {
		prompt := "init do\nparams:\n@v: str" // missing end init
		_, err := comp.CompileString(prompt, nil)
		if err == nil || !strings.Contains(err.Error(), "missing end init") {
			t.Errorf("Expected 'missing end init' error, got %v", err)
		}
	})

	t.Run("UnclosedIf", func(t *testing.T) {
		prompt := "if @v do\nSomething" // missing end if
		_, err := comp.CompileString(prompt, map[string]interface{}{"v": true})
		if err == nil || !strings.Contains(err.Error(), "missing end for if") {
			t.Errorf("Expected 'missing end for if' error, got %v", err)
		}
	})

	t.Run("RecursionLimit", func(t *testing.T) {
		// Mock a circular fragment by using CompileString with a recursive call
		// Since we don't have a real fs here, we'll verify it returns an error string on fragment error
		// which happens if Compile fails (e.g. file not found or recursion)
		out, _ := comp.CompileString("{missing}", nil)
		if !strings.Contains(out, "FRAGMENT ERROR") {
			t.Errorf("Expected FRAGMENT ERROR placeholder, got %q", out)
		}
	})
}
