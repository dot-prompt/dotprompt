# Dot-Prompt Go Compiler

A minimal, fast compiler for `.prompt` files in Go. This compiler focuses on local execution without needing the Elixir/Phoenix backend for compilation.

## Features

- **No caching**: Reads from disk for every request, ideal for live development.
- **Recursive fragment resolution**: Resolves all `{fragment}` or `{{fragment}}` references.
- **Variable substitution**: Substitutes `@variable` placeholders with provided parameters.
- **Minimal memory footprint**: Optimized for one-pass parsing and substitution.

## Installation

```go
import "github.com/dot-prompt/dot-prompt-go-compiler"
```

## Usage

```go
package main

import (
	"fmt"
	"github.com/dot-prompt/dot-prompt-go-compiler"
)

func main() {
	params := map[string]interface{}{
		"name": "Nahar",
	}

	// Simple global helper: Compile promptName from base directory
	output, err := dotprompt.Compile("hello", params, "./prompts")
	if err != nil {
		panic(err)
	}

	fmt.Println(output)
}
```

## Advanced Usage

Using the `Compiler` struct for persistent base directory:

```go
c := dotprompt.NewCompiler("./prompts")
output, err := c.Compile("fragments/greeting", params)
```

## Supported Syntax

### `init` Block

Supports parsing metadata and declaration of params/fragments (currently minimal).

```
init do
  def:
    mode: fragment
  params:
    @name: str
  fragments:
    {foo}: from: bar
end init
```

### Body Variables and Fragments

- **Variables**: `@name`
- **Static Fragments**: `{fragment}`
- **Dynamic Fragments**: `{{fragment}}` (currently treated same as static)

## Design Goals

This compiler is designed to be "parent-friendly". It performs no internal caching, leaving state management to the parent application. It reads directly from the filesystem for every request, ensuring that changes to `.prompt` files are immediately reflected.
