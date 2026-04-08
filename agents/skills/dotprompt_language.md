---
name: dot-prompt
description: Skill for writing the dotprompt language. Use when working with .prompt files.
---

# dot-prompt Language Skill

## ⚠️ Common Mistakes (Read First!)

### Custom Mode Values Are IGNORED
```prompt
# WRONG - these do NOTHING
def:
  mode: execution_plan
  mode: explanation

# USE role INSTEAD
def:
  role: assistant
```

### Use Role for Agent Behaviors
The `role` field in `def:` controls how the prompt is used:
- `role: system` — System prompt (instructions/character)
- `role: user` — User message (with optional context)
- `role: tool` — Tool/function definition
- `role: fragment` — Reusable fragment
- `role: collection` — Fragment collection

### strict: true Does Nothing Without Response Contract
```prompt
# WRONG - no validation happens
def:
  role: assistant
  strict: true

# CORRECT - add response block
def:
  role: assistant
  strict: true

response do
  {"intent": "WORKFLOW_CREATE", "data": {}}
end response
```

### Fragments Must Be Explicitly Included
```prompt
# Declaring a fragment does NOT include it automatically
init do
  fragments:
    {my_context}: from: fragments/my_context
end init

# You MUST add this in the body:
{my_context}
```

---

## Overview

dot-prompt is a **compiled language** for writing LLM prompts:
- Resolves branching logic **at compile time** (if/case/vary disappear)
- Validates parameters against declared types
- Generates response contracts automatically
- Composes prompts via fragments
- Supports structured system/user outputs for agentic workflows

---

## Core Concepts

### Role-Based Prompts

The `role` in `def:` determines how the prompt is used:

| Role | Purpose | Output |
|------|---------|--------|
| `system` | Instructions, character, rules | System message |
| `user` | User input template | User message |
| `tool` | Tool/function definition | Tool schema |
| `fragment` | Reusable snippet | Included in parent |
| `collection` | Fragment folder | Multiple fragments |

### Message Sections

For structured outputs, use `system` and `user` blocks:

```prompt
system do
  You are a helpful coding assistant.
  Follow the @style guidelines.
end system

user do
  Help me with this task: @task
end user
```

**Context merges into user with separator:**

```prompt
system do
  You are a helpful assistant.
end system

user do
  Task: @task
end user

context do
  Retrieved information:
  @context_content
end context
```

**Output:**
```elixir
%{system: "You are a helpful assistant.", user: "=== CONTEXT ===\nRetrieved information:\n...\n=== TASK ===\nTask: ..."}
```

---

## Core Syntax
- `@variable`: All variables start with `@`
- `init do ... end init`: Metadata block
- `{fragment}`: Static fragment/skill inclusion
- `{{fragment}}`: Dynamic fragment inclusion
- `system do...end system`: System message section
- `user do...end user`: User message section
- `context do...end context`: Context section (merged into user)

---

## Types

### Compile-time Types (drive branching)
- `bool`: True/false conditions
- `enum[...]`: Fixed options (e.g., `enum[tone: formal, casual]`)
- `int[a..b]`: Integer ranges
- `list[...]`: Lists of values

### Runtime Types (placeholders)
- `str`: String placeholder — injected at runtime
- `int`: Integer placeholder — injected at runtime

---

## ✅ Best Practices

### Use Enums Over Strings
```prompt
# GOOD - type-safe, enables branching
@intent: enum[CREATE_WORKFLOW, QUERY_DATA, DIRECT_ANSWER]

# BAD - no validation, no branching
@intent: str
```

### Use Role for Agent Behaviors
```prompt
init do
  @version: 1.0
  def:
    role: assistant
    description: Intent classification

  params:
    @message: str

end init
```

### Use Message Sections for Structured Output
```prompt
init do
  @version: 1.0
  def:
    role: assistant

  params:
    @task: str
    @context: str

end init

system do
  You are a skilled programmer.
  Always explain your reasoning.
end system

user do
  Task: @task
end user

context do
  Retrieved files:
  @file_list
end context
```

**Output:**
- `system`: "You are a skilled programmer..."
- `user`: "=== CONTEXT ===\nRetrieved files:\n...\n=== TASK ===\nTask: ..."

### Use Fragments for Shared Content
```prompt
# fragments/org_context.prompt
init do
  @version: 1
  def:
    role: fragment
    match: org_context
end init

You are helping in @org_name (@tier tier).

# main.prompt
init do
  @version: 1.0
  fragments:
    {context}: from: fragments/org_context
end init

{context}

Handle: @user_input
```

### Use Compile-time Defaults
```prompt
@timeout_ms: int = 30000
@tone: enum[formal, casual] = casual
```

---

## Init Block

```
init do
  @version: 1.0

  def:
    role: assistant
    description: Classifies user intent.

  params:
    @message: str
    @history: str

  fragments:
    {context}: from: fragments/shared_context

  docs do
    Use this prompt for intent classification.
  end docs

end init
```

### Sections
<<<<<<< Updated upstream
- `@version: major.minor` — required, semantic versioning
- `def:` — `mode`, `description`, and `role` fields. For fragments, `mode: fragment` and `match: value`
- `params:` — all variables used in the prompt
- `fragments:` — external `.prompt` files to include
- `docs do...end docs` — free text for MCP and agents

### Role Field
The `role` field specifies the message role for the compiled prompt. Valid values:
- `assistant` — AI assistant message (default if not specified)
- `user` — user message
- `system` — system message

```
def:
  role: assistant
  description: A helpful assistant for answering questions.
```

The role field provides the semantic intent of the prompt and helps the compiler determine message placement when merging prompts.

### Message Sections
Message sections organize prompt content into role-specific blocks. Use `do...end` syntax to delimit each section:

```
system do
  You are a helpful AI assistant with expertise in {{domain}}.
  Provide clear, accurate, and concise responses.
end system

context do
  Background information:
  {relevant_context}
end context

user do
  @user_message
end user
```

**Block types:**
- `system` — defines the AI's identity, role, and behavior
- `context` — provides background information and data
- `user` — contains user input or message

### Context Merge Pattern
When combining multiple prompts, content merges by role. System content joins with blank lines, context content concatenates, and user content uses the most recent value.

**Example with context merge:**
```
# Base prompt
system do
  You are a helpful assistant.
end system

context do
  User preferences loaded.
end context

# Merged with skill prompt
{skill_prompt}

# Result - context concatenates:
# context:
#   User preferences loaded.
#
#   Skill-specific context here.
```

### Fragment Mode
Individual fragment files declare `mode: fragment` and a `match` value:
=======
- `@version: major.minor` — required
- `def:` — role and description
- `params:` — variables
- `fragments:` — external files to include
- `docs do...end docs` — documentation

### Role Values
- `role: system` — System prompt
- `role: user` — User message
- `role: tool` — Tool definition
- `role: fragment` — Reusable fragment
- `role: collection` — Fragment collection
>>>>>>> Stashed changes

---

## Message Sections

### System Section
```prompt
system do
  You are @character_name.
  Your personality: @personality
  Follow these rules:
  - Be concise
  - Ask clarifying questions when needed
end system
```

### User Section
```prompt
user do
  The user said: @user_message
  
  History:
  @chat_history
end user
```

### Context Section
Context is merged into the user message with `=== CONTEXT ===` separator:
```prompt
context do
  Retrieved context:
  @context_content
  
  Source: @context_source
end context
```

**Result:**
```elixir
%{system: "...", user: "=== CONTEXT ===\nRetrieved context:\n...\n\n=== TASK ===\n..."}
```

### Tool Section (for tool definitions)
```prompt
init do
  @version: 1
  def:
    role: tool
    match: search
end init

{
  "name": "search",
  "description": "Search the web for information",
  "parameters": {
    "type": "object",
    "properties": {
      "query": {"type": "string"}
    }
  }
}
```

---

## Fragment Declaration

```
fragments:
  {simple}: from: fragments/simple
  {skills}: static from: skills
    match: @skill_names
  {{user_history}}: dynamic
```

- `match: @variable` — filter by enum/list
- `match: all` — include all
- `matchRe: M.*` — regex filter
- `limit: n` — maximum fragments
- `set: child_param: @parent_var` — pass variables

---

## Response Block (Required for strict: true)

```
response do
  {
    "intent": "WORKFLOW_CREATE",
    "confidence": 0.95,
    "data": {"key": "value"}
  }
end response
```

Use `{response_contract}` in body to inject schema.

---

## Control Flow

### If Statements
```
if @is_premium is true do
  Premium content here.
else
  Free tier content.
end @is_premium
```

### Case Statements
```
case @format do
  json do JSON output. end
  xml do XML output. end
end @format
```

### Vary Statements
```
vary @tone do
  formal do Formal language. end
  casual do Casual tone. end
end @tone
```

---

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Fragment empty | Not in body | Add `{Name}` to body |
| strict does nothing | No response block | Add `response do...end response` |
| Mode ignored | Using old `mode` syntax | Use `role` instead |
| Branching fails | Using `str` | Use `enum` or `bool` |
| Custom role ignored | Invalid role | Use: system, user, tool, fragment |
