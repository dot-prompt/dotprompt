"use strict";
/**
 * dot-prompt VS Code Extension
 *
 * A server-backed VS Code extension for .prompt files that provides:
 * - Compilation via Phoenix backend API
 * - Compiled view webview
 * - Inline editor features (hover, diagnostics, CodeLens)
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
exports.outputChannel = void 0;
exports.log = log;
exports.activate = activate;
exports.deactivate = deactivate;
const vscode = __importStar(require("vscode"));
const commands_1 = require("./commands");
const compiledView_1 = require("./webview/compiledView");
const formatter_1 = require("./formatter");
/**
 * Log a message to the output channel
 */
function log(message) {
    if (exports.outputChannel) {
        const time = new Date().toLocaleTimeString();
        exports.outputChannel.appendLine(`[${time}] ${message}`);
    }
}
/**
 * Called when the extension is activated
 */
function activate(context) {
    // Create output channel
    exports.outputChannel = vscode.window.createOutputChannel('.prompt');
    log('.prompt extension is now activating...');
    // Initialize providers
    (0, commands_1.initializeProviders)(context);
    // Register commands
    (0, commands_1.registerCommands)(context);
    // Set up auto-compile on save
    (0, commands_1.setupAutoCompile)(context);
    // Register language providers
    registerLanguageProviders(context);
    // Register formatting provider
    const formattingProvider = new formatter_1.DotPromptFormattingProvider();
    const formattingProviderRegistration = vscode.languages.registerDocumentFormattingEditProvider({ language: 'dot-prompt', scheme: 'file' }, formattingProvider);
    context.subscriptions.push(formattingProviderRegistration);
    const rangeFormattingProviderRegistration = vscode.languages.registerDocumentRangeFormattingEditProvider({ language: 'dot-prompt', scheme: 'file' }, formattingProvider);
    context.subscriptions.push(rangeFormattingProviderRegistration);
    // Check server connection on startup
    checkServerConnection();
    log('.prompt extension activated successfully');
}
/**
 * Register language providers for .prompt files
 */
function registerLanguageProviders(context) {
    // Register HoverProvider
    const hoverProviderRegistration = vscode.languages.registerHoverProvider({ language: 'dot-prompt', scheme: 'file' }, commands_1.hoverProvider);
    context.subscriptions.push(hoverProviderRegistration);
    // Register CodeLensProvider
    const codeLensProviderRegistration = vscode.languages.registerCodeLensProvider({ language: 'dot-prompt', scheme: 'file' }, commands_1.codeLensProvider);
    context.subscriptions.push(codeLensProviderRegistration);
    // Register document open/switch handlers for diagnostics
    context.subscriptions.push(vscode.workspace.onDidOpenTextDocument((document) => {
        if (document.languageId === 'dot-prompt' && commands_1.diagnosticsProvider) {
            commands_1.diagnosticsProvider.triggerUpdate(document);
        }
    }));
    // Register active editor change handler
    context.subscriptions.push(vscode.window.onDidChangeActiveTextEditor((editor) => {
        if (editor && editor.document.languageId === 'dot-prompt') {
            if (commands_1.diagnosticsProvider) {
                commands_1.diagnosticsProvider.triggerUpdate(editor.document);
            }
            // Update compiled view if open
            compiledView_1.CompiledViewPanel.updateActivePanel(editor.document);
        }
    }));
}
/**
 * Check server connection and show notification if not connected
 */
async function checkServerConnection() {
    const { checkServerConnection } = await Promise.resolve().then(() => __importStar(require('./api/client')));
    const { getServerUrl } = await Promise.resolve().then(() => __importStar(require('./api/client')));
    const isConnected = await checkServerConnection();
    if (!isConnected) {
        const serverUrl = getServerUrl();
        vscode.window.showWarningMessage(`.prompt: Cannot connect to server at ${serverUrl}. Please ensure the server is running.`, 'Open Settings').then((selection) => {
            if (selection === 'Open Settings') {
                vscode.commands.executeCommand('workbench.action.openSettings', 'dotPrompt.serverUrl');
            }
        });
    }
}
/**
 * Called when the extension is deactivated
 */
function deactivate() {
    log('.prompt extension is now deactivating...');
    // Clean up
    if (commands_1.diagnosticsProvider) {
        commands_1.diagnosticsProvider.clearDiagnostics = () => {
            // Already handled in dispose
        };
    }
}
//# sourceMappingURL=extension.js.map