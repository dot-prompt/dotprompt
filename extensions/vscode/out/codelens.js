"use strict";
/**
 * CodeLens provider for .prompt files - adds quick action buttons
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
const vscode = __importStar(require("vscode"));
// Using type assertion to work around TypeScript variance issues with generic types
const codeLensProvider = {
    provideCodeLenses(document, _token) {
        // Only provide CodeLens for .prompt files
        if (document.languageId !== 'dot-prompt') {
            return [];
        }
        const codeLenses = [];
        // Add "Compile" CodeLens at the top of the file
        const compileRange = new vscode.Range(new vscode.Position(0, 0), new vscode.Position(0, 0));
        const compileCommand = {
            title: '▶ Compile',
            command: 'dot-prompt.compile',
            arguments: [document]
        };
        codeLenses.push(new vscode.CodeLens(compileRange, compileCommand));
        // Add "Open Compiled View" CodeLens
        const viewRange = new vscode.Range(new vscode.Position(1, 0), new vscode.Position(1, 0));
        const viewCommand = {
            title: '🔍 Open Compiled View',
            command: 'dot-prompt.openCompiledView',
            arguments: [document]
        };
        codeLenses.push(new vscode.CodeLens(viewRange, viewCommand));
        return codeLenses;
    },
    resolveCodeLens(codeLens, _token) {
        return codeLens;
    }
};
exports.default = codeLensProvider;
//# sourceMappingURL=codelens.js.map