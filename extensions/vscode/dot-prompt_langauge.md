<!-- fullWidth: false tocVisible: false tableWrap: true -->
---

## name: dot-prompt description: Use this skill BEFORE creating or editing any .prompt file. dot-prompt is a compiled domain-specific language for authoring structured LLM prompts. Always read this skill first when you see a .prompt file, are asked to write a prompt, or need to understand the dot-prompt language. Do not write .prompt files from memory — the syntax is specific and must be followed exactly.

# dot-prompt Language

dot-prompt is a compiled prompt language. `.prompt` files are compiled into a clean flat string before being sent to an LLM. The LLM receives only the resolved output — no syntax artifacts, no untaken branches, no dead weight.

dot-prompt never makes LLM calls. It returns a string. What the caller does with that string is entirely their concern.

---

## The One Rule

`@` means variable. Always. Only. Everywhere.

Structural keywords — `init`, `docs`, `if`, `case`, `vary`, `else`, `elif`, `end`, `def`, `params`, `fragments`, `select` — never use `@`.

---

## File Structure

Every `.prompt` file has two parts:

```
init do
  ...metadata, params, fragments, docs...
end init

...prompt body...

```

`init` must appear at the top of the file. Everything outside `init` is prompt body. No file separators needed.

---

## Init Block

```
init do
  @version: 1

  def:
    mode: explanation
    description: Human readable description of this prompt.

  params:
    @skill_names: list[Milton Model, Meta Model, Anchoring] = Milton Model
      -> skills to load — matched against skills collection
    @pattern_step: int[1..5] = 1 -> current step in the teaching sequence
    @variation: enum[analogy, recognition, story]
      -> teaching track — required, no default
    @answer_depth: enum[shallow, medium, deep] = medium -> depth of answers
    @if_input_mode_question: bool = false
      -> true when user has asked an off-pattern question
    @user_input: str -> the user's current message — runtime, no default
    @user_level: enum[beginner, intermediate, advanced] = intermediate
      -> user experience level
    @intro_style: enum[formal, curious, story]
      -> opening variation — selected by runtime

  fragments:
    {skill_context}: static from: skills
      match: @skill_names
      -> loads and composites all matching skill definitions
    {{user_history}}: dynamic -> recent conversation history for context

  docs do
    Free text documentation. Surfaces through MCP and schema calls.
    Explain usage, behavioural notes, and anything an LLM needs to
    understand about how this prompt works as a whole.
  end docs

end init

```

---

## Param Declaration Syntax

```
@name: type = default -> documentation

```

| Part          | Separator | Required | Example                      |
| ------------- | --------- | -------- | ---------------------------- |
| name          | `@` prefix | yes      | `@answer_depth`              |
| type          | `:`       | yes      | `enum[shallow, medium, deep]` |
| default       | `=`       | no       | `= medium`                   |
| documentation | `->`      | no       | `-> depth of question answers` |

Params without `=` are required — the caller must always provide them. Params with `=` are optional — the default is used if not provided. No quotes on default string values — parser reads to end of line.

**Multiline documentation** — indent continuation under the param:

```
@skill_names: list[Milton Model, Meta Model] = Milton Model
  -> skills to load
     must exist in the skills collection
     matched exactly against fragment def.match fields

```

---

## Types

| Type          | Domain   | Lifecycle    | Notes                                |
| ------------- | -------- | ------------ | ------------------------------------ |
| `str`         | Infinite | Runtime      | Cannot drive branching               |
| `int`         | Infinite | Runtime      | Cannot drive branching               |
| `int[a..b]`   | Finite   | Compile-time | Can drive branching                  |
| `bool`        | Finite   | Compile-time | Can drive branching                  |
| `enum[a, b, c]` | Finite   | Compile-time | Single value, can drive branching    |
| `list[a, b, c]` | Finite   | Compile-time | Multiple values, can drive branching |

**Only finite domain variables can appear in `if`, `case`, or `vary` blocks.** `str` and `int` are always runtime — inject as content, never branch on them.

`enum` — single value — use when exactly one value is needed. `list` — multiple values — use when multiple values are needed (e.g. loading multiple fragments).

---

## Sigils

| Sigil    | Meaning                                             |
| -------- | --------------------------------------------------- |
| `@name`  | Variable — always and only                          |
| `{name}` | Static fragment — cached, from another `.prompt` file |
| `{{name}}` | Dynamic fragment — fetched fresh each request       |
| `#`      | Comment — stripped, never reaches LLM               |
| `->`     | Documentation — surfaces via MCP and schema         |

---

## Control Flow

All blocks open with `do` and close with `end @variable` or `end keyword`. Indentation is optional and has no semantic meaning. Maximum nesting depth is 3 levels.

### If

Natural language conditions. One keyword per operator.

```
if @if_input_mode_question is true do
STOP TEACHING FLOW. Answer the user's question directly.

elif @pattern_step is 1 do
This is the opening step. Introduce yourself briefly.

else
Continue the normal teaching flow.
end @if_input_mode_question

```

| Syntax                     | Meaning               | Types                 |
| -------------------------- | --------------------- | --------------------- |
| `if @var is x do`          | equality              | `bool`, `enum`, `int[a..b]` |
| `if @var not x do`         | inequality            | `enum`, `int[a..b]`   |
| `if @var above x do`       | greater than          | `int[a..b]`           |
| `if @var below x do`       | less than             | `int[a..b]`           |
| `if @var min x do`         | greater than or equal | `int[a..b]`           |
| `if @var max x do`         | less than or equal    | `int[a..b]`           |
| `if @var between x and y do` | inclusive range       | `int[a..b]`           |

### Case

Deterministic branch selection. Caller always provides the value. Optional title after `:` compiles through to LLM. Prefix title with `#` to keep as author documentation only.

```
case @answer_depth do
shallow: Shallow Answer
1-2 sentences answering exactly what they asked.

medium: Medium Answer
Explanation + 1 relevant example from the context.

deep: Deep Answer
Full explanation with multiple examples from the context.
end @answer_depth

```

### Vary

Non-deterministic branch selection. Requires an `enum` variable. Runtime randomizes unless a seed is provided by the caller. Named branches — descriptive words not single letters.

```
vary @intro_style do
formal: Begin with a structured overview of what we will cover.
curious: Begin with a question that creates productive curiosity.
story: Begin with a brief story that illustrates the concept.
end @intro_style

```

**Rules for vary:**

- Always requires an `enum` variable — no unnamed vary blocks
- Branch names are descriptive words matching the enum values
- Closes with `end @variable_name` — same as all other blocks
- Caller passes optional `seed:` for deterministic selection
- One seed drives all vary blocks in the prompt

### Nested Case — Variation Tracks

`case @variation` outside, `case @pattern_step` inside. Each track is a coherent narrative arc. Track titles prefixed with `#` are author docs only. Step titles without `#` compile through to the LLM.

```
case @variation do
analogy: #Analogy Track
case @pattern_step do
1: Opening Anchor
Introduce @skill_names with a single real-world analogy.
2: Deepening the Frame
Build on the analogy from step 1.
3: Concrete Examples
Give 2 examples of @skill_names in real conversation.
end @pattern_step

recognition: #Recognition Track
case @pattern_step do
1: Opening Anchor
Open with a question that makes the user realise they already use @skill_names.
2: Deepening the Frame
Return to the user's own recognition from step 1.
3: Concrete Examples
Ask the user to generate their own example first.
end @pattern_step

end @variation

```

**Compiled output** for `variation: recognition`, `pattern_step: 2`:

```
Deepening the Frame
Return to the user's own recognition from step 1.

```

---

## Fragments

### Single file fragment

```
fragments:
  {rules}: static from: shared/rules.prompt
  {{user_history}}: dynamic -> fetched fresh each request

```

### Collection fragments

A folder with `_index.prompt` is a collection. Assembly rules live in the calling prompt — not in `_index.prompt`.

```
fragments:
  # enum — single value — returns one fragment
  {primary_skill}: static from: skills
    match: @primary_skill

  # list — multiple values — returns composited fragments
  {skill_context}: static from: skills
    match: @skill_names

  # regex match — enum variable only, compile-time safe
  {milton_variants}: static from: skills
    matchRe: @skill_pattern
    limit: 3
    order: ascending

  # match all — returns every fragment in folder
  {all_skills}: static from: skills
    match: all
    order: ascending
    limit: 10

```

### Fragment assembly rules

| Rule  | Syntax                        | Requirement                           |
| ----- | ----------------------------- | ------------------------------------- |
| Exact | `match: @variable`            | `enum` or `list`                      |
| Regex | `matchRe: @variable`          | `enum` only — values are regex patterns |
| All   | `match: all`                  | none                                  |
| Limit | `limit: n`                    | integer                               |
| Order | `order: ascending / descending` | —                                     |

### Fragment file structure

```
init do
  @version: 1

  def:
    mode: fragment
    description: Milton Model skill definition
    match: Milton Model

  params:
    @skill_names: list[Milton Model] -> passed from parent prompt
end init

The Milton Model is a set of language patterns derived from...

```

The `match` field in `def:` is what the calling prompt matches against.

### \_index.prompt

Collection manifest — metadata and params only. No assembly rules.

```
init do
  @version: 1

  def:
    mode: collection
    description: NLP skills collection

  docs do
    Each .prompt file in this folder declares its match field in def.
    Add new skills by dropping a file in with the correct match value.
  end docs

end init

```

---

## Common Mistakes to Avoid

**Never use `@` on structural keywords:**

```
# WRONG
@init do
@docs do
end @init

# CORRECT
init do
docs do
end init

```

**Never use single letters for vary branches:**

```
# WRONG
vary @intro_style do
a: Begin with a structured overview.
b: Begin with a question.
end @intro_style

# CORRECT
vary @intro_style do
formal: Begin with a structured overview.
curious: Begin with a question.
end @intro_style

```

**Never use str variables in control flow:**

```
# WRONG — str is runtime, cannot branch
if @user_input is hello do
...
end @user_input

# CORRECT — only finite domain variables in control flow
if @if_input_mode_question is true do
...
end @if_input_mode_question

```

**Never use quotes on default values:**

```
# WRONG
@user_input: str = "Hello"

# CORRECT
@user_input: str = Hello

```

**Never use vary without an enum variable:**

```
# WRONG — unnamed vary not allowed
vary do
a: Option one.
b: Option two.
end vary

# CORRECT
@style: enum[formal, curious] -> opening style
vary @style do
formal: Option one.
curious: Option two.
end @style

```

**Never put assembly rules in \_index.prompt:**

```
# WRONG — assembly rules belong in calling prompt
# _index.prompt
select:
  match: @skill_names
  limit: all

# CORRECT — assembly rules in calling prompt fragments block
fragments:
  {skill_context}: static from: skills
    match: @skill_names

```

**Never use trailing / on folder paths:**

```
# WRONG
{skill_context}: static from: skills/

# CORRECT
{skill_context}: static from: skills

```

---

## Full Example

```
init do
  @version: 1

  def:
    mode: explanation
    description: Teacher mode — explanation phase with dynamic depth control.

  params:
    @skill_names: list[Milton Model, Meta Model, Anchoring, Reframing] = Milton Model
      -> skills to load — matched against skills collection
    @pattern_step: int[1..3] = 1 -> current step in the teaching sequence
    @variation: enum[analogy, recognition, story]
      -> teaching track — required, selected once per session
    @answer_depth: enum[shallow, medium, deep] = medium -> depth of question answers
    @if_input_mode_question: bool = false
      -> true when user has asked an off-pattern question
    @user_input: str -> the user's current message
    @user_level: enum[beginner, intermediate, advanced] = intermediate
      -> user experience level
    @intro_style: enum[formal, curious, story]
      -> opening variation — selected by runtime
    @closing_style: enum[exercise, reflection]
      -> closing variation — selected by runtime

  fragments:
    {skill_context}: static from: skills
      match: @skill_names
      -> loads and composites all matching skill definitions
    {{user_history}}: dynamic -> recent conversation history for context

  docs do
    Teaches NLP skills using a structured multi-turn pattern.
    @variation and @intro_style selected once at session start and held constant.
    Increment @pattern_step each turn.
    Set @if_input_mode_question true when user asks an off-pattern question.
  end docs

end init

# ROLE
You are Milton, an expert NLP trainer teaching @user_level students.
Your job is to teach @skill_names efficiently using structured teaching patterns.

vary @intro_style do
formal: Begin with a structured overview of what we will cover today.
curious: Begin with a question that creates productive curiosity.
story: Begin with a brief story that illustrates why this skill matters.
end @intro_style

if @if_input_mode_question is true do

# Question mode — interrupts teaching flow
STOP TEACHING FLOW. Answer the user's question directly.

The user asked: @user_input

Skill context:
{skill_context}

User history:
{{user_history}}

HOW TO ANSWER:
case @answer_depth do
shallow: Shallow Answer
1-2 sentences answering exactly what they asked.

medium: Medium Answer
Explanation + 1 relevant example from the context.

deep: Deep Answer
Full explanation with multiple examples from the context.
end @answer_depth

Rules:
- Do not continue the teaching pattern.
- Answer naturally, acknowledging their question.

Respond with this JSON:
{
  "response_type": "question_answer",
  "content": "your response here",
  "ui_hints": {
    "show_answer_input": false,
    "show_success": false,
    "show_failure": false
  }
}

else

# Teaching mode — normal step progression
case @variation do
analogy: #Analogy Track
case @pattern_step do
1: Opening Anchor
Introduce @skill_names with a single real-world analogy.
Do not define it formally yet. Let the analogy do the work.
2: Deepening the Frame
Build on the analogy from step 1. Layer in the formal definition.
3: Concrete Examples
Give 2 examples of @skill_names. First obvious, second subtle.
end @pattern_step

recognition: #Recognition Track
case @pattern_step do
1: Opening Anchor
Open with a question that makes the user realise they already use @skill_names.
2: Deepening the Frame
Return to the user's own recognition. Use their words to introduce the formal framing.
3: Concrete Examples
Ask the user to generate their own example first. Then offer one refinement.
end @pattern_step

story: #Story Track
case @pattern_step do
1: Opening Anchor
Start with a brief story where @skill_names changed the outcome of a conversation.
2: Deepening the Frame
Extend the story. Show how @skill_names was operating beneath the surface.
3: Concrete Examples
Show @skill_names being used poorly then well. Ask what changed.
end @pattern_step

end @variation

@user_input

vary @closing_style do
exercise: End with a practical exercise for the user to try in their next conversation.
reflection: End with a reflective question that deepens the learning.
end @closing_style

Respond with this JSON:
{
  "response_type": "teaching",
  "content": "your response here",
  "ui_hints": {
    "show_answer_input": true,
    "show_success": false,
    "show_failure": false
  }
}

end @if_input_mode_question

```

---

## Quick Reference

```
init do / end init          file setup — must be first
docs do / end docs          documentation inside init
if @var is x do / end @var  conditional
elif @var is x do           chained condition
else                        fallback branch
case @var do / end @var     deterministic branch selection
vary @var do / end @var     random or seeded branch — enum only
@name: type = default       param declaration
@name: type = default ->    param with documentation
{name}                      static fragment
{{name}}                    dynamic fragment
#                           comment — never reaches LLM
->                          documentation — surfaces via MCP

```