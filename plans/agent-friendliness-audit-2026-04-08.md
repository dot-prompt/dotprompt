# DotPrompt Agent-Friendliness Audit

**Date:** April 8, 2026
**Based on:** anantha-os usage audit

---

## Summary

An audit of an external project using dot-prompt revealed several patterns where agents misuse the library. This document captures actionable recommendations.

---

## Critical Issues Found

### 1. Custom Mode Values Are Ignored

**Problem:** Agents use custom modes like `execution_plan`, `explanation`, `router` which are silently ignored.

**Impact:** Agents believe they are configuring behavior that has no effect.

**Recommendation:**
- [x] Updated skill files to clearly list valid modes
- [ ] Consider warning in compiler when non-standard modes are used

### 2. strict: true Does Nothing Without Response Block

**Problem:** Agents set `strict: true` but forget to define `response` block.

**Impact:** No validation occurs, agent believes validation is happening.

**Recommendation:**
- [x] Updated skill files with example of correct usage
- [ ] Consider compiler warning: "strict: true set but no response block defined"

### 3. Fragments Never Included in Body

**Problem:** Agents declare fragments in `init` block but never add `{name}` to body.

**Impact:** Fragment system provides zero benefit, agents copy-paste instead.

**Recommendation:**
- [x] Updated skill files with explicit example
- [ ] Consider compiler warning: "fragment 'x' declared but not included in body"

### 4. Enum Parameters Not Used

**Problem:** Agents use `str` everywhere, preventing branching with if/case/vary.

**Impact:** No compile-time optimization, all logic pushed to runtime.

**Recommendation:**
- [x] Updated skill files to emphasize enum benefits
- [ ] Add lint rule: "consider enum for parameters with fixed options"

---

## Skill File Updates

### Updated Files

1. **agents/skills/dotprompt_language.md**
   - Added "Common Mistakes" section at top
   - Clarified which modes are valid
   - Added example of strict + response block
   - Added fragment inclusion pattern
   - Added best practices section

2. **agents/skills/dot-prompt-writing-skill/SKILL.md**
   - Rewrote to focus on dot-prompt syntax
   - Added "Common Agent Mistakes" section
   - Added standard modes list
   - Added common patterns

---

## Future Recommendations for Library

### Compiler Warnings (Medium Priority)

```elixir
# Consider adding these compiler warnings:

# 1. Custom mode warning
warning: "mode 'execution_plan' is not a standard mode. Valid modes: json, text, fragment, collection"

# 2. strict without response
warning: "strict: true requires a response block to enable validation"

# 3. Unused fragment
warning: "fragment 'context' declared but not included in prompt body"
```

### Documentation Improvements (Low Priority)

1. Add FAQ section addressing common mistakes
2. Add "Anti-patterns" page in documentation
3. Add "Migration from ad-hoc prompts" guide

---

## Conclusion

The main issues are not library bugs but **misunderstandings of the DSL**. The skill file updates address the most critical issues. Compiler warnings would provide additional protection.

**Action Items:**
- [x] Update dotprompt_language.md
- [x] Update dot-prompt-writing-skill/SKILL.md
- [ ] Consider compiler warnings for v2
