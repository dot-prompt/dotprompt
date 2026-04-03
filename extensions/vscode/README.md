<!-- fullWidth: false tocVisible: false tableWrap: true -->
# dot-prompt VS Code Extension

A server-backed VS Code extension for `.prompt` files with compiled view webview.

## Features

- **Server-backed Compilation**: Uses the existing Phoenix backend API (`/api/compile`) for compilation
- **Compiled View Webview**: Display compiled output with syntax highlighting, token counts, cache status
- **Inline Editor Features**:
  - Hover provider showing compiled preview
  - Diagnostic provider for validation errors
  - CodeLens for quick actions

## Requirements

- VS Code 1.75.0 or later
- Phoenix backend server running (default: http://localhost:4000)

## Installation

1. Navigate to the extension directory:

   ```bash
   cd dot-prompt_vscode
```
2. Install dependencies:

   ```bash
   npm install
```
3. Compile the TypeScript:

   ```bash
   npm run compile
```
4. Open the extension in VS Code and press F5 to run the development version

## Configuration

The extension provides the following settings (accessible via File > Preferences > Settings):

| Setting                | Default               | Description                                 |
| ---------------------- | --------------------- | ------------------------------------------- |
| `dotPrompt.serverUrl`  | `http://localhost:4000` | URL of the dot-prompt Phoenix server        |
| `dotPrompt.autoCompile` | `true`                | Automatically compile .prompt files on save |
| `dotPrompt.compileDelay` | `300`                 | Delay in milliseconds before auto-compile   |

## Usage

### Opening a .prompt File

1. Open any `.prompt` file in VS Code
2. The extension will automatically compile it if `autoCompile` is enabled

### Commands

- **dot-prompt: Compile** - Manually compile the current .prompt file
- **dot-prompt: Open Compiled View** - Open the compiled view webview panel

### Keyboard Shortcuts

You can bind keyboard shortcuts in VS Code:

```json
{
  "key": "ctrl+shift+p",
  "command": "dot-prompt.compile",
  "when": "editorLangId == prompt"
}
```

### Compiled View Webview

The compiled view displays:

- Full compiled template with syntax highlighting
- Token count and cache status
- Vary selections (if any)
- Response contract display
- Warnings (if any)

### Inline Features

- **Hover**: Hover over a .prompt file to see a quick summary (tokens, cache status, vary selections)
- **Diagnostics**: Compilation errors and warnings are shown in the Problems panel
- **CodeLens**: Quick action buttons at the top of the file

## Architecture

```
VS Code Extension ──► Phoenix Backend API ──► Compiled Output
       │                                         │
       ├─► Webview Panel                         │
       ├─► Hover Provider                        │
       ├─► Diagnostics                          │
       └─► CodeLens                              │
```

## API Endpoints Used

| Endpoint     | Method | Purpose                     |
| ------------ | ------ | --------------------------- |
| `/api/compile` | POST   | Compile .prompt with params |
| `/api/render` | POST   | Render compiled template    |

## Development

### Building

```bash
npm run compile
```

### Testing

```bash
npm run test
```

## License

MIT