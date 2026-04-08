# Dot Prompt Writing Skill

## Purpose
Writing effective dot-prompt files (.prompt) for agentic workflows.

## When to Use
- Creating new .prompt files
- Building prompts with system/user role outputs
- Adding fragments or response contracts

## ⚠️ Common Mistakes

### Use role Instead of Custom Modes
```prompt
# WRONG
def:
  mode: execution_plan

# CORRECT
def:
  role: assistant
```

**Valid roles:** system, user, tool, fragment, collection

### strict: true requires response block
```prompt
def:
  role: assistant
  strict: true

response do
  {"intent": "WORKFLOW_CREATE", "data": {}}
end response
```

## Role Field
The `role` field in the `def:` section specifies the message role for the compiled prompt. Valid values:
- `assistant` — AI assistant message (default if not specified)
- `user` — user message
- `system` — system message

```
def:
  role: assistant
  description: A helpful assistant for answering questions.
```

## Message Sections
Message sections organize prompt content into role-specific blocks using `do...end` syntax:

```
system do
  You are a helpful AI assistant.
  Provide clear, accurate responses.
end system

context do
  Background information:
  {skill_context}
end context

user do
  @user_message
end user
```

**Block types:**
- `system` — defines the AI's identity, role, and behavior
- `context` — provides background information and data
- `user` — contains user input or message

## Context Merge Pattern
When combining multiple prompts, content merges by role:
- **System**: Joins with blank lines between content
- **Context**: Concatenates with blank line separators
- **User**: Uses the most recent value

```
# Base prompt
system do
  You are a helpful assistant.
end system

context do
  User preferences loaded.
end context

# Include skill
{skill_prompt}

# Merged result combines all context blocks
```

## Agentic Workflow Pattern

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
```elixir
%{system: "You are a skilled programmer...", user: "=== CONTEXT ===\nRetrieved files:\n...\n\n=== TASK ===\nTask: ..."}
```

## Related Skills
- `dot-prompt` — Full language reference (agents/skills/dotprompt_language.md)
