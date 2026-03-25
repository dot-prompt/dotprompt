/**
 * Command handlers for the dot-prompt extension
 */

import * as vscode from 'vscode';
import * as api from './api/client';
import { CompileResponse, CompileError } from './api/types';
import { CompiledViewPanel } from './webview/compiledView';
import { DiagnosticsProvider } from './diagnostics';
import { HoverProvider } from './hover';
import codeLensProvider from './codelens';

export let diagnosticsProvider: DiagnosticsProvider;
export let hoverProvider: HoverProvider;
export let compiledViewPanel: CompiledViewPanel | undefined;
export { codeLensProvider };

/**
 * Initialize all providers
 */
export function initializeProviders(context: vscode.ExtensionContext): void {
  diagnosticsProvider = new DiagnosticsProvider();
  hoverProvider = new HoverProvider();

  // Register document change listeners
  context.subscriptions.push(
    vscode.workspace.onDidChangeTextDocument((event) => {
      // Could trigger diagnostics on change if needed
    })
  );

  context.subscriptions.push(diagnosticsProvider);
}

/**
 * Handle the compile command
 */
export async function compileCommand(
  document?: vscode.TextDocument
): Promise<void> {
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
    vscode.window.showErrorMessage(
      `Cannot connect to dot-prompt server at ${serverUrl}. Is the server running?`
    );
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
      vscode.window.showInformationMessage(
        `Compiled successfully${cacheStatus}: ~${tokenCount} tokens`
      );
      
      // Update diagnostics
      if (diagnosticsProvider) {
        diagnosticsProvider.triggerUpdate(activeDoc);
      }
    });
  } catch (error) {
    const compileError = error as CompileError;
    vscode.window.showErrorMessage(`Compilation failed: ${compileError.message}`);
  }
}

/**
 * Handle the open compiled view command
 */
export async function openCompiledViewCommand(
  document?: vscode.TextDocument
): Promise<void> {
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
    vscode.window.showErrorMessage(
      `Cannot connect to dot-prompt server at ${serverUrl}. Is the server running?`
    );
    return;
  }

  // Get extension URI for webview
  const extension = vscode.extensions.getExtension('dot-prompt.dot-prompt');
  if (!extension) {
    vscode.window.showErrorMessage('Extension not found');
    return;
  }

  // Create or show the compiled view panel
  const panel = CompiledViewPanel.createOrShow(extension.extensionUri);
  panel.setDocument(activeDoc);
  
  // Auto-compile and display
  await panel.compileAndDisplay();
}

/**
 * Register all commands
 */
export function registerCommands(context: vscode.ExtensionContext): void {
  // Compile command
  context.subscriptions.push(
    vscode.commands.registerCommand('dot-prompt.compile', async (document?: vscode.TextDocument) => {
      await compileCommand(document);
    })
  );

  // Open compiled view command
  context.subscriptions.push(
    vscode.commands.registerCommand('dot-prompt.openCompiledView', async (document?: vscode.TextDocument) => {
      await openCompiledViewCommand(document);
    })
  );
}

/**
 * Set up auto-compile on save
 */
export function setupAutoCompile(context: vscode.ExtensionContext): void {
  context.subscriptions.push(
    vscode.workspace.onDidSaveTextDocument(async (document) => {
      if (document.languageId !== 'dot-prompt') {
        return;
      }

      // Check if formatting is needed (already handled by VS Code formatOnSave,
      // but we wait a tiny bit to ensure it finished or trigger it if needed)

      const config = vscode.workspace.getConfiguration('dotPrompt');
      const autoCompile = config.get<boolean>('autoCompile');
      
      if (autoCompile && diagnosticsProvider) {
        diagnosticsProvider.triggerUpdate(document);
      }
    })
  );
}
