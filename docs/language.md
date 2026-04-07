<!-- fullWidth: false tocVisible: false tableWrap: true -->
# dot-prompt Language Reference

dot-prompt is a compiled language for writing LLM prompts. You write `.prompt` files. The compiler resolves all branching and returns a clean flat string. The LLM receives only the resolved output — no syntax, no dead branches, no untaken paths.

dot-prompt never makes LLM calls. It returns a string. What you do with that string is up to you.

---

## The One Rule

`@` means variable. Always. Only. Everywhere.

If it starts with `@`, it is a variable. If it does not start with `@`, it is not a variable. Structural keywords like `if`, `case`, `vary`, `init` never use `@`.

---

## File Structure

Every `.prompt` file has exactly two parts: an `init` block at the top, and a prompt body below it.

```
init do
  ...
end init

...prompt body...
```

The `init` block declares everything about the file — its version, its variables, its fragments, its documentation. The prompt body is the prose that gets compiled and sent to the LLM.

---

## The Init Block

The `init` block opens with `init do` and closes with `end init`. It contains four sections: version, `def:`, `params:`, `fragments:`, and an optional `docs` block.

```
init do
  @version: 1.0

  def:
    mode: explanation
    role: assistant
    description: Teaches NLP skills using a structured multi-turn pattern.

  params:
    @variation: enum[analogy, recognition, story] = analogy
      -> teaching track — selected once per session
    @pattern_step: int[1..5] = 1 -> current step in the sequence
    @user_input: str -> the user's current message

  fragments:
    {skill_context}: static from: skills
      filter: @variation
    {{user_history}}: dynamic -> recent conversation history

  docs do
    Increment @pattern_step each turn.
    Set @if_input_mode_question true when the user asks a question.
  end docs

end init
```

### @version

`@version` is `major.minor` — the first number is the major version (breaking change boundary). The container manages `@version` automatically after initial declaration.

```
@version: 1.0
```

Major must be ≥ 1. The first number in `@version` is used as the major version.

### def:

Three fields — `mode`, `description`, and `role`. All are informational. `description` surfaces in schema calls and the viewer. `role` specifies the message role (assistant, user, or system).

```
def:
  mode: explanation
    role: assistant
  description: Human readable description of this prompt.
```

### params:

All variables are declared here. The declaration syntax is:

```
@name: type = default -> documentation
```

- `@name` — required
- `: type` — required
- `= default` — optional. String defaults do not use quotes.
- `-> documentation` — optional. Surfaces via MCP. Can be multiline with indented continuation.

```
params:
  @answer_depth: enum[shallow, medium, deep] = medium -> depth of answers
  @skill_names: list[Milton Model, Meta Model, Anchoring]
    -> skills to load
       must exist in the skills collection
  @user_input: str -> the user's message — required, no default
  @if_input_mode_question: bool = false
  @pattern_step: int[1..5] = 1 -> current step
```

### fragments:

Fragments are external files or collections that get compiled into the prompt. Declared here, referenced in the body with `{name}` or `{{name}}`.

```
fragments:
  {rules}: static from: shared/rules.prompt
  {skill_context}: static from: skills
    filter: @skill_names
  {{user_history}}: dynamic -> fetched fresh each request
```

See the Fragments section for full syntax.

### docs:

Free text. Surfaces through MCP `prompt_schema` calls. Write whatever is useful for the caller or an LLM agent working with this prompt.

```
docs do
  This prompt teaches NLP skills in a structured multi-turn sequence.
  Select @variation once at session start and hold it constant.
end docs
```

---

## Types

Types determine two things: what values are valid, and when the variable is resolved.

| Type      | Example                  | Domain                           | Resolved     |
| --------- | ------------------------ | -------------------------------- | ------------ |
| `str`     | `@user_input: str`       | Any string                       | Runtime      |
| `int`     | `@count: int`            | Any integer                      | Runtime      |
| `int[a..b]` | `@step: int[1..5]`       | Integer within range             | Compile-time |
| `bool`    | `@show_hint: bool = false` | `true` or `false`                | Compile-time |
| `enum[...]` | `@mode: enum[fast, slow]` | One value from the list          | Compile-time |
| `list[...]` | `@skills: list[A, B, C]` | One or more values from the list | Compile-time |

**Compile-time** types (`int[a..b]`, `bool`, `enum`, `list`) are resolved during compilation and can drive branching — `if`, `case`, and `vary` blocks.

**Runtime** types (`str`, `int`) are injected just before the LLM call. They cannot drive branching because their value is unknown at compile time. They appear as placeholders in the compiled template and are filled in during injection.

---

## The Prompt Body

Everything below `end init` is prompt body. It is plain prose with variable references, fragment references, comments, and control flow blocks.

### Variable References

Reference any declared variable by name. Runtime variables remain as placeholders after compilation and are filled in at injection time.

```
You are teaching @user_level students about @skill_names.

The user said: @user_input
```

### Fragment References

```
{skill_context}     # static — compiled from file, cached
{{user_history}}    # dynamic — fetched fresh each request
```

### Comments

Lines starting with `#` are stripped during compilation. The LLM never sees them.

```
# This section handles question interruptions
if @if_input_mode_question is true do
...
end @if_input_mode_question
```

Inside `case` and `vary` blocks, a `#` prefix on a branch title marks it as author documentation only — it does not compile through to the LLM.

```
case @variation do
analogy: #Analogy Track     # stripped — LLM does not see "Analogy Track"
content here

recognition: Recognition    # no # — LLM sees "Recognition"
content here
end @variation
```

---

## Control Flow

All control flow blocks open with `do` and close with `end @variable` or `end keyword`. Indentation is optional and has no semantic meaning. Maximum nesting depth is 3 levels.

Only **compile-time types** can drive control flow: `bool`, `enum`, `list`, `int[a..b]`. You cannot branch on `str` or unbounded `int`.

### if

Evaluates a variable against a condition. Supports `elif` and `else`.

```
if @if_input_mode_question is true do
Answer the user's question directly. Do not continue the teaching flow.

elif @pattern_step is 1 do
This is the opening step. Introduce yourself briefly.

else
Continue the normal teaching flow.
end @if_input_mode_question
```

The block closes with `end @variable` where `@variable` matches the variable used in the opening `if`.

**Condition operators:**

| Syntax                     | Meaning               | Valid types           |
| -------------------------- | --------------------- | --------------------- |
| `if @var is x do`          | equals                | `bool`, `enum`, `int[a..b]` |
| `if @var not x do`         | does not equal        | `enum`, `int[a..b]`   |
| `if @var above x do`       | greater than          | `int[a..b]`           |
| `if @var below x do`       | less than             | `int[a..b]`           |
| `if @var min x do`         | greater than or equal | `int[a..b]`           |
| `if @var max x do`         | less than or equal    | `int[a..b]`           |
| `if @var between x and y do` | inclusive range       | `int[a..b]`           |

### case

Deterministic branch selection. The caller always provides the value. Every value in the enum or range can have a branch.

An optional title after `:` compiles through to the LLM. Prefix the title with `#` to keep it as author documentation only.

```
case @answer_depth do
shallow: Shallow Answer
Give 1-2 sentences answering exactly what was asked.

medium: Medium Answer
Explanation plus one relevant example from the context.

deep: Deep Answer
Full explanation with multiple examples from the context.
end @answer_depth
```

### vary

Non-deterministic branch selection. Requires an `enum` variable. The runtime randomises the selection unless a seed is provided. Branch names are descriptive words, not single letters.

```
vary @intro_style do
formal: Begin with a structured overview of what we will cover today.
curious: Begin with a question that creates productive curiosity.
story: Begin with a brief story that illustrates why this skill matters.
end @intro_style
```

**Seeding:** One optional seed drives all `vary` blocks in a prompt. The seed is hashed against each vary variable name internally, producing independent but reproducible selections per block.

```elixir
# Random selection
DotPrompt.compile("concept_explanation", params)

# Deterministic, reproducible
DotPrompt.compile("concept_explanation", params, seed: 42)
```

### Nesting

Control flow blocks can be nested up to 3 levels deep. The most common pattern is nesting `case @pattern_step` inside `case @variation` to build variation tracks.

```
case @variation do
analogy: #Analogy Track
case @pattern_step do
1: Opening Anchor
Introduce the concept with a single real-world analogy.

2: Deepening the Frame
Build on the analogy. Layer in the formal definition.

3: Concrete Examples
Give two examples. Ask which felt more natural.
end @pattern_step

recognition: #Recognition Track
case @pattern_step do
1: Opening Anchor
Open with a question that makes the user realise they already use this.

2: Deepening the Frame
Return to their recognition. Use their words to introduce the formal framing.

3: Concrete Examples
Ask the user to generate their own example first.
end @pattern_step

end @variation
```

The compiler resolves both variables. For `variation: recognition` and `pattern_step: 2`, the output is:

```
Deepening the Frame
Return to their recognition. Use their words to introduce the formal framing.
```

---

## Fragments

Fragments are external `.prompt` files compiled into the calling prompt. They are declared in `init` and referenced by name in the body.

### Single file

```
fragments:
  {rules}: static from: shared/rules.prompt
```

The path resolves to a single `.prompt` file. No trailing `/`.

### Collection

A folder containing an `_index.prompt` is a collection. The calling prompt declares how to select from it.

```
fragments:
  # enum variable — returns one fragment
  {primary_skill}: static from: skills
    filter: @primary_skill

  # list variable — returns all matched fragments composited in order
  {skill_context}: static from: skills
    filter: @skill_names

  # regex match — enum variables only
  {milton_variants}: static from: skills
    filterRe: Milton.*
    limit: 3
    order: ascending

  # every fragment in the folder
  {all_examples}: static from: examples
    filter: all
    order: ascending
```

Assembly rules (`filter`, `filterRe`, `filter: all`, `limit`, `order`, `set`) are always declared in the calling prompt — never in `_index.prompt`.

**filter vs filterRe:**

- `filter: @variable` — exact string match against each fragment's `def.match` field
- `filterRe: pattern` — compile-time regex. Supports `@variable` interpolation but the variable must be `enum` type
- `filter: all` — returns every `.prompt` file in the folder except `_index.prompt`

### Dynamic fragments

`{{double_braces}}` means the fragment is fetched fresh on every request and never cached. Use for live data like conversation history.

```
fragments:
  {{user_history}}: dynamic -> recent conversation history
```

Dynamic fragments are referenced in the body the same way as static ones:

```
{{user_history}}
```

### Passing variables to fragments

Use `set:` to explicitly pass variables to fragments. The left side is the fragment's parameter name (no `@`), the right side is the parent variable (with `@`).

```
fragments:
  {greeting}: dynamic from: fragments/greeting
    filter: @greeting_type
    set:
      name: @user_name
      level: @user_level
```

The compiler validates:
1. Every variable on the right (`@user_name`, `@user_level`) is declared in the parent params
2. Every variable on the left (`name`, `level`) exists in the fragment's own params
3. Types match on both sides

### \_index.prompt

Every collection folder must have an `_index.prompt`. It declares the folder's metadata only — no assembly rules.

```
init do
  @version: 1

  def:
    mode: collection
    description: NLP skills collection

  docs do
    Add skills by dropping .prompt files in this folder.
    Each file must declare its match value in def.match.
  end docs

end init
```

### Fragment files

Each fragment file is a full `.prompt` file. Its `def.match` field is what the calling prompt matches against.

```
init do
  @version: 1

  def:
    mode: fragment
    description: Milton Model skill definition
    filter: Milton Model

end init

The Milton Model is a set of language patterns derived from...
```

---

## Response Contracts

A `response do / end response` block in the prompt body declares the expected JSON shape of the LLM's response. The compiler derives a typed contract from it and returns it alongside the compiled prompt.

### Syntax

```
Teach the concept now.

response do
  {
    "response_type": "teaching",
    "content": "string",
    "ui_hints": {
      "show_input": true,
      "show_success": false
    }
  }
end response
```

The JSON inside the block is the shape — field names and types. The compiler reads it and derives the contract schema.

### {response_contract}

A special reference that injects the derived contract into the compiled prompt as a JSON instruction to the LLM.

```
Respond in exactly this JSON format:
{response_contract}
```

The compiler replaces `{response_contract}` with the actual JSON shape. The LLM sees the concrete structure it must follow.

### Multiple response blocks

One `response` block per branch is allowed. The compiler collects all blocks and compares them.

| Scenario                      | Compiler action                                   |
| ----------------------------- | ------------------------------------------------- |
| All blocks identical          | Silent                                            |
| Same fields, different values | Warning: `compatible_contracts`                   |
| Different fields or types     | Error: `incompatible_contracts` — compilation fails |
| Branch missing a block        | Warning: `missing_contract`                       |

### DotPrompt.Result

All compile and render calls return a `DotPrompt.Result` struct.

```elixir
%DotPrompt.Result{
  prompt: "You are teaching intermediate students...",
  response_contract: %{
    "response_type" => %{type: "string", required: true},
    "content" => %{type: "string", required: true}
  },
  vary_selections: %{"intro_style" => "curious"},
  compiled_tokens: 312,
  cache_hit: true
}
```

### Validating LLM output

```elixir
case DotPrompt.validate_output(llm_response, result.response_contract) do
  :ok -> # valid
  {:error, reason} -> # mismatch — reason describes what failed
end

# Strict mode — extra fields in the response are rejected
DotPrompt.validate_output(llm_response, result.response_contract, strict: true)
```

---

## Versioning

### Initial declaration

Set `@version` once when you create the file. Never edit it manually again.

```
init do
  @version: 1.0
  ...
end init
```

### How versioning works

The container watches your prompt files. When you save:

- **Non-breaking change** — silent. The container auto-bumps the minor version on your next git commit.
- **Breaking change** — the container notifies you via the viewer and VS Code. You choose what to do.

On a breaking change notification you have three options:

- **Version it** — the current file is archived as `archive/name_v{major}.prompt`. `@version` increments (e.g., 1.5 → 2.0).
- **Not now** — warning persists. You can keep editing.
- **Ignore always** — suppressed in the viewer until your next git commit, at which point a hard warning fires regardless.

### Breaking vs non-breaking

**Breaking — requires Version it:**

| Change                         | Example                    |
| ------------------------------ | -------------------------- |
| Removing a param               | `@skill_names` deleted     |
| Renaming a param               | `@level` → `@user_level`   |
| Changing a param type          | `str` → `enum[...]`        |
| Removing a param's default     | `= medium` removed         |
| Narrowing an enum              | `enum[a, b, c]` → `enum[a, b]` |
| Removing a response field      | `"content"` deleted        |
| Renaming a response field      | `"content"` → `"body"`     |
| Changing a response field type | `"number"` → `"string"`    |

**Non-breaking — minor auto-bumped on commit:**

| Change                          | Example                                 |
| ------------------------------- | --------------------------------------- |
| Adding a param with a default   | `@theme: enum[light, dark] = light`     |
| Adding enum values              | `enum[a, b]` → `enum[a, b, c]`          |
| Changing documentation          | `->` text updated                       |
| Changing a default value        | `= medium` → `= deep`                   |
| Rewriting prompt body prose     | Any text change with no contract change |
| Adding optional response fields | New field with `required: false`        |

### Folder structure with versions

```
priv/prompts/
  concept_explanation.prompt          # current (e.g. major 3, version 3.2)
  .snapshots/
    concept_explanation.prompt.snap   # pre-edit baseline — gitignored
  archive/
    concept_explanation_v1.prompt     # archived major 1
    concept_explanation_v2.prompt     # archived major 2
  skills/
    _index.prompt
    milton_model.prompt
    archive/
      milton_model_v1.prompt
```

- Current version — always at top level, no suffix
- Archived majors — `archive/name_v{major}.prompt`
- `archive/` never contains `_index.prompt` — it is not a collection
- `.snapshots/` is gitignored — never committed

### Post-commit hook

Install once per repo:

```bash
echo 'curl -s -X POST http://localhost:4041/webhooks/commit > /dev/null' \
  > .git/hooks/post-commit
chmod +x .git/hooks/post-commit
```

On every commit the container runs a diff, auto-bumps minors for non-breaking changes, and fires a hard warning if a breaking change was not versioned.

---

## Errors

The compiler stops immediately on any error. Errors include file name, line number, variable name, and a descriptive message. There are no silent failures.

| Error                  | Meaning                                                        |
| ---------------------- | -------------------------------------------------------------- |
| `unknown_variable`     | `@var` referenced in body but not declared in params           |
| `out_of_range`         | `int[a..b]` value outside declared bounds                      |
| `invalid_enum`         | `enum` value not in declared member list                       |
| `invalid_list`         | `list` value not in declared member list                       |
| `missing_param`        | Required param not provided and no default declared            |
| `unclosed_block`       | `do` with no matching `end`                                    |
| `mismatched_end`       | `end @var` does not match the open block's variable            |
| `nesting_exceeded`     | Block depth exceeds 3 levels                                   |
| `unknown_vary`         | Seed provided but no `vary` blocks in the prompt               |
| `missing_fragment`     | Referenced file not found                                      |
| `missing_index`        | Folder referenced as collection has no `_index.prompt`         |
| `collection_no_match`  | No fragments matched the given value                           |
| `incompatible_contracts` | `response` blocks across branches have different fields or types |
| `invalid_matchre_type` | `matchRe` used with a non-`enum` variable                      |
| `missing_major_bump`   | Breaking change committed without a major version increment    |
| `invalid_response_json` | `response` block contains malformed JSON                       |

---

## Full Example

```
init do
  @version: 1.0

  def:
    mode: explanation
    role: assistant
    description: Teacher mode — explanation phase with dynamic depth control.

  params:
    @skill_names: list[Milton Model, Meta Model, Anchoring, Reframing]
      -> skills to load — matched against skills collection
    @pattern_step: int[1..3] = 1 -> current step in the teaching sequence
    @variation: enum[analogy, recognition, story] = analogy
      -> teaching track — selected once per session
    @answer_depth: enum[shallow, medium, deep] = medium -> depth of question answers
    @if_input_mode_question: bool = false -> true when user has asked a question
    @user_input: str -> the user's current message
    @user_level: enum[beginner, intermediate, advanced] = intermediate
    @intro_style: enum[formal, curious, story] = curious
      -> opening variation — selected by runtime
    @closing_style: enum[exercise, reflection] = exercise

  fragments:
    {skill_context}: static from: skills
      filter: @skill_names
    {{user_history}}: dynamic -> recent conversation history

  docs do
    Select @variation once at session start and hold it constant.
    Increment @pattern_step each turn.
    Set @if_input_mode_question true when user asks an off-pattern question.
  end docs

end init

# ROLE
You are Milton, an expert NLP trainer teaching @user_level students.
Your job is to teach @skill_names using structured teaching patterns.

vary @intro_style do
  formal: Begin with a structured overview of what we will cover today.
  curious: Begin with a question that creates productive curiosity.
  story: Begin with a brief story that illustrates why this skill matters.
end @intro_style

if @if_input_mode_question is true do

  # Question mode
  STOP TEACHING FLOW. Answer the user's question directly.
  
  The user asked: @user_input
  
  {skill_context}
  
  {{user_history}}
  
  case @answer_depth do
    shallow: Shallow Answer
    1-2 sentences answering exactly what was asked.
    
    medium: Medium Answer
    Explanation plus one relevant example from the context.
    
    deep: Deep Answer
    Full explanation with multiple examples from the context.
  end @answer_depth

Respond in exactly this JSON format:
{response_contract}

response do
  {
    "response_type": "question_answer",
    "content": "string",
    "ui_hints": {
      "show_answer_input": false,
      "show_success": false
    }
  }
end response

else

  # Teaching mode
  case @variation do
  analogy: #Analogy Track
    case @pattern_step do
      1: Opening Anchor
        Introduce @skill_names with a single real-world analogy.
      
      2: Deepening the Frame
        Build on the analogy. Layer in the formal definition.
      
      3: Concrete Examples
        Give two examples. Ask which felt more natural.
  end @pattern_step

recognition: #Recognition Track
case @pattern_step do
1: Opening Anchor
Open with a question that makes the user realise they already use @skill_names.

2: Deepening the Frame
Return to their recognition. Use their words to introduce the formal framing.

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

Respond in exactly this JSON format:
{response_contract}

response do
  {
    "response_type": "teaching",
    "content": "string",
    "ui_hints": {
      "show_answer_input": true,
      "show_success": false
    }
  }
end response

end @if_input_mode_question
```

---

## Quick Reference

### Sigils

| Sigil    | Meaning                            |
| -------- | ---------------------------------- |
| `@name`  | Variable                           |
| `{name}` | Static fragment                    |
| `{{name}}` | Dynamic fragment                   |
| `#`      | Comment — stripped at compile time |
| `->`     | Documentation                      |
| `=`      | Default value                      |

### Block syntax

```
keyword do
  ...
end keyword_or_@variable
```

Every block opens with `do`. Every block closes with `end`.

### Types at a glance

| Type      | Branching | Example                        |
| --------- | --------- | ------------------------------ |
| `str`     | No        | `@user_input: str`             |
| `int`     | No        | `@count: int`                  |
| `int[a..b]` | Yes       | `@step: int[1..5] = 1`         |
| `bool`    | Yes       | `@show_hint: bool = false`     |
| `enum[...]` | Yes       | `@mode: enum[fast, slow] = fast` |
| `list[...]` | Yes       | `@skills: list[A, B, C]`       |

### Control flow at a glance

| Block | Variable type   | Selection        |
| ----- | --------------- | ---------------- |
| `if`  | Any finite type | Conditional      |
| `case` | `enum`, `int[a..b]` | Deterministic    |
| `vary` | `enum` only     | Random or seeded |

<!-- fullWidth: false tocVisible: false tableWrap: true -->
