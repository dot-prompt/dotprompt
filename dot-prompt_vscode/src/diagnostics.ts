/**
 * Diagnostic provider for .prompt files - shows compilation errors
 */

import * as vscode from 'vscode';
import * as api from './api/client';
import { CompileError } from './api/types';

export class DiagnosticsProvider {
  private diagnosticCollection: vscode.DiagnosticCollection;
  private statusBarItem: vscode.StatusBarItem;
  private debounceTimer: NodeJS.Timeout | undefined;

  constructor() {
    this.diagnosticCollection = vscode.languages.createDiagnosticCollection('dot-prompt');
    this.statusBarItem = vscode.window.createStatusBarItem(
      vscode.StatusBarAlignment.Left,
      100
    );
    this.statusBarItem.text = 'dot-prompt: Ready';
    this.statusBarItem.show();
  }

  /**
   * Trigger diagnostics for a document with debouncing
   */
  public triggerUpdate(document: vscode.TextDocument): void {
    // Clear previous timer
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer);
    }

    // Debounce the update
    const config = vscode.workspace.getConfiguration('dotPrompt');
    const delay = config.get<number>('compileDelay') || 300;

    this.debounceTimer = setTimeout(() => {
      this.updateDiagnostics(document);
    }, delay);
  }

  /**
   * Update diagnostics for a document
   */
  private async updateDiagnostics(document: vscode.TextDocument): Promise<void> {
    // Clear existing diagnostics
    this.diagnosticCollection.clear();
    
    // Check if we should auto-compile
    const config = vscode.workspace.getConfiguration('dotPrompt');
    const autoCompile = config.get<boolean>('autoCompile');
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
      const diagnostics: vscode.Diagnostic[] = [];
      
      // Parse warnings that have line/column info
      for (const warning of warnings) {
        // Try to parse line number from warning message
        // Format: "Warning at line X: message"
        const lineMatch = warning.match(/line\s+(\d+)/i);
        const line = lineMatch ? parseInt(lineMatch[1], 10) - 1 : 0;
        
        const range = new vscode.Range(
          new vscode.Position(line, 0),
          new vscode.Position(line, 1000)
        );
        
        const diagnostic = new vscode.Diagnostic(
          range,
          warning,
          vscode.DiagnosticSeverity.Warning
        );
        
        diagnostics.push(diagnostic);
      }
      
      // Set diagnostics
      this.diagnosticCollection.set(document.uri, diagnostics);
      
      // Update status bar
      if (result.warnings && result.warnings.length > 0) {
        this.statusBarItem.text = `dot-prompt: ${result.warnings.length} warning(s)`;
      } else if (result.cache_hit) {
        this.statusBarItem.text = 'dot-prompt: ✓ Compiled (cached)';
      } else {
        this.statusBarItem.text = 'dot-prompt: ✓ Compiled';
      }
      
    } catch (error) {
      const compileError = error as CompileError;
      
      // Show error in status bar
      this.statusBarItem.text = 'dot-prompt: ✗ Compilation error';
      
      // Parse error for line info
      let line = 0;
      if (compileError.line) {
        line = compileError.line - 1;
      } else {
        // Try to extract from message
        const lineMatch = compileError.message.match(/line\s+(\d+)/i);
        if (lineMatch) {
          line = parseInt(lineMatch[1], 10) - 1;
        }
      }
      
      const range = new vscode.Range(
        new vscode.Position(line, 0),
        new vscode.Position(line, 1000)
      );
      
      const diagnostic = new vscode.Diagnostic(
        range,
        compileError.message,
        vscode.DiagnosticSeverity.Error
      );
      
      this.diagnosticCollection.set(document.uri, [diagnostic]);
    }
  }

  /**
   * Clear diagnostics for a document
   */
  public clearDiagnostics(document: vscode.TextDocument): void {
    this.diagnosticCollection.delete(document.uri);
  }

  /**
   * Dispose of resources
   */
  public dispose(): void {
    this.diagnosticCollection.dispose();
    this.statusBarItem.dispose();
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer);
    }
  }
}
