"use strict";
/**
 * Server API client for communicating with the dot-prompt Phoenix backend
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
exports.compile = compile;
exports.render = render;
exports.checkServerConnection = checkServerConnection;
exports.getServerUrl = getServerUrl;
const vscode = __importStar(require("vscode"));
const types_1 = require("./types");
/**
 * Get server configuration from VS Code settings
 */
function getServerConfig() {
    const config = vscode.workspace.getConfiguration('dotPrompt');
    return {
        serverUrl: config.get('serverUrl') || types_1.DEFAULT_CONFIG.serverUrl,
        timeout: config.get('timeout') || types_1.DEFAULT_CONFIG.timeout
    };
}
/**
 * Create a standardized error message for API failures
 */
function createApiError(error, context) {
    if (error instanceof Error) {
        // Check for common error patterns
        if (error.message.includes('ECONNREFUSED') || error.message.includes('connect')) {
            return {
                error: 'server_unreachable',
                message: `Cannot connect to .prompt server at ${getServerConfig().serverUrl}. Is the server running?`
            };
        }
        if (error.message.includes('timeout')) {
            return {
                error: 'timeout',
                message: 'Request to server timed out'
            };
        }
        return {
            error: 'api_error',
            message: `${context}: ${error.message}`
        };
    }
    return {
        error: 'unknown',
        message: `${context}: Unknown error occurred`
    };
}
/**
 * Compile a .prompt file by calling the backend API
 */
async function compile(prompt, params = {}, options = {}) {
    const config = getServerConfig();
    const request = {
        prompt,
        params,
        ...options
    };
    try {
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), config.timeout);
        const response = await fetch(`${config.serverUrl}/api/compile`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(request),
            signal: controller.signal
        });
        clearTimeout(timeoutId);
        if (!response.ok) {
            const errorData = await response.json().catch(() => ({}));
            const error = new Error(errorData.message || `Server returned ${response.status}`);
            error.apiError = errorData;
            throw error;
        }
        const data = await response.json();
        return data;
    }
    catch (error) {
        if (error instanceof Error && error.name === 'AbortError') {
            throw createApiError(new Error('Request timed out'), 'compile');
        }
        throw createApiError(error, 'compile');
    }
}
/**
 * Render a compiled template with runtime parameters
 */
async function render(template, params = {}) {
    const config = getServerConfig();
    const request = {
        template,
        params
    };
    try {
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), config.timeout);
        const response = await fetch(`${config.serverUrl}/api/render`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(request),
            signal: controller.signal
        });
        clearTimeout(timeoutId);
        if (!response.ok) {
            throw new Error(`Server returned ${response.status}`);
        }
        const data = await response.json();
        return data;
    }
    catch (error) {
        if (error instanceof Error && error.name === 'AbortError') {
            throw createApiError(new Error('Request timed out'), 'render');
        }
        throw createApiError(error, 'render');
    }
}
/**
 * Check if the server is reachable
 */
async function checkServerConnection() {
    const config = getServerConfig();
    try {
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 5000);
        const response = await fetch(`${config.serverUrl}/api/prompts`, {
            method: 'GET',
            signal: controller.signal
        });
        clearTimeout(timeoutId);
        return response.ok;
    }
    catch {
        return false;
    }
}
/**
 * Get the current server URL from settings
 */
function getServerUrl() {
    return getServerConfig().serverUrl;
}
//# sourceMappingURL=client.js.map