/**
 * CodeLens provider for .prompt files - adds quick action buttons
 */

import * as vscode from 'vscode';
import * as api from './api/client';
import { CompileResponse, CompileError } from './api/types';

// Using type assertion to work around TypeScript variance issues with generic types
const codeLensProvider = {
  provideCodeLenses(
    document: vscode.TextDocument,
    _token: vscode.CancellationToken
  ): vscode.ProviderResult<vscode.CodeLens[]> {
    // Only provide CodeLens for .prompt files
    if (document.languageId !== 'dot-prompt') {
      return [];
    }

    const codeLenses: vscode.CodeLens[] = [];

    // Add "Compile" CodeLens at the top of the file
    const compileRange = new vscode.Range(
      new vscode.Position(0, 0),
      new vscode.Position(0, 0)
    );

    const compileCommand: vscode.Command = {
      title: '▶ Compile',
      command: 'dot-prompt.compile',
      arguments: [document]
    };

    codeLenses.push(new vscode.CodeLens(compileRange, compileCommand));

    // Add "Open Compiled View" CodeLens
    const viewRange = new vscode.Range(
      new vscode.Position(1, 0),
      new vscode.Position(1, 0)
    );

    const viewCommand: vscode.Command = {
      title: '🔍 Open Compiled View',
      command: 'dot-prompt.openCompiledView',
      arguments: [document]
    };

    codeLenses.push(new vscode.CodeLens(viewRange, viewCommand));

    return codeLenses;
  },

  resolveCodeLens(
    codeLens: vscode.CodeLens,
    _token: vscode.CancellationToken
  ): vscode.ProviderResult<vscode.CodeLens> {
    return codeLens;
  }
} as vscode.CodeLensProvider<vscode.CodeLens>;

export default codeLensProvider;
