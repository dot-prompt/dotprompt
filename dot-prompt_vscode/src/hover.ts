/**
 * Hover provider for .prompt files - shows compiled preview on hover
 */

import * as vscode from 'vscode';
import * as api from './api/client';
import { CompileResponse, CompileError } from './api/types';

export class HoverProvider {
  private cache: Map<string, { result: CompileResponse; timestamp: number }> = new Map();
  private cacheTimeout = 5000; // 5 seconds

  /**
   * Provide hover information for a position in a .prompt file
   */
  public async provideHover(
    document: vscode.TextDocument,
    position: vscode.Position
  ): Promise<vscode.Hover | null> {
    // Only provide hover for .prompt files
    if (document.languageId !== 'dot-prompt') {
      return null;
    }

    const prompt = document.getText();
    const uri = document.uri.toString();

    try {
      // Check cache first
      const cached = this.getCachedResult(uri);
      if (cached) {
        return this.createHover(cached);
      }

      // Compile and cache
      const result = await api.compile(prompt, {});
      this.cacheResult(uri, result);

      return this.createHover(result);
    } catch (error) {
      // Don't show hover on error, just return null
      return null;
    }
  }

  /**
   * Get cached compilation result
   */
  private getCachedResult(uri: string): CompileResponse | null {
    const cached = this.cache.get(uri);
    if (cached && Date.now() - cached.timestamp < this.cacheTimeout) {
      return cached.result;
    }
    return null;
  }

  /**
   * Cache a compilation result
   */
  private cacheResult(uri: string, result: CompileResponse): void {
    this.cache.set(uri, {
      result,
      timestamp: Date.now()
    });

    // Clean up old entries periodically
    if (this.cache.size > 10) {
      const now = Date.now();
      for (const [key, value] of this.cache.entries()) {
        if (now - value.timestamp > this.cacheTimeout) {
          this.cache.delete(key);
        }
      }
    }
  }

  /**
   * Create hover content from compile result
   */
  private createHover(result: CompileResponse): vscode.Hover {
    const lines: string[] = [];

    // Add token count
    lines.push(`**Tokens:** ~${result.compiled_tokens}`);
    
    // Add cache status
    if (result.cache_hit) {
      lines.push('**Cache:** ✓ Hit');
    }

    // Add vary selections summary
    if (result.vary_selections && Object.keys(result.vary_selections).length > 0) {
      lines.push('**Vary Selections:**');
      for (const [key, value] of Object.entries(result.vary_selections)) {
        lines.push(`- ${key}: ${value}`);
      }
    }

    // Add response contract type
    if (result.response_contract) {
      lines.push(`**Response Type:** ${result.response_contract.type}`);
    }

    // Add warning count if any
    if (result.warnings && result.warnings.length > 0) {
      lines.push(`**Warnings:** ${result.warnings.length}`);
    }

    // Create a preview of the compiled template
    const preview = result.template.substring(0, 500);
    if (preview.length < result.template.length) {
      lines.push('', '---', '', '**Preview (first 500 chars):**', '```', preview, '...', '```');
    } else {
      lines.push('', '---', '', '**Compiled Template:**', '```', preview, '```');
    }

    const markdown = new vscode.MarkdownString(lines.join('\n'));
    markdown.isTrusted = true;
    
    return new vscode.Hover(markdown);
  }

  /**
   * Clear the hover cache
   */
  public clearCache(): void {
    this.cache.clear();
  }
}
