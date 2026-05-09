import { complete, type Context } from "@mariozechner/pi-ai";
import type { ExtensionContext } from "@mariozechner/pi-coding-agent";
import { existsSync, readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { join, dirname } from "node:path";
import { homedir } from "node:os";

const FALLBACK_MESSAGE = "Working";
const TOOL_REFRESH_INTERVAL_MS = 30_000;
const VIBE_SYSTEM_PROMPT =
    "You generate short themed loading messages and reply with the requested text only.";

const BATCH_PROMPT = `Generate {count} unique 2-4 word loading messages for a "{theme}" theme.
Each message should end with "..."
Be creative, varied, and thematic. No duplicates.
Output one message per line, nothing else. No numbering, no bullets.`;

interface VibeConfig {
    theme: string | null;
    fallback: string;
}

let config: VibeConfig = loadConfig();
let extensionCtx: ExtensionContext | null = null;
let isStreaming = false;
let lastVibeTime = 0;
let vibeCache: string[] = [];
let vibeCacheTheme: string | null = null;
let vibeSeed = Date.now();
let vibeIndex = 0;

function getSettingsPath(): string {
    const homeDir = process.env.HOME || process.env.USERPROFILE || homedir();
    return join(homeDir, ".pi", "agent", "settings.json");
}

function isRecord(value: unknown): value is Record<string, unknown> {
    return typeof value === "object" && value !== null && !Array.isArray(value);
}

function readSettingsForLoad(): Record<string, unknown> {
    const settingsPath = getSettingsPath();

    try {
        if (!existsSync(settingsPath)) {
            return {};
        }

        const parsed = JSON.parse(readFileSync(settingsPath, "utf-8"));
        if (!isRecord(parsed)) {
            console.debug(`[working-vibes] Ignoring non-object settings at ${settingsPath}`);
            return {};
        }

        return parsed;
    } catch (error) {
        console.debug(`[working-vibes] Failed to load settings from ${settingsPath}:`, error);
        return {};
    }
}

function readSettingsForWrite(scope: string): Record<string, unknown> | null {
    const settingsPath = getSettingsPath();

    if (!existsSync(settingsPath)) {
        return {};
    }

    try {
        const parsed = JSON.parse(readFileSync(settingsPath, "utf-8"));
        if (!isRecord(parsed)) {
            console.debug(
                `[working-vibes] Refusing to write ${scope}: settings at ${settingsPath} is not an object`,
            );
            return null;
        }

        return parsed;
    } catch (error) {
        console.debug(
            `[working-vibes] Failed to parse settings while writing ${scope} at ${settingsPath}:`,
            error,
        );
        return null;
    }
}

function persistSettings(settings: Record<string, unknown>, scope: string): boolean {
    const settingsPath = getSettingsPath();

    try {
        mkdirSync(dirname(settingsPath), { recursive: true });
        writeFileSync(settingsPath, JSON.stringify(settings, null, 2) + "\n");
        return true;
    } catch (error) {
        console.debug(`[working-vibes] Failed to persist ${scope} to ${settingsPath}:`, error);
        return false;
    }
}

function loadConfig(): VibeConfig {
    const settings = readSettingsForLoad();
    const rawTheme = typeof settings.workingVibe === "string" ? settings.workingVibe : null;
    const theme = rawTheme?.toLowerCase() === "off" ? null : rawTheme;

    return {
        theme,
        fallback:
            typeof settings.workingVibeFallback === "string"
                ? settings.workingVibeFallback
                : FALLBACK_MESSAGE,
    };
}

function saveConfig(): boolean {
    const settings = readSettingsForWrite("workingVibe");
    if (!settings) {
        return false;
    }

    if (config.theme === null) {
        delete settings.workingVibe;
    } else {
        settings.workingVibe = config.theme;
    }

    delete settings.workingVibeMode;
    delete settings.workingVibeModel;
    delete settings.workingVibePrompt;
    delete settings.workingVibeMaxLength;

    return persistSettings(settings, "workingVibe");
}

function getVibesDir(): string {
    const homeDir = process.env.HOME || process.env.USERPROFILE || homedir();
    return join(homeDir, ".pi", "agent", "vibes");
}

function toVibeFileSlug(theme: string): string {
    const slug = theme
        .trim()
        .toLowerCase()
        .replace(/[^a-z0-9_-]+/g, "-")
        .replace(/-+/g, "-")
        .replace(/^[-_]+|[-_]+$/g, "");

    return slug || "theme";
}

function getVibeFilePath(theme: string): string {
    const filename = `${toVibeFileSlug(theme)}.txt`;
    return join(getVibesDir(), filename);
}

function loadVibesFromFile(theme: string): string[] {
    const filePath = getVibeFilePath(theme);
    if (!existsSync(filePath)) return [];

    try {
        const content = readFileSync(filePath, "utf-8");
        return content
            .split("\n")
            .map((line) => line.trim())
            .filter((line) => line.length > 0 && line.endsWith("..."));
    } catch (error) {
        console.debug(`[working-vibes] Failed to load vibe file ${filePath}:`, error);
        return [];
    }
}

function saveVibesToFile(theme: string, vibes: string[]): void {
    const vibesDir = getVibesDir();
    const filePath = getVibeFilePath(theme);

    if (!existsSync(vibesDir)) {
        mkdirSync(vibesDir, { recursive: true });
    }

    writeFileSync(filePath, `${vibes.join("\n")}\n`);
}

function mulberry32(seed: number): () => number {
    return function random(): number {
        let value = (seed += 0x6d2b79f5);
        value = Math.imul(value ^ (value >>> 15), value | 1);
        value ^= value + Math.imul(value ^ (value >>> 7), value | 61);
        return ((value ^ (value >>> 14)) >>> 0) / 4294967296;
    };
}

function getVibeAtIndex(vibes: string[], index: number, seed: number): string {
    if (vibes.length === 0) return `${config.fallback}...`;

    const effectiveIndex = index % vibes.length;
    const rng = mulberry32(seed);
    const indices = Array.from({ length: vibes.length }, (_, i) => i);

    for (let i = indices.length - 1; i > 0; i--) {
        const j = Math.floor(rng() * (i + 1));
        [indices[i], indices[j]] = [indices[j], indices[i]];
    }

    return vibes[indices[effectiveIndex]] ?? `${config.fallback}...`;
}

function getNextVibeFromFile(): string {
    if (!config.theme) return `${config.fallback}...`;

    if (vibeCacheTheme !== config.theme) {
        vibeCache = loadVibesFromFile(config.theme);
        vibeCacheTheme = config.theme;
        vibeSeed = Date.now();
        vibeIndex = 0;
    }

    if (vibeCache.length === 0) {
        return `${config.fallback}...`;
    }

    const vibe = getVibeAtIndex(vibeCache, vibeIndex, vibeSeed);
    vibeIndex++;
    return vibe;
}

function buildAiContext(prompt: string): Context {
    return {
        systemPrompt: VIBE_SYSTEM_PROMPT,
        messages: [
            {
                role: "user",
                content: [{ type: "text", text: prompt }],
                timestamp: Date.now(),
            },
        ],
    };
}

export function initVibeManager(ctx: ExtensionContext): void {
    extensionCtx = ctx;
    config = loadConfig();
}

export function getVibeTheme(): string | null {
    return config.theme;
}

export function setVibeTheme(theme: string | null): boolean {
    config = { ...config, theme };
    vibeCache = [];
    vibeCacheTheme = null;
    vibeIndex = 0;
    return saveConfig();
}

export function onVibeBeforeAgentStart(
    _prompt: string,
    setWorkingMessage: (msg?: string) => void,
): void {
    if (!config.theme || !extensionCtx) return;

    setWorkingMessage(getNextVibeFromFile());
    lastVibeTime = Date.now();
}

export function onVibeAgentStart(): void {
    isStreaming = true;
}

export function onVibeToolCall(
    _toolName: string,
    _toolInput: Record<string, unknown>,
    setWorkingMessage: (msg?: string) => void,
    _agentContext?: string,
): void {
    if (!config.theme || !extensionCtx || !isStreaming) return;

    const now = Date.now();
    if (now - lastVibeTime < TOOL_REFRESH_INTERVAL_MS) return;

    lastVibeTime = now;
    setWorkingMessage(getNextVibeFromFile());
}

export function onVibeAgentEnd(setWorkingMessage: (msg?: string) => void): void {
    isStreaming = false;
    setWorkingMessage(undefined);
}

export function hasVibeFile(theme: string): boolean {
    return existsSync(getVibeFilePath(theme));
}

export function getVibeFileCount(theme: string): number {
    const vibes = loadVibesFromFile(theme);
    return vibes.length;
}

export interface GenerateVibesResult {
    success: boolean;
    count: number;
    filePath: string;
    error?: string;
}

export async function generateVibesBatch(
    theme: string,
    count: number = 100,
    modelOverride?: unknown,
): Promise<GenerateVibesResult> {
    const filePath = getVibeFilePath(theme);
    const safeCount = Number.isFinite(count) ? Math.min(Math.max(Math.floor(count), 1), 500) : 100;

    if (!extensionCtx) {
        return { success: false, count: 0, filePath, error: "Extension not initialized" };
    }

    const model = modelOverride ?? extensionCtx.model;
    if (!model || typeof model !== "object") {
        return { success: false, count: 0, filePath, error: "No current model is configured" };
    }

    const auth = await extensionCtx.modelRegistry.getApiKeyAndHeaders(model as never);
    if (!auth.ok) {
        return { success: false, count: 0, filePath, error: auth.error };
    }

    const prompt = BATCH_PROMPT.replace(/\{theme\}/g, theme).replace(
        /\{count\}/g,
        String(safeCount),
    );

    try {
        const signal = AbortSignal.timeout(30_000);
        const response = await complete(model as never, buildAiContext(prompt), {
            apiKey: auth.apiKey,
            headers: auth.headers,
            signal,
        });

        const textContent = response.content.find((content) => content.type === "text");
        if (!textContent?.text) {
            const error =
                response.stopReason === "error" && response.errorMessage
                    ? response.errorMessage
                    : "Empty response from model";
            return { success: false, count: 0, filePath, error };
        }

        const vibes = textContent.text
            .split("\n")
            .map((line) => line.trim())
            .filter((line) => line.length > 0)
            .map((line) => {
                let vibe = line.replace(/^["'\d.\-)\s]+/, "").trim();
                vibe = vibe.replace(/["']$/g, "");
                if (!vibe.endsWith("...")) {
                    vibe = `${vibe.replace(/\.+$/, "")}...`;
                }
                return vibe;
            })
            .filter((vibe) => vibe.length > 3 && vibe !== "...");

        if (vibes.length === 0) {
            return { success: false, count: 0, filePath, error: "No valid vibes generated" };
        }

        saveVibesToFile(theme, vibes);

        if (vibeCacheTheme === theme) {
            vibeCache = [];
            vibeCacheTheme = null;
        }

        return { success: true, count: vibes.length, filePath };
    } catch (error) {
        const message = error instanceof Error ? error.message : "Unknown error";
        return { success: false, count: 0, filePath, error: message };
    }
}
