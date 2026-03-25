import * as vscode from 'vscode';

export class DotPromptFormattingProvider implements vscode.DocumentFormattingEditProvider, vscode.DocumentRangeFormattingEditProvider {
    public provideDocumentFormattingEdits(
        document: vscode.TextDocument,
        options: vscode.FormattingOptions,
        token: vscode.CancellationToken
    ): vscode.TextEdit[] {
        console.log('DotPromptFormattingProvider: Formatting whole document...');
        return this.doFormat(document, new vscode.Range(0, 0, document.lineCount - 1, document.lineAt(document.lineCount - 1).text.length), options);
    }

    public provideDocumentRangeFormattingEdits(
        document: vscode.TextDocument,
        range: vscode.Range,
        options: vscode.FormattingOptions,
        token: vscode.CancellationToken
    ): vscode.TextEdit[] {
        console.log('DotPromptFormattingProvider: Formatting range...');
        return this.doFormat(document, range, options);
    }

    private doFormat(document: vscode.TextDocument, range: vscode.Range, options: vscode.FormattingOptions): vscode.TextEdit[] {
        const edits: vscode.TextEdit[] = [];
        let indentLevel = 0;
        let labelActiveAtLevel = -1;
        
        const indentSize = options.tabSize || 2;
        const useSpaces = options.insertSpaces;
        const indentChar = useSpaces ? ' '.repeat(indentSize) : '\t';

        // We process line by line from the start to maintain correct indentLevel
        // but only apply edits within the requested range
        for (let i = 0; i < document.lineCount; i++) {
            const line = document.lineAt(i);
            const text = line.text.trim();

            const isWithinRange = i >= range.start.line && i <= range.end.line;

            if (text === '') {
                if (isWithinRange && line.text !== '') {
                    edits.push(vscode.TextEdit.replace(new vscode.Range(i, 0, i, line.text.length), ''));
                }
                continue;
            }

            const isClosing = this.isClosingBlock(text);
            const isMiddle = this.isMiddleBlock(text);
            const isLabel = this.isLabel(text);

            if (isClosing) {
                if (labelActiveAtLevel === indentLevel - 1) {
                    indentLevel = Math.max(0, indentLevel - 1);
                    labelActiveAtLevel = -1;
                }
                indentLevel = Math.max(0, indentLevel - 1);
            } else if (isMiddle) {
                if (labelActiveAtLevel === indentLevel - 1) {
                    indentLevel = Math.max(0, indentLevel - 1);
                    labelActiveAtLevel = -1;
                }
                indentLevel = Math.max(0, indentLevel - 1);
            } else if (isLabel) {
                if (labelActiveAtLevel === indentLevel - 1) {
                    indentLevel = Math.max(0, indentLevel - 1);
                }
            }

            if (isWithinRange) {
                const newText = indentChar.repeat(indentLevel) + text;
                if (newText !== line.text) {
                    edits.push(vscode.TextEdit.replace(new vscode.Range(i, 0, i, line.text.length), newText));
                }
            }

            if (this.isStartingBlock(text)) {
                indentLevel++;
            } else if (isMiddle) {
                indentLevel++;
            } else if (isLabel) {
                indentLevel++;
                labelActiveAtLevel = indentLevel - 1;
            }
        }

        console.log(`DotPromptFormattingProvider: Returning ${edits.length} edits.`);
        return edits;
    }

    private isStartingBlock(text: string): boolean {
        return (/\bdo\b(\s*#.*)?$/.test(text) || /^init\s+do\b/.test(text) || /^docs\s+do\b/.test(text)) && !/^end\b/.test(text);
    }

    private isClosingBlock(text: string): boolean {
        return /^end\s+/.test(text) || text === 'end';
    }

    private isMiddleBlock(text: string): boolean {
        return /^elif\s+/.test(text) || /^else(\s*#.*)?$/.test(text);
    }

    private isLabel(text: string): boolean {
        if (text.startsWith('@')) return false;
        if (text.startsWith('{')) return false;
        if (text.startsWith('#')) return false;
        if (/^(init|docs|def|params|fragments|select|match|matchRe|limit|order|if|elif|else|case|vary|end|do)\b/.test(text)) return false;
        return /^[^:\s]+:\s*(.*)$/.test(text);
    }
}
