"use strict";
/**
 * Hover provider for .prompt files - shows compiled preview on hover
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
exports.HoverProvider = void 0;
const vscode = __importStar(require("vscode"));
const api = __importStar(require("./api/client"));
class HoverProvider {
    constructor() {
        this.cache = new Map();
        this.cacheTimeout = 5000; // 5 seconds
    }
    /**
     * Provide hover information for a position in a .prompt file
     */
    async provideHover(document, position) {
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
        }
        catch (error) {
            // Don't show hover on error, just return null
            return null;
        }
    }
    /**
     * Get cached compilation result
     */
    getCachedResult(uri) {
        const cached = this.cache.get(uri);
        if (cached && Date.now() - cached.timestamp < this.cacheTimeout) {
            return cached.result;
        }
        return null;
    }
    /**
     * Cache a compilation result
     */
    cacheResult(uri, result) {
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
    createHover(result) {
        const lines = [];
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
        }
        else {
            lines.push('', '---', '', '**Compiled Template:**', '```', preview, '```');
        }
        const markdown = new vscode.MarkdownString(lines.join('\n'));
        markdown.isTrusted = true;
        return new vscode.Hover(markdown);
    }
    /**
     * Clear the hover cache
     */
    clearCache() {
        this.cache.clear();
    }
}
exports.HoverProvider = HoverProvider;
//# sourceMappingURL=hover.js.map