/**
 * dot-prompt VS Code Extension
 * 
 * A server-backed VS Code extension for .prompt files that provides:
 * - Compilation via Phoenix backend API
 * - Compiled view webview
 * - Inline editor features (hover, diagnostics, CodeLens)
 */

import * as vscode from 'vscode';
import {
  registerCommands,
  initializeProviders,
  setupAutoCompile,
  diagnosticsProvider,
  hoverProvider,
  codeLensProvider
} from './commands';
import { CompiledViewPanel } from './webview/compiledView';
import { DotPromptFormattingProvider } from './formatter';

/**
 * Output channel for .prompt extension
 */
export let outputChannel: vscode.OutputChannel;

/**
 * Log a message to the output channel
 */
export function log(message: string): void {
  if (outputChannel) {
    const time = new Date().toLocaleTimeString();
    outputChannel.appendLine(`[${time}] ${message}`);
  }
}

/**
 * Called when the extension is activated
 */
export function activate(context: vscode.ExtensionContext): void {
  // Create output channel
  outputChannel = vscode.window.createOutputChannel('.prompt');
  log('.prompt extension is now activating...');

  // Initialize providers
  initializeProviders(context);

  // Register commands
  registerCommands(context);

  // Set up auto-compile on save
  setupAutoCompile(context);

  // Register language providers
  registerLanguageProviders(context);

  // Register formatting provider
  const formattingProvider = new DotPromptFormattingProvider();
  const formattingProviderRegistration = vscode.languages.registerDocumentFormattingEditProvider(
    { language: 'dot-prompt', scheme: 'file' },
    formattingProvider
  );
  context.subscriptions.push(formattingProviderRegistration);

  const rangeFormattingProviderRegistration = vscode.languages.registerDocumentRangeFormattingEditProvider(
    { language: 'dot-prompt', scheme: 'file' },
    formattingProvider
  );
  context.subscriptions.push(rangeFormattingProviderRegistration);

  // Check server connection on startup
  checkServerConnection();

  log('.prompt extension activated successfully');
}

/**
 * Register language providers for .prompt files
 */
function registerLanguageProviders(context: vscode.ExtensionContext): void {
  // Register HoverProvider
  const hoverProviderRegistration = vscode.languages.registerHoverProvider(
    { language: 'dot-prompt', scheme: 'file' },
    hoverProvider
  );
  context.subscriptions.push(hoverProviderRegistration);

  // Register CodeLensProvider
  const codeLensProviderRegistration = vscode.languages.registerCodeLensProvider(
    { language: 'dot-prompt', scheme: 'file' },
    codeLensProvider
  );
  context.subscriptions.push(codeLensProviderRegistration);

  // Register document open/switch handlers for diagnostics
  context.subscriptions.push(
    vscode.workspace.onDidOpenTextDocument((document) => {
      if (document.languageId === 'dot-prompt' && diagnosticsProvider) {
        diagnosticsProvider.triggerUpdate(document);
      }
    })
  );

  // Register active editor change handler
  context.subscriptions.push(
    vscode.window.onDidChangeActiveTextEditor((editor) => {
      if (editor && editor.document.languageId === 'dot-prompt') {
        if (diagnosticsProvider) {
          diagnosticsProvider.triggerUpdate(editor.document);
        }
        
        // Update compiled view if open
        CompiledViewPanel.updateActivePanel(editor.document);
      }
    })
  );
}

/**
 * Check server connection and show notification if not connected
 */
async function checkServerConnection(): Promise<void> {
  const { checkServerConnection } = await import('./api/client');
  const { getServerUrl } = await import('./api/client');
  
  const isConnected = await checkServerConnection();
  
  if (!isConnected) {
    const serverUrl = getServerUrl();
    vscode.window.showWarningMessage(
      `.prompt: Cannot connect to server at ${serverUrl}. Please ensure the server is running.`,
      'Open Settings'
    ).then((selection) => {
      if (selection === 'Open Settings') {
        vscode.commands.executeCommand('workbench.action.openSettings', 'dotPrompt.serverUrl');
      }
    });
  }
}

/**
 * Called when the extension is deactivated
 */
export function deactivate(): void {
  log('.prompt extension is now deactivating...');
  
  // Clean up
  if (diagnosticsProvider) {
    diagnosticsProvider.clearDiagnostics = (): void => {
      // Already handled in dispose
    };
  }
}
