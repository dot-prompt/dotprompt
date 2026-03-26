"use strict";
/**
 * Command handlers for the dot-prompt extension
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
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.codeLensProvider = exports.compiledViewPanel = exports.hoverProvider = exports.diagnosticsProvider = void 0;
exports.initializeProviders = initializeProviders;
exports.compileCommand = compileCommand;
exports.openCompiledViewCommand = openCompiledViewCommand;
exports.registerCommands = registerCommands;
exports.setupAutoCompile = setupAutoCompile;
const vscode = __importStar(require("vscode"));
const api = __importStar(require("./api/client"));
const compiledView_1 = require("./webview/compiledView");
const diagnostics_1 = require("./diagnostics");
const hover_1 = require("./hover");
const codelens_1 = __importDefault(require("./codelens"));
exports.codeLensProvider = codelens_1.default;
// Add a debounce timer for live updates to the compiled view
let compileViewDebounceTimer;
/**
 * Initialize all providers
 */
function initializeProviders(context) {
    exports.diagnosticsProvider = new diagnostics_1.DiagnosticsProvider();
    exports.hoverProvider = new hover_1.HoverProvider();
    // Register document change listeners
    context.subscriptions.push(vscode.workspace.onDidChangeTextDocument((event) => {
        if (event.document.languageId === 'dot-prompt') {
            // Handle live updates for the compiled view if it's open
            if (compiledView_1.CompiledViewPanel.currentPanel) {
                if (compileViewDebounceTimer) {
                    clearTimeout(compileViewDebounceTimer);
                }
                const config = vscode.workspace.getConfiguration('dotPrompt');
                const delay = config.get('compileDelay') || 300;
                compileViewDebounceTimer = setTimeout(() => {
                    compiledView_1.CompiledViewPanel.updateActivePanel(event.document);
                }, delay);
            }
        }
    }));
    context.subscriptions.push(exports.diagnosticsProvider);
}
/**
 * Handle the compile command
 */
async function compileCommand(document) {
    // Use active document if none provided
    const activeDoc = document || vscode.window.activeTextEditor?.document;
    if (!activeDoc) {
        vscode.window.showErrorMessage('No .prompt file open');
        return;
    }
    if (activeDoc.languageId !== 'dot-prompt') {
        vscode.window.showErrorMessage('Not a .prompt file');
        return;
    }
    // Check server connection first
    const isConnected = await api.checkServerConnection();
    if (!isConnected) {
        const serverUrl = api.getServerUrl();
        vscode.window.showErrorMessage(`Cannot connect to .prompt server at ${serverUrl}. Is the server running?`);
        return;
    }
    const prompt = activeDoc.getText();
    try {
        // Show progress
        await vscode.window.withProgress({
            location: vscode.ProgressLocation.Notification,
            title: 'Compiling .prompt file',
            cancellable: false
        }, async () => {
            const result = await api.compile(prompt, {});
            // Show success notification
            const tokenCount = result.compiled_tokens;
            const cacheStatus = result.cache_hit ? ' (cached)' : '';
            vscode.window.showInformationMessage(`Compiled successfully${cacheStatus}: ~${tokenCount} tokens`);
            // Update diagnostics
            if (exports.diagnosticsProvider) {
                exports.diagnosticsProvider.triggerUpdate(activeDoc);
            }
        });
    }
    catch (error) {
        const compileError = error;
        vscode.window.showErrorMessage(`Compilation failed: ${compileError.message}`);
    }
}
/**
 * Handle the open compiled view command
 */
async function openCompiledViewCommand(document) {
    // Use active document if none provided
    const activeDoc = document || vscode.window.activeTextEditor?.document;
    if (!activeDoc) {
        vscode.window.showErrorMessage('No .prompt file open');
        return;
    }
    if (activeDoc.languageId !== 'dot-prompt') {
        vscode.window.showErrorMessage('Not a .prompt file');
        return;
    }
    // Check server connection first
    const isConnected = await api.checkServerConnection();
    if (!isConnected) {
        const serverUrl = api.getServerUrl();
        vscode.window.showErrorMessage(`Cannot connect to .prompt server at ${serverUrl}. Is the server running?`);
        return;
    }
    // Get extension URI for webview
    const extension = vscode.extensions.getExtension('dot-prompt.dot-prompt');
    if (!extension) {
        vscode.window.showErrorMessage('Extension not found');
        return;
    }
    // Create or show the compiled view panel
    const panel = compiledView_1.CompiledViewPanel.createOrShow(extension.extensionUri);
    panel.setDocument(activeDoc);
    // Auto-compile and display
    await panel.compileAndDisplay();
}
/**
 * Register all commands
 */
function registerCommands(context) {
    // Compile command
    context.subscriptions.push(vscode.commands.registerCommand('dot-prompt.compile', async (document) => {
        await compileCommand(document);
    }));
    // Open compiled view command
    context.subscriptions.push(vscode.commands.registerCommand('dot-prompt.openCompiledView', async (document) => {
        await openCompiledViewCommand(document);
    }));
}
/**
 * Set up auto-compile on save
 */
function setupAutoCompile(context) {
    context.subscriptions.push(vscode.workspace.onDidSaveTextDocument(async (document) => {
        if (document.languageId !== 'dot-prompt') {
            return;
        }
        // Check if formatting is needed (already handled by VS Code formatOnSave,
        // but we wait a tiny bit to ensure it finished or trigger it if needed)
        const config = vscode.workspace.getConfiguration('dotPrompt');
        const autoCompile = config.get('autoCompile');
        if (autoCompile) {
            if (exports.diagnosticsProvider) {
                exports.diagnosticsProvider.triggerUpdate(document);
            }
            // Update compiled view if open
            compiledView_1.CompiledViewPanel.updateActivePanel(document);
        }
    }));
}
//# sourceMappingURL=commands.js.map