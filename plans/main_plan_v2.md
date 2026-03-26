# dot-prompt Specification
**Version 1.2 — Response Contracts + Versioning**

A compiled domain-specific language for authoring structured LLM prompts.
dot-prompt compiles to a clean, flat prompt string. The LLM receives only
the resolved output — no syntax artifacts, no untaken branches, no dead weight.

dot-prompt never makes LLM calls. It returns a string. What the caller
does with that string is entirely their concern.

---

## What Changed in v1.1

Applied to the already implemented v1.0 codebase:

1. `@` means variable and only variable — structural keywords never use `@`
2. `init do / end init` — not `@init do / end @init`
3. `docs do / end docs` — not `@docs do / end @docs`
4. `vary` requires an enum variable — no unnamed vary blocks
5. `vary` closes with `end @variable` — consistent with all control flow
6. Named vary branches — `formal:` not `a:`
7. `vary` accepts single optional `seed:` — `seeds:` plural removed entirely
8. One seed drives all vary blocks — hashed against vary variable name internally
9. Default values on params using `=` — `@answer_depth: enum[shallow, medium, deep] = medium`
10. Multiline `->` documentation using indented continuation
11. `@version` promoted to top level of `init` block — out of `def:`
12. No `@system` / `@user` blocks — caller decides how to split the string
13. No `@const` — model config is outside dot-prompt boundary
14. No reserved variable names — author names everything
15. No `@note` — covered by `#` and `docs`
16. No `when` — keep `if` and `case`
17. No `@include` — fragments cover all composition needs
18. No `seeds:` plural in API — only `seed:` singular
19. No `skills:` block in `_index.prompt` — folder structure is the registry
20. No select rules in `_index.prompt` — assembly rules live in calling prompt
21. No `order: random` in fragments — random selection belongs in `vary`
22. No dynamic regex matching — callers preprocess before calling dot-prompt
23. No trailing `/` on folder paths — compiler resolves file vs folder automatically
24. `list[...]` and `enum[...]` — members declared inline, no `list[str]` or `list[enum]`
25. `enum` single value → one fragment, `list` multiple values → composited fragments
26. `filter: @variable` — exact match against fragment `def.match` field
27. `filterRe: pattern` — compile-time regex, supports `@variable` interpolation (enum variables only)
28. `filter: all` — returns every fragment in folder
29. `limit: n`, `order: ascending / descending` — assembly rules in calling prompt only
30. `_index.prompt` declares folder metadata and params only — no assembly rules

---

## What Changed in v1.2

New features added on top of v1.1:

1. `response do / end response` block in prompt body — not in init
2. Response block contains raw JSON shape — compiler derives contract schema
3. `{response_contract}` reference — injects response JSON into compiled prompt as LLM instruction
4. Multiple `response` blocks allowed — one per branch
 5. Compiler collects all response blocks and compares shapes across branches — compatible → warning, incompatible → error
 6. `DotPrompt.Result` struct returned instead of plain string from all compile/render calls
 7. `result.prompt` — compiled prompt string, `result.response_contract` — derived schema
 8. `DotPrompt.validate_output/3` — validates LLM JSON response against contract
 9. HTTP API returns both `prompt` and `response_contract` in all responses
10. `@version` becomes `major.minor` — managed automatically by container on commit
11. No separate `@major` field — major derived from first number in `@version`
12. Developer never manually edits `@version` after initial declaration
13. Breaking change without minor version increment → hard warning at commit
14. Non-breaking change → minor auto-bumped on commit silently
15. Server serves multiple major versions simultaneously
16. API caller pins to major — served latest minor automatically
17. `GET /api/schema/:prompt/:major` — schema for specific major version
18. Current version always at top level — no version suffix in filename
19. Old major versions in local `archive/` as `name_v{major}.prompt`
20. `archive/` folders are never collections — no `_index.prompt` inside
21. Container detects breaking change on every file save
22. Viewer prompts developer — `Version it` / `Not now` / `Ignore always`
23. `Ignore always` — suppressed until git commit, then hard warning
24. Non-breaking changes — silent, minor auto-bumped on commit
25. Post-commit hook — one line in `.git/hooks/post-commit`, pings container
26. Container mounts full app repo — runs git commands against it
27. `POST /api/version` — version it action from VS Code or viewer
28. `POST /webhooks/commit` — triggered by post-commit hook
29. Container exposes SSE stream at `GET /api/events`
30. VS Code extension subscribes to SSE on startup
31. Breaking change fires native VS Code notification — `Version it` / `Not now`
32. Inline diagnostic squiggle on changed params or response block
33. Container snapshots file to `.snapshots/` on first save after last commit
34. Subsequent saves do not update snapshot — only first save matters
35. On `Version it` — snapshot moved to `archive/` as old major version
36. On git commit — snapshot cleared, committed version is new baseline
37. `.snapshots/` gitignored — never committed, never deployed

---

## What It Is

dot-prompt is a deterministic structural reducer. It shapes one prompt for
one LLM call. It is not a workflow engine, state machine, or conversation
manager. dot-prompt never makes LLM calls — it returns a compiled string.
The caller decides what to do with it.

| Layer | Responsibility |
|-------|---------------|
| dot-prompt | Shape one prompt + response contract deterministically, return `DotPrompt.Result` |
| State machine | Orchestrate multiple prompt calls and conversation flow |
| Caller | Make the LLM call, validate response with `DotPrompt.validate_output/3` |

---

## Project Structure

Umbrella app — one repo, two apps, clean separation.

```
dot-prompt/
├── apps/
│   ├── dot_prompt/                    # core Hex library — published to Hex
│   │   ├── lib/
│   │   │   └── dot_prompt/
│   │   │       ├── parser/
│   │   │       │   ├── lexer.ex
│   │   │       │   ├── parser.ex
│   │   │       │   └── validator.ex
│   │   │       ├── compiler/
│   │   │       │   ├── if_resolver.ex
│   │   │       │   ├── case_resolver.ex
│   │   │       │   ├── fragment_expander/
│   │   │       │   │   ├── static.ex
│   │   │       │   │   ├── collection.ex
│   │   │       │   │   └── dynamic.ex
│   │   │       │   └── vary_compositor.ex
│   │   │       ├── cache/
│   │   │       │   ├── structural.ex
│   │   │       │   ├── fragment.ex
│   │   │       │   └── vary.ex
│   │   │       ├── injector.ex
│   │   │       └── telemetry.ex
│   │   └── mix.exs
│   │
│   └── dot_prompt_server/             # container app — HTTP API + MCP + viewer
│       ├── lib/
│       │   └── dot_prompt_server/
│       │       ├── api/
│       │       │   ├── router.ex
│       │       │   └── controllers/
│       │       │       ├── compile_controller.ex
│       │       │       ├── render_controller.ex
│       │       │       └── schema_controller.ex
│       │       ├── mcp/
│       │       │   ├── server.ex
│       │       │   └── tools/
│       │       │       ├── schema.ex
│       │       │       ├── compile.ex
│       │       │       └── list.ex
│       │       └── viewer/
│       │           ├── live/
│       │           │   ├── viewer_live.ex
│       │           │   └── stats_live.ex
│       │           └── router.ex
│       └── mix.exs
│
├── Dockerfile
├── docker-compose.yml
├── mix.exs
└── README.md
```

---

## Deployment Contexts

| Context | What runs |
|---------|-----------|
| Elixir production (TealSpeech) | `dot_prompt` Hex library — compiled into release, zero latency |
| All other languages | HTTP API via container |
| Local development | Container — viewer on :4040, API on :4041, MCP on stdio |
| CI | `dot_prompt` library tests only |

```elixir
# TealSpeech mix.exs — native, no HTTP
{:dot_prompt, "~> 1.1"}
```

```bash
# All other languages — container
docker run -v ./prompts:/prompts -p 4040:4040 -p 4041:4041 dotprompt/server
```

---

## Sigils — Final

| Sigil | Meaning | Example |
|-------|---------|---------|
| `@name` | Variable — always and only | `@skill_name`, `@pattern_step` |
| `{}` | Static fragment — cached | `{skill_context}` |
| `{{}}` | Dynamic fragment — fetched fresh | `{{user_history}}` |
| `#` | Comment — never reaches LLM | `# this is a note` |
| `->` | Documentation — surfaces via MCP | `@skill_name: str -> the NLP skill` |

`@` means variable. Everywhere. Always. No exceptions.
Structural keywords — `init`, `docs`, `if`, `case`, `vary`, `else`, `elif`,
`end`, `def`, `params`, `fragments`, `select` — never use `@`.

---

## Keywords — Final

**Structural:**
| Keyword | Role |
|---------|------|
| `init` | File setup block |
| `docs` | Documentation block inside init |
| `def` | Metadata section inside init |
| `params` | Variable declarations inside init |
| `fragments` | Fragment declarations inside init |
| `select` | Collection selection rules inside _index |

**Control flow:**
| Keyword | Role |
|---------|------|
| `if` | Conditional block |
| `elif` | Chained condition |
| `else` | Fallback branch |
| `case` | Deterministic branch selection |
| `vary` | Seeded or random branch selection — requires enum variable |
| `end` | Closes any block |
| `do` | Opens any block |

**Condition operators:**
| Keyword | Meaning |
|---------|---------|
| `is` | Equality |
| `not` | Inequality |
| `above` | Greater than |
| `below` | Less than |
| `min` | Greater than or equal |
| `max` | Less than or equal |
| `between` | Range — used as `between x and y` |
| `and` | Range separator — only inside `between x and y` |

**Types:**
| Keyword | Domain | Lifecycle |
|---------|--------|-----------|
| `str` | Infinite | Runtime |
| `int` | Infinite | Runtime |
| `int[a..b]` | Finite | Compile-time |
| `bool` | Finite | Compile-time |
| `enum[...]` | Finite | Compile-time — single value |
| `list[...]` | Finite | Compile-time — multiple values |

**Fragment assembly:**
| Keyword | Role |
|---------|------|
| `static` | Fixed cacheable fragment |
| `dynamic` | Live fetched fragment |
| `from` | Fragment source path — file or folder |
| `filter` | Exact match against fragment `def.match` field |
| `filterRe` | Compile-time regex match — enum variables only — supports `@variable` interpolation |
| `all` | Match every fragment in folder |
| `limit` | Cap number of matched fragments |
| `order` | `ascending` or `descending` |
| `set` | Pass variables to fragment — left: fragment param, right: parent variable |

---

## File Structure

Every `.prompt` file has two parts:

```
init do
  ...metadata, params, fragments, docs...
end init

...prompt body...
```

`init` uses the same `do / end name` convention as all other blocks.
No file separators required. Everything outside `init` is prompt body.
`init` must appear at the top of the file.

---

## Init Block

```
init do
  @version: 1

  def:
    mode: explanation
    description: Teacher mode — explanation phase with dynamic depth control.

  params:
    @skill_names: list[Milton Model, Meta Model, Anchoring, Reframing]
      -> skills to load — matched against skills collection
    @pattern_step: int[1..5] = 1 -> current step in the teaching sequence
    @variation: enum[analogy, recognition, story] = analogy
      -> teaching track
    @answer_depth: enum[shallow, medium, deep] = medium -> depth of question answers
    @if_input_mode_question: bool = false -> true when user has asked a question
    @user_input: str -> the user's current message
    @user_level: enum[beginner, intermediate, advanced] = intermediate
      -> user experience level

  fragments:
    {skill_context}: static from: skills
      match: @skill_names
      -> loads and composites all matching skill definitions
    {{user_history}}: dynamic -> recent conversation history for context

  docs do
    Teaches NLP skills using a structured multi-turn pattern.
    Variation track is selected once per session and held constant.
    Increment @pattern_step each turn.
    Set @if_input_mode_question true when user asks an off-pattern question.
    @skill_names must exist as .prompt files in the skills folder.
  end docs

end init
```

### @version Only

`@version` is `major.minor` — the first number is the major version.
The container manages `@version` automatically — developer sets on initial
declaration and never edits after that.

```
init do
  @version: 1.0
  ...
end init
```

| Field | Managed by | Meaning |
|-------|------------|--------|
| `@version` | Container (auto) | `major.minor` — first number is breaking change boundary |

**Rules:**
- `@version: 0.x` is invalid — major must be ≥ 1
- After initial declaration, developer never touches `@version`
- Container bumps minor on non-breaking commit
- Container increments major on `Version it` action (breaking change declared)
- Breaking change without major bump → hard warning at commit
- `@version` in cache keys and telemetry — minor bump invalidates structural cache

### def:

| Field | Purpose |
|-------|---------|
| `mode` | Prompt mode identifier — informational |
| `description` | Human readable description |

### params:

All variables declared here. Type determines lifecycle.
Default values use `=` after the type declaration. Parser reads string defaults to end of line, no quotes required.
Documentation uses `->` — inline or multiline with indented continuation.

```
params:
  @answer_depth: enum[shallow, medium, deep] = medium -> depth of question answers
  @skill_names: list[Milton Model, Meta Model]
    -> skills to load
       must exist in the skills collection
       matched exactly against fragment def.match fields
  @user_input: str -> the user's current message — no default, always required
```

### fragments:

Declares all external content. Assembly rules live here, not in `_index.prompt`.

```
fragments:
  # Single file — path resolves to a file
  {rules}: static from: shared/rules.prompt

  # Collection — path resolves to a folder with _index.prompt
  # enum single value — returns one fragment
  {primary_skill}: static from: skills
    match: @primary_skill

  # Collection — list multiple values — returns composited fragments
  {skill_context}: static from: skills
    match: @skill_names

  # Collection — regex match — compile-time only
  {milton_variants}: static from: skills
    matchRe: Milton.*
    limit: 3
    order: ascending

  # Collection — all fragments in folder
  {all_examples}: static from: examples
    match: all
    order: ascending

  # Dynamic — fetched fresh each request, not cached
  {{user_history}}: dynamic -> recent conversation history
```

### docs:

Free text documentation. Surfaces through MCP `prompt_schema` calls.

```
docs do
  Teaches NLP skills using a structured multi-turn pattern.
  Variation track selected once per session and held constant.
end docs
```

---

## Prompt Folder Structure

### Current version — top level

The current (latest) version of a prompt lives at the top level with no suffix.

```
priv/prompts/
  concept_explanation.prompt     # latest major
  skills/
    _index.prompt
    milton_model.prompt
    ...
  archive/
    concept_explanation_v1.prompt  # archived major 1
    concept_explanation_v2.prompt  # archived major 2
    skills/
      archive/
        milton_model_v1.prompt
```

**Rules:**
- Current version: `name.prompt` at top level — no suffix, no version folder
- Archived majors: `archive/name_v{major}.prompt`
- Collections with archives: `collection_name/archive/fragment_v{major}.prompt`
- `archive/` folders **never** contain `_index.prompt` — they are not collections
- `.snapshots/` lives alongside `archive/` — gitignored, never committed

```
priv/prompts/
  concept_explanation.prompt          # current (e.g. major 3)
  .snapshots/
    concept_explanation.prompt.snap   # pre-edit snapshot, cleared on commit
  archive/
    concept_explanation_v1.prompt
    concept_explanation_v2.prompt
  skills/
    _index.prompt
    milton_model.prompt
    archive/
      milton_model_v1.prompt
```

---

## Fragment Collections

Any folder with an `_index.prompt` is a collection.
The `_index.prompt` declares the folder metadata and params.
Assembly rules are declared in the calling prompt — not in `_index.prompt`.

| Rule | Syntax | Requirement |
|------|--------|-------------|
| Exact match | `filter: @variable` | `enum` or `list` |
| Regex match | `filterRe: @variable` | `enum` only — compile-time check |
| All | `filter: all` | none |
| Limit | `limit: n` | `integer` |
| Order | `order: ascending / descending` | — |
| Set variables | `set: left: @right` | left is fragment param (no @), right is parent var (has @) |

```
priv/prompts/skills/
  _index.prompt
  milton_model.prompt
  meta_model.prompt
  anchoring.prompt
  reframing.prompt
```

### _index.prompt

```
init do
  @version: 1

  def:
    mode: collection
    description: NLP skills collection

  docs do
    Each .prompt file in this folder declares its match field in def.
    Add new skills by dropping a file in with the correct match value.
    No code changes or registry updates needed.
  end docs

end init
```

No assembly rules. No skills registry. Just metadata and docs.

### Individual fragment file

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
It is a plain string. The calling prompt's `filter:` or `filterRe:` finds it.

---

## Prompt Body

Plain prose with inline variable references and control flow blocks.
Indentation has no semantic meaning. Maximum nesting depth is 3 levels.
Only finite domain variables can appear in control flow conditions.

### Comments

```
# This section handles question interruptions — stripped, never reaches LLM
if @if_input_mode_question is true do
...
end @if_input_mode_question
```

### Variable References

Runtime variables injected at call time — left as placeholders after compile:

```
You are teaching @user_level students about @skill_names.

@user_input
```

### Fragment References

```
# Static — compiled from another .prompt file, cached
{skill_context}

# Dynamic — fetched fresh each request
{{user_history}}
```

---

## Control Flow

All blocks open with `do` and close with `end @variable` or `end keyword`.
Indentation is optional. Maximum nesting depth is 3 levels.

### If

Evaluates a finite domain variable. Natural language conditions.

```
if @if_input_mode_question is true do
STOP TEACHING FLOW. Answer the user's question directly.

elif @pattern_step is 1 do
This is the opening step. Introduce yourself briefly.

else
Continue the normal teaching flow.
end @if_input_mode_question
```

Full condition reference:

| Syntax | Meaning | Types |
|--------|---------|-------|
| `if @var is x do` | equality | `bool`, `enum`, `int[a..b]` |
| `if @var not x do` | inequality | `enum`, `int[a..b]` |
| `if @var above x do` | greater than | `int[a..b]` |
| `if @var below x do` | less than | `int[a..b]` |
| `if @var min x do` | greater than or equal | `int[a..b]` |
| `if @var max x do` | less than or equal | `int[a..b]` |
| `if @var between x and y do` | inclusive range | `int[a..b]` |

### Case

Deterministic branch selection. Caller always provides the value.
Optional title after `:` compiles through to LLM.
Prefix title with `#` to keep as author documentation only.

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

Non-deterministic branch selection. Requires an enum variable.
Runtime randomizes selection unless a seed is provided.
Caller never manages which branch was selected — dot-prompt handles it.
Named branches — descriptive words not single letters.

```
@intro_style: enum[formal, curious, story] = formal -> opening style, selected by runtime

vary @intro_style do
formal: Begin with a structured overview of what we will cover.
curious: Begin with a question that creates productive curiosity.
story: Begin with a brief story that illustrates the concept.
end @intro_style
```

**Seeding:**

One optional seed drives all vary blocks in the prompt.
The seed is hashed against each vary variable name to produce
independent selections per block from a single seed value.

```elixir
# No seed — runtime picks randomly for each vary block
DotPrompt.compile("concept_explanation", params)

# Single seed — deterministic, reproducible, cacheable
DotPrompt.compile("concept_explanation", params, seed: 42)
```

Via HTTP API:
```json
{ "seed": 42 }
```

### Nested Case — Variation Tracks

`case @variation` outside, `case @pattern_step` inside.
Each variation track is a coherent narrative arc.
Track titles prefixed with `#` are author docs only — do not compile through.
Step titles without `#` compile through to the LLM.

```
case @variation do
analogy: #Analogy Track
case @pattern_step do
1: Opening Anchor
Introduce @skill_names with a single real-world analogy.
Do not define it formally yet. Let the analogy do the work.

2: Deepening the Frame
Build on the analogy from step 1. Layer in the formal
definition of @skill_names without abandoning the analogy.

3: Concrete Examples
Give 2 examples of @skill_names in real conversation.
First obvious, second subtle. Ask which felt more natural.
end @pattern_step

recognition: #Recognition Track
case @pattern_step do
1: Opening Anchor
Open with a question that makes the user realise they
already use @skill_names without knowing it.

2: Deepening the Frame
Return to the user's own recognition from step 1.
Use their words to introduce the formal framing.

3: Concrete Examples
Ask the user to generate their own example first.
Then offer one refinement and one contrast.
end @pattern_step

story: #Story Track
case @pattern_step do
1: Opening Anchor
Start with a brief story where @skill_names changed
the outcome of a conversation.

2: Deepening the Frame
Extend the story. Show how @skill_names was operating
beneath the surface the whole time.

3: Concrete Examples
Show @skill_names being used poorly then well.
Ask what changed.
end @pattern_step

end @variation
```

**Compiled output** for `variation: recognition`, `pattern_step: 2`:

```
Deepening the Frame
Return to the user's own recognition from step 1.
Use their words to introduce the formal framing.
```

---

## Compilation Pipeline

Compilation is lazy — on demand per request, not pre-computed.
Three independent cache layers maximise reuse.

```
Request arrives with compile-time params (+ optional seed)
      │
      ▼
  [Stage 1] Validate
            check all compile-time @params against declared types
            validate enum/list values against declared members
            check int[a..b] values within bounds
            apply defaults for any missing params with default values
            STOP on any error — never silent
            error includes: file, line, variable name, descriptive message

      │
      ▼
  [Stage 2] Resolve if/case control flow
            vary blocks left as named slots — not resolved yet
            ──────────────────────────────────────────────
            STRUCTURAL CACHE
            key   = prompt name + @version + compile-time params hash
            value = resolved skeleton with vary slots intact
            ──────────────────────────────────────────────

      │
      ▼
  [Stage 3] Expand fragments
            static {} — compile referenced .prompt files with passed params
            collections — resolve _index.prompt, apply calling prompt assembly rules
            match/matchRe/all → select files → compile each → composite in order
            ──────────────────────────────────────────────
            STATIC FRAGMENT CACHE
            key   = fragment path + @version + passed params hash
            value = compiled fragment content
            preloadable at application startup
            ──────────────────────────────────────────────
            dynamic {{}} — fetch fresh each request, not cached
            only fragments in surviving branch are fetched

      │
      ▼
  [Stage 4] Resolve vary slots
            for each vary slot in structural skeleton:
              if seed provided: hash(seed + vary_variable_name) → branch index
              if no seed: random branch selection
            composite selected branches into skeleton — pure string replacement
            ──────────────────────────────────────────────
            VARY BRANCH CACHE
            key   = prompt name + vary variable name + branch name
            value = branch content
            preloadable at application startup
            ──────────────────────────────────────────────

      │
      ▼
  [Stage 5] Inject runtime @variables
            fill runtime variable placeholders just before LLM call

      │
      ▼
  Final prompt string → caller → LLM call (caller's responsibility)
```

### Cache Summary

| Cache | Key | Cacheable | Preloadable |
|-------|-----|-----------|-------------|
| Structural | prompt + version + compile-time params | Always | No |
| Static fragment | fragment path + version + params | Always | Yes |
| Vary branch | prompt + vary variable + branch name | Always | Yes |
| Dynamic fragment | — | Never | No |

### Dev vs Prod Mode

```
Dev:   full parse → compile → inject on every request
       no caching — prompt files reloaded on every change via file watcher

Prod:  Stage 1 → check structural cache
       hit:  Stage 3 (dynamic only) → Stage 4 → Stage 5
       miss: Stage 2 → Stage 3 → Stage 4 → cache → Stage 5
```

---

## Response Contracts

A `response do / end response` block in the **prompt body** (not in `init`) declares the
expected JSON shape of the LLM's response. The compiler derives a strongly-typed contract
from it and returns it alongside the compiled prompt.

### Syntax

```
case @mode do
teaching: Teach the concept.
response do
  {
    "response_type": "teaching",
    "content": "string",
    "confidence": "number"
  }
end response

question: Answer the question.
response do
  {
    "response_type": "question",
    "answer": "string"
  }
end response
end @mode
```

### {response_contract}

A special fragment reference that injects the derived response contract into the compiled
prompt as a structured JSON instruction to the LLM:

```
Provide your response in exactly this JSON format:
{response_contract}
```

This is replaced by the compiler with the contract JSON. The LLM sees the actual JSON shape.

### Multiple response blocks — validation rules

Compiler collects all `response` blocks across all branches and compares their shapes:

| Scenario | Compiler action |
|----------|-----------------|
| All blocks identical | Silent — no warning |
| Same fields, different values | Warning: `compatible_contracts` — field names match, values differ |
| Different fields or types | Error: `incompatible_contracts` — compilation fails |
| One block missing in a branch | Warning: `missing_contract` — branch has no response shape |

### DotPrompt.Result

All compile and render calls return a `DotPrompt.Result` struct instead of a plain string:

```elixir
%DotPrompt.Result{
  prompt: "You are teaching intermediate students...",
  response_contract: %{
    "response_type" => %{type: "string", required: true},
    "content" => %{type: "string", required: true},
    "confidence" => %{type: "number", required: false}
  },
  vary_selections: %{"intro_style" => "curious"},
  compiled_tokens: 312,
  cache_hit: true
}
```

### DotPrompt.validate_output/3

Validates an LLM JSON response string against a response contract:

```elixir
case DotPrompt.validate_output(llm_response, result.response_contract) do
  :ok -> # valid
  {:error, reason} -> # invalid — reason describes the mismatch
end

# Strict mode — extra fields are rejected
DotPrompt.validate_output(llm_response, contract, strict: true)
```

---

## Error Handling

Compiler stops immediately on any error. Never silent.
Every error includes file name, line number, variable name, and message.

| Error | Example message |
|-------|----------------|
| `unknown_variable` | `@skill_level referenced but not declared — concept_explanation.prompt line 24` |
| `out_of_range` | `@pattern_step value 7 out of range int[1..5] — line 12` |
| `invalid_enum` | `@variation value fast not in enum[analogy, recognition, story] — line 8` |
| `invalid_list` | `@skill_names value Unknown Skill not in list — line 9` |
| `invalid_filterre_type`| `filterRe requires enum variable, but @var is str — line 24` |
| `set_type_mismatch` | `set: name: @user_name — type mismatch: parent is str, fragment expects int — line 24` |
| `set_undeclared_var` | `set: name: @unknown — @unknown not declared in parent params — line 24` |
| `set_unknown_param` | `set: unknown_param: @name — unknown_param not in fragment params — line 24` |
| `missing_param` | `@answer_depth required but not provided — no default declared` |
| `unclosed_block` | `if @if_input_mode_question do opened at line 31 — no matching end` |
| `mismatched_end` | `end @answer_depth at line 45 — expected end @if_input_mode_question` |
| `nesting_exceeded` | `nesting depth 4 at line 67 — maximum is 3` |
| `unknown_vary` | `seed provided but no vary blocks found in prompt` |
| `missing_fragment` | `shared/rules.prompt not found` |
| `missing_index` | `skills folder has no _index.prompt` |
| `collection_no_match` | `no fragments matched Milton Modelx in skills` |
| `incompatible_contracts` | `response blocks have incompatible schemas — teaching branch missing "answer" field` |
| `compatible_contracts` | (warning) `response blocks have same fields but different value types across branches` |

---

## Versioning Workflow

The container manages major/minor versioning automatically. The developer only declares
`@version` on initial file creation. After that, the container owns it.

### File save — breaking change detection

```
Developer saves file
      │
      ▼
Container compares saved file to .snapshots/ baseline
      │
      ├── No change detected → silent
      ├── Non-breaking change → silent (minor bumped at commit)
      └── Breaking change detected
            │
            ├── VS Code notification: "Breaking change in concept_explanation"
            │     [ Version it ]  [ Not now ]  [ Ignore always ]
            │
            └── Viewer prompt: same three options
```

### On "Version it"

1. Snapshot moved to `archive/concept_explanation_v{current_major}.prompt`
2. `@version` incremented (e.g., 1.5 → 2.0, so major changes from 1 to 2)
3. New snapshot taken of the versioned file

### On "Ignore always"

- Breaking change suppressed in viewer and VS Code until next git commit
- On commit — hard warning fires regardless

### On git commit — post-commit hook

```bash
# .git/hooks/post-commit (single line)
curl -s -X POST http://localhost:4041/webhooks/commit > /dev/null
```

```
Commit fires POST /webhooks/commit
      │
      ▼
Container runs git diff HEAD~1 HEAD against repo
      │
      ├── Breaking change unversioned → hard error logged, developer notified
      ├── Non-breaking change → @version minor auto-bumped, .snapshot/ cleared
      └── No prompt change → snapshot cleared, new baseline set
```

### Endpoints

| Endpoint | Purpose |
|----------|---------|
| `POST /api/version` | Trigger "Version it" — archives current, bumps major |
| `POST /webhooks/commit` | Triggered by post-commit hook — runs diff, bumps minor |
| `GET /api/events` | SSE stream — breaking change events, version notifications |

---

## Breaking Change Definitions

### Input changes — breaking

| Change | Example |
|--------|---------|
| Removing a param | `@skill_names` deleted |
| Changing param type | `str` → `enum[...]` |
| Renaming a param | `@level` → `@user_level` |
| Removing a default from required param | `= medium` removed |
| Narrowing an enum — removing valid values | `enum[a, b, c]` → `enum[a, b]` |

### Input changes — non-breaking

| Change | Example |
|--------|---------|
| Adding a param with a default | `@theme: enum[light, dark] = light` |
| Adding new enum values | `enum[a, b]` → `enum[a, b, c]` |
| Changing documentation | `->`  doc text updated |
| Changing defaults | `= medium` → `= deep` |
| Prompt body changes with no contract change | Prose rewrite |

### Output changes — breaking

| Change | Example |
|--------|---------|
| Removing a response field | `"content"` deleted from response block |
| Renaming a response field | `"content"` → `"body"` |
| Changing a response field type | `"count": "number"` → `"count": "string"` |
| Adding a required response field | New field with `required: true` |

### Output changes — non-breaking

| Change | Example |
|--------|---------|
| Adding optional fields | New field with `required: false` |
| Changing prose or step instructions | Prompt body text update |

---

## VS Code Integration

The container exposes an SSE stream. The VS Code extension subscribes on startup
and surfaces breaking change notifications without leaving the editor.

### SSE stream — GET /api/events

```
Event types:
  breaking_change  — file has an unversioned breaking change
  version_bumped   — major or minor version updated
  compile_error    — syntax or validation error on save
  commit_warning   — unversioned breaking change present at commit
```

```javascript
// VS Code extension
const evtSource = new EventSource("http://localhost:4041/api/events");
evtSource.addEventListener("breaking_change", (e) => {
  const { file, change_summary } = JSON.parse(e.data);
  vscode.window.showWarningMessage(
    `Breaking change in ${file}: ${change_summary}`,
    "Version it", "Not now"
  ).then(choice => {
    if (choice === "Version it") fetch("http://localhost:4041/api/version", ...);
  });
});
```

### Inline diagnostics

The extension registers a diagnostic provider. When the SSE stream emits a
`breaking_change` event, the extension places a squiggle on:
- The changed param declaration line
- The changed `response do` block

This gives the developer precise line-level feedback without leaving the file.

---

## Snapshots

Snapshots are pre-edit baselines used to detect what changed since the last commit.

### Lifecycle

```
First save after commit
      │
      └── Container writes .snapshots/name.prompt.snap

Subsequent saves (same commit cycle)
      │
      └── Snapshot unchanged — diff always against first-save baseline

On "Version it"
      │
      └── Snapshot moved to archive/name_v{major}.prompt
          New snapshot taken of versioned file

On git commit
      │
      └── Snapshot cleared — committed file is new baseline
```

**Rules:**
- `.snapshots/` is gitignored — never committed, never deployed
- Snapshot triggered by file change event — not a timer
- Only one snapshot per file per commit cycle — first save wins
- Snapshot cleared on commit even if no version action was taken

---

## HTTP API

Container exposes REST API on port 4041.

### POST /api/compile

```json
// Request
{
  "prompt": "concept_explanation",
  "params": {
    "pattern_step": 2,
    "variation": "recognition",
    "answer_depth": "medium",
    "if_input_mode_question": false,
    "skill_names": ["Milton Model", "Meta Model"]
  },
  "seed": 42
}

// Response
{
  "template": "You are teaching @user_level students...",
  "cache_hit": true,
  "compiled_tokens": 312,
  "vary_selections": {
    "intro_style": "curious",
    "closing_style": "exercise"
  },
  "response_contract": {
    "response_type": {"type": "string", "required": true},
    "content": {"type": "string", "required": true}
  }
}
```

### POST /api/inject

```json
// Request
{
  "template": "You are teaching @user_level students...",
  "runtime": {
    "user_input": "Can you give me an example?",
    "user_level": "intermediate"
  }
}

// Response
{
  "prompt": "You are teaching intermediate students...",
  "injected_tokens": 387
}
```

### POST /api/render

```json
// Request
{
  "prompt": "concept_explanation",
  "params": {
    "pattern_step": 2,
    "variation": "recognition",
    "answer_depth": "medium",
    "if_input_mode_question": false,
    "skill_names": ["Milton Model"]
  },
  "runtime": {
    "user_input": "Can you give me an example?",
    "user_level": "intermediate"
  },
  "seed": 42
}

// Response
{
  "prompt": "You are teaching intermediate students...",
  "cache_hit": true,
  "compiled_tokens": 312,
  "injected_tokens": 387,
  "vary_selections": {
    "intro_style": "curious"
  },
  "response_contract": {
    "response_type": {"type": "string", "required": true},
    "content": {"type": "string", "required": true}
  }
}
```

### GET /api/schema/:prompt

Returns schema for the latest major version.

```json
{
  "name": "concept_explanation",
  "major": 3,
  "version": "3.2",
  "description": "Teacher mode — explanation phase with dynamic depth control.",
  "params": {
    "skill_names": {
      "type": "list",
      "members": ["Milton Model", "Meta Model", "Anchoring", "Reframing"],
      "lifecycle": "compile",
      "default": null,
      "doc": "skills to load — matched against skills collection"
    },
    "pattern_step": {
      "type": "int",
      "range": [1, 5],
      "lifecycle": "compile",
      "default": 1,
      "doc": "current step in the teaching sequence"
    },
    "user_input": {
      "type": "str",
      "lifecycle": "runtime",
      "default": null,
      "doc": "the user's current message"
    },
    "user_level": {
      "type": "enum",
      "members": ["beginner", "intermediate", "advanced"],
      "lifecycle": "runtime",
      "default": "intermediate",
      "doc": "user experience level"
    }
  },
  "fragments": {
    "skill_context": {
      "type": "static",
      "from": "skills",
      "match": "@skill_names",
      "doc": "loads and composites all matching skill definitions"
    },
    "user_history": {
      "type": "dynamic",
      "doc": "recent conversation history for context"
    }
  },
  "response_contract": {
    "response_type": {"type": "string", "required": true},
    "content": {"type": "string", "required": true}
  },
  "docs": "Teaches NLP skills using a structured multi-turn pattern..."
}
```

### GET /api/schema/:prompt/:major

Returns schema for a **specific major version** — reads from `archive/name_v{major}.prompt`.
Callers pin to a major version and receive the latest minor automatically.

```http
GET /api/schema/concept_explanation/1
GET /api/schema/concept_explanation/2
```

Returns 404 if the major version does not exist in `archive/` and is not the current major.

### GET /api/prompts

Lists all available `.prompt` files with name, major, version, description.

### GET /api/collections

Lists all folders with `_index.prompt` with name, version, description.

### POST /api/version

Triggers the "Version it" action for a specific prompt file:

```json
// Request
{ "prompt": "concept_explanation" }

// Response
{
  "archived_as": "concept_explanation_v2.prompt",
  "new_major": 3,
  "new_version": "3.0"
}
```

### POST /webhooks/commit

Triggered by the post-commit git hook. Container runs diff against the repo,
bumps minor versions for non-breaking changes, fires hard warning for unversioned
breaking changes.

```json
// Response
{
  "bumped": ["concept_explanation", "skills/_index"],
  "warnings": [],
  "errors": []
}
```

### GET /api/events

Server-Sent Events stream. Emits `breaking_change`, `version_bumped`,
`compile_error`, and `commit_warning` events as they occur.

---

## Telemetry

Library emits events. Host application attaches handlers and stores.

```elixir
:telemetry.execute(
  [:dot_prompt, :render, :stop],
  %{compiled_tokens: 312, injected_tokens: 387, duration_ms: 12},
  %{
    prompt: "concept_explanation",
    version: 1,
    params: %{variation: :recognition, pattern_step: 2},
    vary_selections: %{intro_style: :curious},
    cache_hit: true
  }
)

:telemetry.attach(
  "dot-prompt-stats",
  [:dot_prompt, :render, :stop],
  &MyApp.PromptStats.handle/4,
  nil
)
```

---

## Elixir Native API

```elixir
# Schema — latest major
DotPrompt.schema("concept_explanation")
DotPrompt.schema("skills")

# Schema — specific major version
DotPrompt.schema("concept_explanation", major: 2)

# Compile — returns DotPrompt.Result
%DotPrompt.Result{} = result = DotPrompt.compile("concept_explanation", %{
  pattern_step: 2,
  variation: :recognition,
  answer_depth: :medium,
  if_input_mode_question: false,
  skill_names: ["Milton Model", "Meta Model"]
}, seed: 42)

result.prompt             # compiled template string
result.response_contract  # derived schema from response blocks
result.vary_selections    # %{"intro_style" => "curious"}
result.compiled_tokens    # 312
result.cache_hit          # true | false

# Inject — accepts DotPrompt.Result or plain string template
final = DotPrompt.inject(result, %{
  user_input: "Can you give me an example?",
  user_level: "intermediate"
})

final.prompt           # fully rendered string
final.injected_tokens  # 387

# Render — compile and inject in one call, returns DotPrompt.Result
result = DotPrompt.render("concept_explanation",
  %{
    pattern_step: 2,
    variation: :recognition,
    answer_depth: :medium,
    if_input_mode_question: false,
    skill_names: ["Milton Model"]
  },
  %{
    user_input: "Can you give me an example?",
    user_level: "intermediate"
  },
  seed: 42
)

# Validate LLM response against the contract
llm_response = "{\"response_type\": \"teaching\", \"content\": \"...\"}"}

case DotPrompt.validate_output(llm_response, result.response_contract) do
  :ok -> # valid
  {:error, reason} -> # invalid
end

# Strict mode — extra fields rejected
DotPrompt.validate_output(llm_response, result.response_contract, strict: true)
```

---

## Python Client

Thin HTTP wrapper. No parser, no compiler.

```python
from dot_prompt import Client

client = Client("http://localhost:4041")

prompt = client.render(
    "concept_explanation",
    params={
        "pattern_step": 2,
        "variation": "recognition",
        "answer_depth": "medium",
        "if_input_mode_question": False,
        "skill_names": ["Milton Model"]
    },
    runtime={
        "user_input": "Can you give me an example?",
        "user_level": "intermediate"
    },
    seed=42
)

schema = client.schema("concept_explanation")
prompts = client.list_prompts()
collections = client.list_collections()
```

---

## MCP Server

Stdio mode — spawned on demand by MCP client, no persistent port.

```json
{
  "dot-prompt": {
    "command": "docker",
    "args": ["exec", "-i", "dot-prompt", "mix", "dot_prompt.mcp"]
  }
}
```

**Tools:**

| Tool | Purpose |
|------|---------|
| `prompt_schema` | Returns params, fragments, docs for a prompt |
| `collection_schema` | Returns metadata and params for a collection |
| `prompt_list` | Lists all available prompt files |
| `collection_list` | Lists all available collections |
| `prompt_compile` | Compiles a prompt with given params for preview |

---

## Docker

```dockerfile
FROM elixir:1.17-alpine
WORKDIR /app
COPY . .
RUN mix deps.get
RUN mix compile
EXPOSE 4040 4041
CMD ["mix", "phx.server"]
```

```yaml
version: "3.8"
services:
  dot-prompt:
    build: .
    ports:
      - "4040:4040"  # viewer
      - "4041:4041"  # HTTP API
    volumes:
      - ./prompts:/app/priv/prompts
    environment:
      - MIX_ENV=dev
```

---

## Full .prompt Example

```
init do
  @version: 1

  def:
    mode: explanation
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
      -> user experience level
    @intro_style: enum[formal, curious, story] = curious
      -> opening variation — selected by runtime
    @closing_style: enum[exercise, reflection] = exercise
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

## Control Flow Reference — Final

| Syntax | Behaviour | Requirement | Closes with |
|--------|-----------|-------------|-------------|
| `init do` | File setup block | Must be first | `end init` |
| `docs do` | Documentation inside init | Inside init only | `end docs` |
| `if @var is x do` | Equality condition | `bool`, `enum`, `int[a..b]` | `end @var` |
| `if @var not x do` | Inequality | `enum`, `int[a..b]` | `end @var` |
| `if @var above x do` | Greater than | `int[a..b]` | `end @var` |
| `if @var below x do` | Less than | `int[a..b]` | `end @var` |
| `if @var min x do` | Greater than or equal | `int[a..b]` | `end @var` |
| `if @var max x do` | Less than or equal | `int[a..b]` | `end @var` |
| `if @var between x and y do` | Inclusive range | `int[a..b]` | `end @var` |
| `elif @var is x do` | Chained condition | same as if | — |
| `else` | Fallback branch | — | — |
| `case @var do` | Deterministic selection | `enum` or `int[a..b]` | `end @var` |
| `vary @var do` | Random or seeded selection | `enum` — required | `end @var` |

All blocks use `do` to open.
Indentation is optional and has no semantic meaning.
Maximum nesting depth is 3 levels.
`@` means variable — always and only.
Structural keywords never use `@`.

---

## Implementation Notes for LLM

**What changed from v1.0 — parser updates needed:**

1. `@init` → `init`, `@docs` → `docs` — update lexer keyword list
2. `vary` now always has a variable — `vary @var do / end @var` — update vary parser rule
3. Named vary branches — branch labels are words not single letters
4. `seeds:` removed from API and compile call — only `seed:` singular
5. Default values — parse `= value` after type declaration in params. String values read to end of line without quotes.
6. Multiline `->` — continuation lines indented under param declaration
7. Fragment assembly rules — `filter`, `filterRe`, `filter: all`, `limit`, `order`, `set` parsed from fragment declarations in init
8. `_index.prompt` — no longer has `skills:` or `select:` blocks — just `init` with `def` and `docs`
9. Fragment paths — no trailing `/` — compiler checks if path is file or directory
10. `@version` — top level field in init, not nested under `def:`
11. Collection assembly — rules come from calling prompt `fragments:` block, not from `_index.prompt`

**What changed from v1.1 — v1.2 parser + compiler updates needed:**

1. `response do / end response` — new block type in prompt body; lexer + parser must handle it
2. `{response_contract}` — new reserved fragment reference; compiler replaces with derived contract JSON
3. No `@major` field — major derived from first number in `@version`
4. `@version` now `major.minor` string format — parser accepts both `1` and `1.0`
5. `DotPrompt.Result` struct — all public API functions return struct, not bare tuple
6. `ResponseCollector` compiler stage — post-case/post-vary collection of response blocks
7. Contract comparison — identical → silent, compatible → warning, incompatible → error
8. `validate_output/3` — new public API, validates JSON string against derived schema
9. `GET /api/schema/:prompt/:major` — new route, reads from archive/
10. `POST /api/version` and `POST /webhooks/commit` — new server endpoints
11. `GET /api/events` — new SSE stream endpoint
12. `.snapshots/` management — container writes/clears on save/commit events

**Vary compositor update:**
Vary variable name is now the slot identifier not a positional name.
Seed hashing: `hash(seed <> vary_variable_name)` → branch index within branch count.
Branch lookup uses branch name not letter index.

**Fragment expander update:**
When path resolves to directory: load `_index.prompt`, read its params,
then apply assembly rules from the calling prompt's fragment declaration.
`filter: @var` — resolve var value, match against fragment `def.match` fields exactly.
`filterRe: pattern` — compile regex, interpolate `@var` references (enum variables only), match against `def.match` fields.
`filter: all` — return all `.prompt` files in folder except `_index.prompt`.
Apply `limit` and `order` after matching.
Composite matched fragments in order — join with double newline.
