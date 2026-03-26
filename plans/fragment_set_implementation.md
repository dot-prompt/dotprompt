# Fragment `set:` + Keyword Rename Implementation Plan

## Summary
- Change `match` → `filter` throughout
- Change `matchRe` → `filterRe` throughout
- Add `set:` block for passing variables to fragments

## Phase 1: Update Spec Files

### 1.1 plans/main_plan_v2.md
- Lines 251-261: Fragment assembly keywords table - `match`→`filter`, `matchRe`→`filterRe`, add `set`
- Lines 469-475: Collection rules table - same renames
- Error table: Add `set_type_mismatch`, `set_undeclared_var`, `set_unknown_param`

### 1.2 docs/language.md
- All `match:` → `filter:`, `matchRe:` → `filterRe:`
- Add `set:` syntax section

---

## Phase 2: Update Tests

### 2.1 validator_test.exs
- Add tests for `filter:`, `filterRe:`, `set:` parsing
- Add tests for new validation errors

### 2.2 error_handling_test.exs
- Add tests for `set_type_mismatch`, `set_undeclared_var`, `set_unknown_param`

### 2.3 collection_test.exs
- Change `match:` → `filter:` in test cases

### 2.4 fragment_expander_test.exs
- Add tests for `set:` param passing

### 2.5 Test fixture .prompt files
- Change `match:` → `filter:` in def blocks

---

## Phase 3: Implementation

### 3.1 validator.ex
- Parse `filter`/`filterRe` instead of `match`/`matchRe`
- Add `set:` block parsing
- Add validation: parent vars declared, fragment vars exist, types match

### 3.2 fragment_expander/collection.ex
- Update rule lookups `rules[:match]` → `rules[:filter]`

### 3.3 fragment_expander/static.ex
- Accept and forward `set` params to fragment compilation

### 3.4 fragment_expander/dynamic.ex
- Accept and forward `set` params to fragment compilation

---

## Phase 4: Update .prompt Files

### 4.1 Root prompts/ (5 files)
- concept_explanation.prompt
- fragment_demo.prompt
- all_skills.prompt

### 4.2 prompts/skills/ (4 files)
- milton_model.prompt, meta_model.prompt, anchoring.prompt, reframing.prompt

### 4.3 prompts/fragments/ (8 files)
- All fragment .prompt files

### 4.4 priv/prompts/ (9 files)
- Mirror of prompts/ directory

### 4.5 Test fixtures (4 files)
- Test fixture .prompt files

---

## Error Types

| Error | Description |
|-------|-------------|
| `set_type_mismatch` | Types differ between parent and fragment variable |
| `set_undeclared_var` | Variable on right side of set not declared in parent params |
| `set_unknown_param` | Variable on left side of set not in fragment's params |

## New Syntax

```prompt
fragments:
  {greeting}: dynamic from: fragments/greeting
    filter: @greeting_type
    set:
      name: @user_name
      level: @user_level
```