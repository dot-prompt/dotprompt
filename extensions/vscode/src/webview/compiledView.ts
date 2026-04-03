/**
 * Compiled View Webview Panel - displays compiled .prompt output
 */

import * as vscode from 'vscode';
import * as path from 'path';
import { CompileResponse, CompileError } from '../api/types';
import * as api from '../api/client';
import { log } from '../extension';

export class CompiledViewPanel {
  public static currentPanel: CompiledViewPanel | undefined;
  public static readonly viewType = 'dotPromptCompiled';

  private readonly panel: vscode.WebviewPanel;
  private readonly extensionUri: vscode.Uri;
  private currentDocument: vscode.TextDocument | undefined;
  private currentParams: Record<string, any> = {};
  private currentSeed: number | undefined;

  /**
   * Create or show the compiled view panel
   */
  public static createOrShow(extensionUri: vscode.Uri): CompiledViewPanel {
    if (CompiledViewPanel.currentPanel) {
      log('[CompiledView] Existing panel revealed');
      CompiledViewPanel.currentPanel.panel.reveal(vscode.ViewColumn.Two);
      return CompiledViewPanel.currentPanel;
    }

    log('[CompiledView] Creating new panel');
    const panel = vscode.window.createWebviewPanel(
      CompiledViewPanel.viewType,
      'Compiled View',
      vscode.ViewColumn.Two,
      {
        enableScripts: true,
        retainContextWhenHidden: true,
        localResourceRoots: [extensionUri]
      }
    );

    CompiledViewPanel.currentPanel = new CompiledViewPanel(panel, extensionUri);
    return CompiledViewPanel.currentPanel;
  }

  /**
   * Update the current panel if it exists
   */
  public static updateActivePanel(document: vscode.TextDocument): void {
    if (CompiledViewPanel.currentPanel && document.languageId === 'dot-prompt') {
      log(`[CompiledView] Updating for: ${path.basename(document.fileName)}`);
      
      if (CompiledViewPanel.currentPanel.currentDocument?.uri.toString() !== document.uri.toString()) {
        CompiledViewPanel.currentPanel.currentParams = {};
        CompiledViewPanel.currentPanel.currentSeed = undefined;
      }
      
      CompiledViewPanel.currentPanel.setDocument(document);
      CompiledViewPanel.currentPanel.compileAndDisplay();
    }
  }

  private constructor(panel: vscode.WebviewPanel, extensionUri: vscode.Uri) {
    this.panel = panel;
    this.extensionUri = extensionUri;

    this.panel.webview.html = this.getHtmlForWebview();
    this.panel.webview.onDidReceiveMessage(this.handleMessage.bind(this));

    this.panel.onDidDispose(() => {
      log('[CompiledView] Panel disposed');
      CompiledViewPanel.currentPanel = undefined;
    });

    this.panel.onDidChangeViewState((e) => {
      if (e.webviewPanel.visible) {
        log('[CompiledView] Panel became visible');
        const activeEditor = vscode.window.activeTextEditor;
        if (activeEditor && activeEditor.document.languageId === 'dot-prompt') {
          this.setDocument(activeEditor.document);
          this.compileAndDisplay();
        }
      }
    });
  }

  public setDocument(document: vscode.TextDocument): void {
    this.currentDocument = document;
    if (this.panel) {
      this.panel.title = `Compiled: ${path.basename(document.fileName)}`;
    }
  }

  public async compileAndDisplay(): Promise<void> {
    if (!this.currentDocument) return;

    const prompt = this.currentDocument.getText();
    const fileName = path.basename(this.currentDocument.fileName);
    log(`[CompiledView] Fetching compilation for: ${fileName}`);
    
    try {
      this.showLoading();
      const result = await api.compile(prompt, this.currentParams, {
        seed: this.currentSeed
      });
      log(`[CompiledView] API success: ${fileName}`);
      this.displayCompileResult(result);
    } catch (error: any) {
      const message = error.apiError?.message || error.message || 'Compilation failed';
      log(`[CompiledView] API failure: ${message}`);
      this.showError(message);
    }
  }

  private displayCompileResult(result: CompileResponse): void {
    if (!this.panel) return;
    this.panel.webview.postMessage({
      type: 'display',
      data: result,
      currentParams: this.currentParams,
      currentSeed: this.currentSeed
    });
  }

  private showLoading(): void {
    if (!this.panel) return;
    this.panel.webview.postMessage({ type: 'loading' });
  }

  private showError(message: string): void {
    if (!this.panel) return;
    this.panel.webview.postMessage({
      type: 'error',
      data: { message }
    });
  }

  private async handleMessage(message: any): Promise<void> {
    log(`[CompiledView] Received message: ${message.type}`);
    switch (message.type) {
      case 'ready':
        if (this.currentDocument) await this.compileAndDisplay();
        break;
      case 'refresh':
        await this.compileAndDisplay();
        break;
      case 'updateParam':
        this.currentParams[message.key] = message.value;
        await this.compileAndDisplay();
        break;
      case 'updateListParam':
        {
          const current = Array.isArray(this.currentParams[message.key]) ? [...this.currentParams[message.key]] : [];
          if (message.checked) {
            if (!current.includes(message.val)) current.push(message.val);
          } else {
            const idx = current.indexOf(message.val);
            if (idx !== -1) current.splice(idx, 1);
          }
          this.currentParams[message.key] = current;
          await this.compileAndDisplay();
        }
        break;
      case 'updateSeed':
        this.currentSeed = message.value;
        await this.compileAndDisplay();
        break;
      case 'resetParams':
        this.currentParams = {};
        this.currentSeed = undefined;
        await this.compileAndDisplay();
        break;
      case 'copy':
        await vscode.env.clipboard.writeText(message.data.text);
        vscode.window.showInformationMessage('Copied to clipboard');
        break;
    }
  }

  private getHtmlForWebview(): string {
    return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Compiled View</title>
  <style>
    body { margin: 0; padding: 0; background: #1e1e1e; color: #d4d4d4; font-family: -apple-system, sans-serif; font-size: 13px; display: flex; flex-direction: column; height: 100vh; overflow: hidden; }
    .toolbar { display: flex; align-items: center; gap: 12px; padding: 8px 16px; background: #252526; border-bottom: 1px solid #3c3c3c; flex-shrink: 0; }
    .toolbar button { background: #0e639c; color: #fff; border: none; padding: 4px 12px; border-radius: 2px; cursor: pointer; font-size: 12px; }
    .toolbar button:hover { background: #1177bb; }
    .toolbar button.secondary { background: #3c3c3c; color: #ccc; }
    .status { margin-left: auto; display: flex; align-items: center; gap: 12px; font-size: 11px; }
    .token-count { color: #9cdcfe; font-weight: bold; }
    .cache-status { padding: 2px 6px; border-radius: 2px; }
    .cache-hit { background: rgba(78, 201, 176, 0.2); color: #4ec9b0; }
    .cache-miss { background: rgba(220, 220, 170, 0.2); color: #dcdcaa; }
    
    .main-container { display: flex; flex: 1; overflow: hidden; }
    .sidebar { width: 300px; background: #252526; border-right: 1px solid #3c3c3c; overflow-y: auto; padding: 16px; flex-shrink: 0; }
    .sidebar-section { margin-bottom: 24px; }
    .sidebar-header { font-weight: bold; margin-bottom: 12px; color: #ccc; text-transform: uppercase; font-size: 11px; border-bottom: 1px solid #333; padding-bottom: 4px; display: flex; justify-content: space-between; }
    
    .param-item { margin-bottom: 16px; }
    .param-label { display: block; margin-bottom: 6px; font-weight: 500; color: #9cdcfe; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    .param-doc { font-size: 11px; color: #858585; margin-top: 6px; display: block; line-height: 1.3; }
    .param-input { width: 100%; background: #3c3c3c; color: #ccc; border: 1px solid #3c3c3c; padding: 6px 10px; border-radius: 2px; box-sizing: border-box; font-size: 12px; font-family: inherit; }
    .param-input:focus { border-color: #0e639c; outline: none; }
    
    .range-container { display: flex; align-items: center; gap: 10px; }
    .range-value { min-width: 24px; text-align: right; color: #ce9178; font-family: monospace; }
    
    .content { flex: 1; padding: 16px; overflow-y: auto; background: #1e1e1e; }
    .section { margin-bottom: 16px; border: 1px solid #3c3c3c; border-radius: 4px; overflow: hidden; }
    .section-header { background: #252526; padding: 8px 12px; border-bottom: 1px solid #3c3c3c; font-weight: bold; display: flex; justify-content: space-between; align-items: center; }
    .section-header button { background: transparent; border: 1px solid #3c3c3c; color: #ccc; padding: 2px 8px; font-size: 10px; cursor: pointer; }
    .section-content { padding: 12px; white-space: pre-wrap; font-family: 'Consolas', monospace; font-size: 12px; }
    
    .loading-spinner { display: none; width: 14px; height: 14px; border: 2px solid rgba(255,255,255,0.1); border-top-color: #0e639c; border-radius: 50%; animation: spin 0.8s linear infinite; }
    @keyframes spin { to { transform: rotate(360deg); } }
    
    .error { padding: 16px; color: #f14c4c; background: rgba(241, 76, 76, 0.1); border: 1px solid #f14c4c; border-radius: 4px; }
    .contract pre { margin: 0; color: #9cdcfe; font-size: 11px; }
    
    .badge { padding: 2px 6px; border-radius: 10px; background: #333; color: #aaa; font-size: 10px; font-weight: normal; }
    
    ::-webkit-scrollbar { width: 10px; }
    ::-webkit-scrollbar-track { background: transparent; }
    ::-webkit-scrollbar-thumb { background: #3c3c3c; }
    ::-webkit-scrollbar-thumb:hover { background: #454545; }
  </style>
</head>
<body>
  <div class="toolbar">
    <button id="refresh-btn">↻ Refresh</button>
    <button id="reset-btn" class="secondary">Reset All</button>
    <div class="loading-spinner" id="loader"></div>
    <div class="status">
      <span class="token-count" id="tokens"></span>
      <span id="cache"></span>
    </div>
  </div>
  
  <div class="main-container">
    <div class="sidebar">
      <div class="sidebar-section">
        <div class="sidebar-header">Prompt Info</div>
        <div style="display: flex; flex-direction: column; gap: 8px;">
          <div style="display: flex; justify-content: space-between; font-size: 12px;">
            <span style="color: #858585;">Major Version:</span>
            <span id="info-major" style="color: #9cdcfe; font-weight: bold;">-</span>
          </div>
          <div style="display: flex; justify-content: space-between; font-size: 12px;">
            <span style="color: #858585;">Revision:</span>
            <span id="info-version" style="color: #9cdcfe;">-</span>
          </div>
        </div>
      </div>

      <div class="sidebar-section" id="vary-section" style="display: none;">
        <div class="sidebar-header">Vary Selections</div>
        <div id="vary-list"></div>
        <div class="param-item" style="margin-top: 12px; padding-top: 12px; border-top: 1px solid #333;">
          <label class="param-label" style="font-size: 11px; color: #858585;">Global Seed</label>
          <input type="number" class="param-input" id="seed-input" placeholder="Random" style="padding: 4px 8px; height: 24px;" onchange="vscode.postMessage({type:'updateSeed', value: this.value ? parseInt(this.value, 10) : undefined})">
        </div>
      </div>
      
      <div class="sidebar-section">
        <div class="sidebar-header">Parameters</div>
        <div id="params-list"></div>
      </div>
    </div>
    
    <div class="content" id="main">
      <div class="empty-state">Select a .prompt file to see the compiled output</div>
    </div>
  </div>

  <script>
    (function() {
      const vscode = acquireVsCodeApi();
      const main = document.getElementById('main');
      const loader = document.getElementById('loader');
      const paramsList = document.getElementById('params-list');
      const varyList = document.getElementById('vary-list');
      const varySection = document.getElementById('vary-section');
      
      document.getElementById('refresh-btn').onclick = () => vscode.postMessage({ type: 'refresh' });
      document.getElementById('reset-btn').onclick = () => {
        document.getElementById('seed-input').value = '';
        vscode.postMessage({ type: 'resetParams' });
      };

      window.addEventListener('message', event => {
        const msg = event.data;
        if (msg.type === 'loading') loader.style.display = 'inline-block';
        else if (msg.type === 'error') {
          loader.style.display = 'none';
          main.innerHTML = '<div class="error"><b>Error:</b><br>' + escapeHtml(msg.data.message) + '</div>';
        } else if (msg.type === 'display') {
          loader.style.display = 'none';
          document.getElementById('seed-input').value = msg.currentSeed || '';
          document.getElementById('info-major').textContent = msg.data.major || '1';
          document.getElementById('info-version').textContent = msg.data.version || '1';
          
          renderVary(msg.data.vary_selections, msg.currentParams);
          renderParams(msg.data.params, msg.currentParams);
          renderContent(msg.data);
        }
      });

      function renderVary(selections, current) {
        if (!selections || Object.keys(selections).length === 0) {
          varySection.style.display = 'none';
          return;
        }
        varySection.style.display = 'block';
        let html = '';
        for (const [name, data] of Object.entries(selections)) {
          // If the server returns details about the choices, we can show them
          // For now we just show the selected ID and allow overriding it in params
          const selectedId = typeof data === 'object' ? data.id : data;
          const paramValue = current[name] || current['@' + name] || '';
          
          html += '<div class="param-item">';
          html += '<label class="param-label">' + name + ' <span class="badge">vary</span></label>';
          html += '<input type="text" class="param-input" value="' + (paramValue || selectedId) + '" placeholder="Enter branch ID..." onchange="up(\\''+name+'\\',this.value,\\'str\\')">';
          html += '</div>';
        }
        varyList.innerHTML = html;
      }

      function renderParams(params, current) {
        if (!params || Object.keys(params).length === 0) {
          paramsList.innerHTML = '<div style="color:#666; font-size:11px; font-style:italic;">No parameters defined</div>';
          return;
        }
        let html = '';
        for (const [key, meta] of Object.entries(params)) {
          const value = current[key] !== undefined ? current[key] : (meta.default !== undefined ? meta.default : '');
          html += '<div class="param-item"><label class="param-label">' + key + '</label>';
          
          if (meta.type === 'enum' && meta.values) {
            html += '<select class="param-input" onchange="up(\\''+key+'\\',this.value,\\'str\\')">';
            html += '<option value="">Select...</option>';
            meta.values.forEach(v => html += '<option value="'+v+'" '+(String(v)===String(value)?'selected':'')+'>'+v+'</option>');
            html += '</select>';
          } else if (meta.type === 'bool') {
            html += '<select class="param-input" onchange="up(\\''+key+'\\',this.value === \\'true\\',\\'bool\\')">';
            html += '<option value="true" '+(String(value)==='true'?'selected':'')+'>True</option>';
            html += '<option value="false" '+(String(value)==='false'?'selected':'')+'>False</option>';
            html += '</select>';
          } else if (meta.type === 'list' && meta.values) {
            const selectedValues = Array.isArray(value) ? value.map(String) : [];
            html += '<div class="list-multi-select" style="background:#3c3c3c; padding:4px; border-radius:2px; max-height: 120px; overflow-y: auto; border: 1px solid #3c3c3c;">';
            meta.values.forEach(v => {
              const isChecked = selectedValues.includes(String(v));
              html += '<label style="display:flex; align-items:center; gap:6px; padding:2px 4px; cursor:pointer; font-size:11px;">';
              html += '<input type="checkbox" '+(isChecked?'checked':'')+' onchange="upList(\\''+key+'\\',\\''+v+'\\',this.checked)">';
              html += '<span>'+v+'</span></label>';
            });
            html += '</div>';
          } else if (meta.type === 'int' && meta.range) {
            const min = meta.range[0];
            const max = meta.range[1];
            // If the range is small (<= 20), use a dropdown, otherwise use a slider
            if (max - min <= 20) {
              html += '<select class="param-input" onchange="up(\\''+key+'\\',this.value,\\'int\\')">';
              for (let i = min; i <= max; i++) {
                html += '<option value="'+i+'" '+(parseInt(value, 10)===i?'selected':'')+'>'+i+'</option>';
              }
              html += '</select>';
            } else {
              html += '<div class="range-container"><input type="range" class="param-input" min="'+min+'" max="'+max+'" value="'+value+'" oninput="this.nextElementSibling.innerText=this.value" onchange="up(\\''+key+'\\',this.value,\\'int\\')"><span class="range-value">'+value+'</span></div>';
            }
          } else if (meta.type === 'int') {
            html += '<input type="number" class="param-input" value="'+value+'" onchange="up(\\''+key+'\\',this.value,\\'int\\')">';
          } else {
            const displayValue = Array.isArray(value) ? value.join(', ') : value;
            html += '<input type="text" class="param-input" value="'+displayValue+'" onchange="up(\\''+key+'\\',this.value,\\''+(meta.type==='list'?'list':'str')+'\\')">';
          }
          if (meta.doc) html += '<span class="param-doc">' + meta.doc + '</span>';
          html += '</div>';
        }
        paramsList.innerHTML = html;
      }

      window.upList = (key, val, checked) => {
        vscode.postMessage({ type: 'updateListParam', key, val, checked });
      };

      window.up = (key, val, type) => {
        let v = val;
        if (type === 'int') v = parseInt(val, 10);
        if (type === 'list') v = val.split(',').map(x => x.trim()).filter(x => x);
        vscode.postMessage({ type: 'updateParam', key, value: v });
      };

      function renderContent(data) {
        document.getElementById('tokens').textContent = (data.compiled_tokens || 0) + ' tokens';
        const cs = document.getElementById('cache');
        cs.textContent = data.cache_hit ? '✓ Cached' : '✗ Miss';
        cs.className = 'cache-status ' + (data.cache_hit ? 'cache-hit' : 'cache-miss');

        let html = '<div class="section"><div class="section-header">Compiled Prompt <button onclick="copy(this)">Copy</button></div><div class="section-content">' + escapeHtml(data.template) + '</div></div>';
        
        if (data.response_contract) {
          html += '<div class="section"><div class="section-header">Response Contract <button onclick="copy(this)">Copy</button></div><div class="section-content"><pre>' + escapeHtml(JSON.stringify(data.response_contract, null, 2)) + '</pre></div></div>';
        }
        main.innerHTML = html;
      }

      window.copy = (btn) => {
        const text = btn.parentElement.nextElementSibling.innerText;
        vscode.postMessage({ type: 'copy', data: { text } });
      };

      function escapeHtml(t) {
        return t ? t.toString().replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;") : '';
      }
      vscode.postMessage({ type: 'ready' });
    })();
  </script>
</body>
</html>`;
  }
}
