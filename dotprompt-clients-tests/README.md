# dotprompt-clients-tests

Demo projects to test the dot-prompt Python and TypeScript client libraries against a running server with actual prompts.

## Prerequisites

- Docker must be installed and running
- Python 3.10+
- Node.js 18+

## Project Structure

```
dotprompt-clients-tests/
├── python-demo/
│   ├── docker-compose.yml    # Spins up server on port 4001
│   ├── prompts/              # Copy of prompts from dot_prompt/prompts/
│   ├── pyproject.toml
│   └── src/
│       └── demo.py           # Tests all client features
└── ts-demo/
    ├── docker-compose.yml    # Spins up server on port 4002
    ├── prompts/              # Copy of prompts from dot_prompt/prompts/
    ├── package.json
    └── src/
        └── demo.ts           # Tests all client features
```

## Prompts Included

The `prompts/` folder contains a copy of prompts from `dot_prompt/prompts/`:

- **demo.prompt** - Main demo with user_level and user_message params
- **test.prompt** - Empty test file
- **all_skills.prompt** - Demonstrates collection matching (match: all, matchRe, limit, order)
- **fragment_demo.prompt** - Demo for fragments
- **concept_explanation.prompt** - Concept explanation prompt
- **meta_model.prompt** - NLP skills

**Fragments** (`prompts/fragments/`):
- `simple_greeting` - Static fragment
- `personalized_greeting` - Dynamic fragment with params
- `conditional_greeting` - Fragment with conditional logic
- `combined_greeting` - Combines multiple fragments

**Skills** (`prompts/skills/`):
- `anchoring.prompt`
- `meta_model.prompt`
- `milton_model.prompt`
- `reframing.prompt`

## Quick Start

### 1. Build the dot-prompt image (if not already built)

```bash
cd /home/nahar/Documents/code/dot-prompt/dot_prompt
docker compose build
```

### 2. Python Demo

**Terminal 1 - Start server:**
```bash
cd /home/nahar/Documents/code/dot-prompt/dotprompt-clients-tests/python-demo
docker compose up -d
```

**Terminal 2 - Run demo:**
```bash
cd /home/nahar/Documents/code/dot-prompt/dotprompt-clients-tests/python-demo

# Install the local dot-prompt client
pip install -e ../../dot-prompt-python-client

# Install dev dependencies
pip install -e ".[dev]"

# Run the demo
DOTPROMPT_URL=http://localhost:4001 python src/demo.py
```

### 3. TypeScript Demo

**Terminal 1 - Start server:**
```bash
cd /home/nahar/Documents/code/dot-prompt/dotprompt-clients-tests/ts-demo
docker compose up -d
```

**Terminal 2 - Run demo:**
```bash
cd /home/nahar/Documents/code/dot-prompt/dotprompt-clients-tests/ts-demo

# Build the TS client first (if not built)
cd ../../dot-prompt-ts && npm install && npm run build

# Install dependencies
npm install

# Install the local dot-prompt client
npm install ../../dot-prompt-ts

# Run the demo
DOTPROMPT_URL=http://localhost:4002 npm run demo
```

## Testing Features

Both demos test:

1. **list_prompts()** - List all available prompts
2. **list_collections()** - List root-level collections
3. **get_schema(prompt)** - Get prompt schema/metadata
4. **compile(prompt, params)** - Compile a prompt with params
5. **render(prompt, params, runtime)** - Compile + inject runtime
6. **inject(template, runtime)** - Inject runtime into raw template
7. **Fragment handling** - Test simple, personalized, conditional, combined fragments
8. **Collection matching** - Test match: all, matchRe, limit, order features

## Environment Variables

- `DOTPROMPT_URL` - Server URL
  - Python demo default: `http://localhost:4001`
  - TypeScript demo default: `http://localhost:4002`

## Stopping Services

```bash
# Stop Python demo server
cd python-demo && docker compose down

# Stop TypeScript demo server
cd ts-demo && docker compose down
```
