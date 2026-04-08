# Role and Message Sections Implementation Plan

**Date:** April 8, 2026
**Status:** Proposed

---

## Overview

Add `role` field and message sections (`system`, `user`, `context`) for structured agentic outputs.

---

## Design

### Roles

| Role | Purpose |
|------|---------|
| `system` | System instructions/character |
| `user` | User message template |
| `tool` | Tool/function definition |
| `fragment` | Reusable snippet |
| `collection` | Fragment collection |

### Message Sections

```prompt
system do
  You are a helpful assistant.
end system

user do
  Task: @task
end user

context do
  Retrieved files:
  @file_list
end context
```

### Output Format

**System:** Extracted as-is

**User:** Context merged with `=== CONTEXT ===` and `=== TASK ===` separators:

```
=== CONTEXT ===
Retrieved files:
...

=== TASK ===
Task: ...
```

---

## Implementation Tasks

- [ ] Update lexer: add `section_start/end` tokens for system/user/context
- [ ] Update parser: handle `role` field, parse message sections
- [ ] Update compiler: emit structured output (system + user map)
- [ ] Update Result struct: `system: nil, user: nil`
- [ ] Deprecate `mode` in favor of `role`
- [ ] Update clients (Python, TypeScript, Go)
- [ ] Update skill files
- [ ] Add tests

---

## Backward Compatibility

- Keep `mode` as deprecated alias for `role`
- Emit warning when `mode` is used
- Existing prompts without sections continue to work as before
