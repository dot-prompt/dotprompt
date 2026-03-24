# Zones UI Guide for Agents

The Zones UI is a flexible, region-based system for rendering AI responses. To ensure your content renders correctly and updates reliably, follow these rules.

## Core Concepts

### 1. Update Mechanism (Why zones might not update)
Zones are extracted from the **latest** agent conversation and merged with previous turns. For a zone to update:
- **Rule A**: It must be present in the `metadata` of your response (preferred).
- **Rule B**: It must use a **canonical field name** recognized by the `ZoneExtractor`.
- **Rule C**: If using a flat response, the keys must be top-level (e.g., `{"content": "...", "score": {...}}`).

### 2. Formats
- **Flat Format**: `{"content": "Hello", "score": {"overall": 0.8}}` (Automatically transformed to nested).
- **Nested Format**: `{"content": [{"content": "Hello"}], "score": [{"overall": 0.8}]}` (Standard internal representation).

---

## Zone Registry & Schemas

| Zone Type | Region | Required Fields | Description |
| :--- | :--- | :--- | :--- |
| `content` | Content | `content` | Main explanation/feedback text. Rendered via `ExplanationPanel`. |
| `scene` | Content | `content` | Scenario description or setup. |
| `roleplay` | Content | `content` | The character's spoken response. |
| `feedback` | Content | `content` | Specific coaching feedback. |
| `score` | Header | (none) | `{"overall": 0.0-1.0, "reasoning": "..."}`. |
| `progress` | Header | (none) | `{"percent": 0.0-1.0}`. |
| `modal` | Overlay | `variant` | `{"variant": "success/info/warning/error", "title": "...", "description": "..."}`. |
| `toast` | Overlay | `message` | `{"message": "...", "variant": "info", "duration": 5000}`. |

---

## Technical Gotchas (Troubleshooting)

### ❌ Common Mistake: Using Deprecated Keys
The `ResponseParser` maps many keys to `content`, which can cause conflicts if you provide multiple "content-like" fields.
- **Avoid**: `message`, `content_preview`, `roleplay_response`, `patient_response`.
- **Use**: `content` for explanations, `roleplay` for character speech.

### ❌ Common Mistake: Missing Keys in `ZoneExtractor`
The following keys are **STRICTLY** required for the extractor to "see" your zone:
`content`, `scene`, `roleplay`, `feedback`, `hint`, `question`, `sample_completion`, `score`, `progress`, `celebration`, `achievement`, `modal`, `toast`.

### ❌ Common Mistake: Float vs String
Scores and progress **must** be numbers (0.0 to 1.0) or strings with a percent sign (e.g., `"75%"`). Raw integers like `75` will be coerced to `75.0` (oops!).

---

## Best Practice Examples

### Standard Explanation Update
```json
{
  "content": "Today we are learning about Reframing.",
  "response_type": "explanation",
  "navigation": { "next_section": 2 }
}
```

### Roleplay with Feedback & Score
```json
{
  "roleplay": "I'm not sure I understand what you mean.",
  "feedback": "Try to use more empathy in your next turn.",
  "score": {
    "overall": 0.65,
    "skill_usage": 0.2,
    "reasoning": "Good attempt, but lacked rapport."
  },
  "response_type": "practice"
}
```

### Triggering an Overlay (Achievement)
```json
{
  "content": "Great job completing the module!",
  "toast": {
    "message": "Badge Unlocked: Master Reframer!",
    "variant": "success"
  },
  "response_type": "explanation"
}
```
