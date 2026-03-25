"use strict";
/**
 * Diagnostic provider for .prompt files - shows compilation errors
 */
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.DiagnosticsProvider = void 0;
const vscode = __importStar(require("vscode"));
const api = __importStar(require("./api/client"));
class DiagnosticsProvider {
    constructor() {
        this.diagnosticCollection = vscode.languages.createDiagnosticCollection('dot-prompt');
        this.statusBarItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left, 100);
        this.statusBarItem.text = 'dot-prompt: Ready';
        this.statusBarItem.show();
    }
    /**
     * Trigger diagnostics for a document with debouncing
     */
    triggerUpdate(document) {
        // Clear previous timer
        if (this.debounceTimer) {
            clearTimeout(this.debounceTimer);
        }
        // Debounce the update
        const config = vscode.workspace.getConfiguration('dotPrompt');
        const delay = config.get('compileDelay') || 300;
        this.debounceTimer = setTimeout(() => {
            this.updateDiagnostics(document);
        }, delay);
    }
    /**
     * Update diagnostics for a document
     */
    async updateDiagnostics(document) {
        // Clear existing diagnostics
        this.diagnosticCollection.clear();
        // Check if we should auto-compile
        const config = vscode.workspace.getConfiguration('dotPrompt');
        const autoCompile = config.get('autoCompile');
        if (!autoCompile) {
            this.statusBarItem.text = 'dot-prompt: Auto-compile disabled';
            return;
        }
        this.statusBarItem.text = 'dot-prompt: Compiling...';
        const prompt = document.getText();
        try {
            const result = await api.compile(prompt, {});
            // Check for warnings that are actually errors
            const warnings = result.warnings || [];
            const diagnostics = [];
            // Parse warnings that have line/column info
            for (const warning of warnings) {
                // Try to parse line number from warning message
                // Format: "Warning at line X: message"
                const lineMatch = warning.match(/line\s+(\d+)/i);
                const line = lineMatch ? parseInt(lineMatch[1], 10) - 1 : 0;
                const range = new vscode.Range(new vscode.Position(line, 0), new vscode.Position(line, 1000));
                const diagnostic = new vscode.Diagnostic(range, warning, vscode.DiagnosticSeverity.Warning);
                diagnostics.push(diagnostic);
            }
            // Set diagnostics
            this.diagnosticCollection.set(document.uri, diagnostics);
            // Update status bar
            if (result.warnings && result.warnings.length > 0) {
                this.statusBarItem.text = `dot-prompt: ${result.warnings.length} warning(s)`;
            }
            else if (result.cache_hit) {
                this.statusBarItem.text = 'dot-prompt: ✓ Compiled (cached)';
            }
            else {
                this.statusBarItem.text = 'dot-prompt: ✓ Compiled';
            }
        }
        catch (error) {
            const compileError = error;
            // Show error in status bar
            this.statusBarItem.text = 'dot-prompt: ✗ Compilation error';
            // Parse error for line info
            let line = 0;
            if (compileError.line) {
                line = compileError.line - 1;
            }
            else {
                // Try to extract from message
                const lineMatch = compileError.message.match(/line\s+(\d+)/i);
                if (lineMatch) {
                    line = parseInt(lineMatch[1], 10) - 1;
                }
            }
            const range = new vscode.Range(new vscode.Position(line, 0), new vscode.Position(line, 1000));
            const diagnostic = new vscode.Diagnostic(range, compileError.message, vscode.DiagnosticSeverity.Error);
            this.diagnosticCollection.set(document.uri, [diagnostic]);
        }
    }
    /**
     * Clear diagnostics for a document
     */
    clearDiagnostics(document) {
        this.diagnosticCollection.delete(document.uri);
    }
    /**
     * Dispose of resources
     */
    dispose() {
        this.diagnosticCollection.dispose();
        this.statusBarItem.dispose();
        if (this.debounceTimer) {
            clearTimeout(this.debounceTimer);
        }
    }
}
exports.DiagnosticsProvider = DiagnosticsProvider;
//# sourceMappingURL=diagnostics.js.map