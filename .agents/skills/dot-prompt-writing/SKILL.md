# Dot Prompt Writing Skill

Writing effective dot-prompt files (.prompt) for agentic workflows.

## Use role Instead of Custom Modes
```prompt
# WRONG
def:
  mode: execution_plan

# CORRECT
def:
  role: assistant
```

**Valid roles:** system, user, tool, fragment, collection

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

## Agentic Pattern
```prompt
system do
  You are a skilled programmer.
end system

user do
  Task: @task
end user

context do
  Files: @file_list
end context
```

**Output:** `%{system: "...", user: "=== CONTEXT ===\nFiles:...\n\n=== TASK ===\nTask: ..."}`

## Reference
- `dot-prompt` — Full language reference
