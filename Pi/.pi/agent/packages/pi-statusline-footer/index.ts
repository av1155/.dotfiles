import {
    copyToClipboard,
    createLocalBashOperations,
    type ExtensionAPI,
    type ReadonlyFooterDataProvider,
    type Theme,
} from "@mariozechner/pi-coding-agent";
import type { AssistantMessage } from "@mariozechner/pi-ai";
import {
    isKeyRelease,
    type AutocompleteProvider,
    truncateToWidth,
    TUI_KEYBINDINGS,
    visibleWidth,
} from "@mariozechner/pi-tui";
import { readFileSync, writeFileSync, existsSync, mkdirSync } from "node:fs";
import { join, dirname } from "node:path";
import { homedir } from "node:os";

import type { ColorScheme, CustomStatusItem, SegmentContext, StatusLinePreset } from "./types.js";
import type { PowerlineConfig, WidgetLineBudget } from "./powerline-config.js";
import {
    BashCompletionEngine,
    getOneOffBashCommandContext,
    OneOffAwareAutocompleteProvider,
    OneOffBashAutocompleteProvider,
} from "./bash-mode/completion.ts";
import { OneOffShellEditor } from "./bash-mode/editor.ts";
import { appendProjectHistory } from "./bash-mode/history.ts";
import { getPreset, PRESETS } from "./presets.js";
import {
    collectHiddenExtensionStatusKeys,
    getNotificationExtensionStatuses,
    nextPowerlineSettingWithOptions,
    nextPowerlineSettingWithPreset,
    parsePowerlineConfig,
} from "./powerline-config.js";
import { getGitStatus, invalidateGitStatus, invalidateGitBranch } from "./git-status.js";
import { ansi, getFgAnsiCode } from "./colors.js";
import { createRenderScheduler } from "./render-scheduler.ts";
import { readCoreContextUsage } from "./context-usage.ts";
import { renderFixedEditorCluster } from "./fixed-editor/cluster.ts";
import {
    emergencyTerminalModeReset,
    TerminalSplitCompositor,
} from "./fixed-editor/terminal-split.ts";
import { getDefaultColors } from "./theme.js";
import { renderModeIndicatorLine, renderStatuslineFooter } from "./statusline-renderer.js";
import {
    isSupportedSuperShortcut,
    matchesConfiguredShortcut,
    shortcutConflictKey,
    shortcutUsesSuper,
} from "./shortcuts.ts";
import {
    initVibeManager,
    onVibeBeforeAgentStart,
    onVibeAgentStart,
    onVibeAgentEnd,
    onVibeToolCall,
    getVibeTheme,
    setVibeTheme,
    hasVibeFile,
    getVibeFileCount,
    generateVibesBatch,
} from "./working-vibes.js";

// ═══════════════════════════════════════════════════════════════════════════
// Configuration
// ═══════════════════════════════════════════════════════════════════════════

let config: PowerlineConfig = {
    preset: "default",
    customItems: [],
    mouseScroll: true,
    fixedEditor: true,
    widgetBudgets: { widgets: {} },
};

const CUSTOM_COMPACTION_STATUS_KEY = "compact-policy";
let customCompactionEnabled = false;

interface PowerlineShortcuts {
    copyEditor: string;
    cutEditor: string;
    jumpLastUserMessage: string;
    jumpPreviousUserMessage: string;
    jumpNextUserMessage: string;
    jumpPreviousLlmMessage: string;
    jumpNextLlmMessage: string;
    jumpChatBottom: string;
    scrollChatUp: string;
    scrollChatDown: string;
    editorStart: string;
    editorEnd: string;
}

type PowerlineShortcutKey = keyof PowerlineShortcuts;
type ChatJumpShortcutKey = Extract<
    PowerlineShortcutKey,
    | "jumpLastUserMessage"
    | "jumpPreviousUserMessage"
    | "jumpNextUserMessage"
    | "jumpPreviousLlmMessage"
    | "jumpNextLlmMessage"
    | "jumpChatBottom"
>;
type ChatJumpRole = "user" | "assistant";
type ChatJumpDirection = "previous" | "next";
type ChatJumpShortcutAction =
    | { kind: "message"; role: ChatJumpRole; direction: ChatJumpDirection }
    | { kind: "lastMessage"; role: ChatJumpRole }
    | { kind: "bottom" };
type PowerlineShortcutAction =
    | { kind: "copyEditor" }
    | { kind: "cutEditor" }
    | { kind: "chat"; action: ChatJumpShortcutAction };

const DEFAULT_SHORTCUTS: PowerlineShortcuts = {
    copyEditor: "ctrl+alt+c",
    cutEditor: "ctrl+alt+x",
    jumpLastUserMessage: "ctrl+alt+m",
    jumpPreviousUserMessage: "ctrl+shift+u",
    jumpNextUserMessage: "ctrl+shift+i",
    jumpPreviousLlmMessage: "ctrl+alt+,",
    jumpNextLlmMessage: "ctrl+alt+.",
    jumpChatBottom: "ctrl+alt+j",
    scrollChatUp: "super+up",
    scrollChatDown: "super+down",
    editorStart: "super+shift+up",
    editorEnd: "super+shift+down",
};
const CHAT_JUMP_SHORTCUTS: Array<{
    shortcutKey: ChatJumpShortcutKey;
    description: string;
    action: ChatJumpShortcutAction;
}> = [
    {
        shortcutKey: "jumpLastUserMessage",
        description: "Jump to last user message",
        action: { kind: "lastMessage", role: "user" },
    },
    {
        shortcutKey: "jumpPreviousUserMessage",
        description: "Jump to previous user message",
        action: { kind: "message", role: "user", direction: "previous" },
    },
    {
        shortcutKey: "jumpNextUserMessage",
        description: "Jump to next user message",
        action: { kind: "message", role: "user", direction: "next" },
    },
    {
        shortcutKey: "jumpPreviousLlmMessage",
        description: "Jump to previous LLM message",
        action: { kind: "message", role: "assistant", direction: "previous" },
    },
    {
        shortcutKey: "jumpNextLlmMessage",
        description: "Jump to next LLM message",
        action: { kind: "message", role: "assistant", direction: "next" },
    },
    {
        shortcutKey: "jumpChatBottom",
        description: "Jump chat to bottom",
        action: { kind: "bottom" },
    },
];
const SHORTCUT_KEYS: PowerlineShortcutKey[] = [
    "copyEditor",
    "cutEditor",
    "jumpLastUserMessage",
    "jumpPreviousUserMessage",
    "jumpNextUserMessage",
    "jumpPreviousLlmMessage",
    "jumpNextLlmMessage",
    "jumpChatBottom",
    "scrollChatUp",
    "scrollChatDown",
    "editorStart",
    "editorEnd",
];
const APP_RESERVED_SHORTCUTS = [
    "escape",
    "ctrl+c",
    "ctrl+d",
    "ctrl+z",
    "shift+tab",
    "ctrl+p",
    "shift+ctrl+p",
    "ctrl+l",
    "ctrl+o",
    "shift+ctrl+o",
    "ctrl+t",
    "ctrl+n",
    "ctrl+g",
    "alt+enter",
    "alt+up",
    "alt+down",
    "ctrl+v",
    "alt+v",
    "shift+l",
    "shift+t",
    "ctrl+s",
    "ctrl+r",
    "ctrl+backspace",
    "ctrl+a",
    "ctrl+x",
    "ctrl+u",
] as const;
const EXTRA_RESERVED_SHORTCUTS = [] as const;
const SHORTCUT_MODIFIER_ORDER = ["ctrl", "alt", "super", "shift"] as const;
const SHORTCUT_MODIFIERS = new Set(SHORTCUT_MODIFIER_ORDER);
const SHORTCUT_NAMED_KEYS = new Set([
    "escape",
    "esc",
    "enter",
    "return",
    "tab",
    "space",
    "backspace",
    "delete",
    "insert",
    "clear",
    "home",
    "end",
    "pageup",
    "pagedown",
    "up",
    "down",
    "left",
    "right",
]);
const SHORTCUT_SYMBOL_KEYS = new Set([
    "`",
    "-",
    "=",
    "[",
    "]",
    "\\",
    ";",
    "'",
    ",",
    ".",
    "/",
    "!",
    "@",
    "#",
    "$",
    "%",
    "^",
    "&",
    "*",
    "(",
    ")",
    "_",
    "|",
    "~",
    "{",
    "}",
    ":",
    "<",
    ">",
    "?",
]);
const PROMPT_HISTORY_LIMIT = 100;
const LAYOUT_CACHE_TTL_MS = 250;
const STREAMING_LAYOUT_CACHE_TTL_MS = 1000;
const STATUS_RENDER_DEBOUNCE_MS = 33;
const CONTEXT_STATUS_RENDER_MS = 250;
const EDITOR_STATUS_DEFER_MS = 150;
const PROMPT_HISTORY_TRACKED = Symbol.for("powerlinePromptHistoryTracked");
const PROMPT_HISTORY_STATE_KEY = Symbol.for("powerlinePromptHistoryState");

type PromptHistoryState = { savedPromptHistory: string[] };
type SessionAssistantUsage = AssistantMessage["usage"];

function getUsageTokenTotal(usage: SessionAssistantUsage): number {
    const totalTokens =
        "totalTokens" in usage && typeof usage.totalTokens === "number" ? usage.totalTokens : 0;
    return totalTokens || usage.input + usage.output + usage.cacheRead + usage.cacheWrite;
}

function hasSessionAssistantUsage(value: unknown): value is SessionAssistantUsage {
    if (!isRecord(value)) {
        return false;
    }

    if (
        typeof value.input !== "number" ||
        typeof value.output !== "number" ||
        typeof value.cacheRead !== "number" ||
        typeof value.cacheWrite !== "number"
    ) {
        return false;
    }

    return isRecord(value.cost) && typeof value.cost.total === "number";
}

function isSessionAssistantMessage(value: unknown): value is AssistantMessage {
    return (
        isRecord(value) &&
        value.role === "assistant" &&
        hasSessionAssistantUsage(value.usage) &&
        (value.stopReason === undefined || typeof value.stopReason === "string")
    );
}

function isPromptHistoryState(value: unknown): value is PromptHistoryState {
    return (
        isRecord(value) &&
        Array.isArray(value.savedPromptHistory) &&
        value.savedPromptHistory.every((entry) => typeof entry === "string")
    );
}

function getPromptHistoryState(): PromptHistoryState {
    const existing = Reflect.get(globalThis, PROMPT_HISTORY_STATE_KEY);
    if (isPromptHistoryState(existing)) {
        return existing;
    }

    const state: PromptHistoryState = { savedPromptHistory: [] };
    Reflect.set(globalThis, PROMPT_HISTORY_STATE_KEY, state);
    return state;
}

function readPromptHistory(editor: any): string[] {
    const history = editor?.history;
    if (!Array.isArray(history)) return [];

    const normalized: string[] = [];
    for (const entry of history) {
        if (typeof entry !== "string") continue;
        const trimmed = entry.trim();
        if (!trimmed) continue;
        if (normalized.length > 0 && normalized[normalized.length - 1] === trimmed) continue;
        normalized.push(trimmed);
        if (normalized.length >= PROMPT_HISTORY_LIMIT) break;
    }

    return normalized;
}

function snapshotPromptHistory(editor: any): void {
    const history = readPromptHistory(editor);
    if (history.length > 0) {
        getPromptHistoryState().savedPromptHistory = [...history];
    }
}

function restorePromptHistory(editor: any): void {
    const { savedPromptHistory } = getPromptHistoryState();
    if (!savedPromptHistory.length || typeof editor?.addToHistory !== "function") return;

    for (let i = savedPromptHistory.length - 1; i >= 0; i--) {
        editor.addToHistory(savedPromptHistory[i]);
    }
}

function trackPromptHistory(editor: any): void {
    if (!editor || typeof editor.addToHistory !== "function") return;
    if (editor[PROMPT_HISTORY_TRACKED]) {
        snapshotPromptHistory(editor);
        return;
    }

    const originalAddToHistory = editor.addToHistory.bind(editor);
    editor.addToHistory = (text: string) => {
        originalAddToHistory(text);
        snapshotPromptHistory(editor);
    };
    editor[PROMPT_HISTORY_TRACKED] = true;
    snapshotPromptHistory(editor);
}

function getSettingsPath(): string {
    const homeDir = process.env.HOME || process.env.USERPROFILE || homedir();
    return join(homeDir, ".pi", "agent", "settings.json");
}

function getProjectSettingsPath(cwd: string): string {
    return join(cwd, ".pi", "settings.json");
}

function getGlobalCompactionPolicyPath(): string {
    const homeDir = process.env.HOME || process.env.USERPROFILE || homedir();
    return join(homeDir, ".pi", "agent", "compaction-policy.json");
}

function getCustomCompactionExtensionPath(): string {
    const homeDir = process.env.HOME || process.env.USERPROFILE || homedir();
    return join(homeDir, ".pi", "agent", "extensions", "pi-custom-compaction");
}

function mergeSettings(
    base: Record<string, unknown>,
    override: Record<string, unknown>,
): Record<string, unknown> {
    const merged: Record<string, unknown> = { ...base };

    for (const [key, overrideValue] of Object.entries(override)) {
        const baseValue = merged[key];
        merged[key] =
            isRecord(baseValue) && isRecord(overrideValue)
                ? mergeSettings(baseValue, overrideValue)
                : overrideValue;
    }

    return merged;
}

function readSettingsFile(settingsPath: string): Record<string, unknown> {
    try {
        if (!existsSync(settingsPath)) {
            return {};
        }

        const parsed = JSON.parse(readFileSync(settingsPath, "utf-8"));
        if (!isRecord(parsed)) {
            console.debug(`[powerline-footer] Ignoring non-object settings at ${settingsPath}`);
            return {};
        }

        return parsed;
    } catch (error) {
        // Settings are user-edited input. Log and keep the extension running with defaults
        // instead of crashing the UI during startup.
        console.debug(`[powerline-footer] Failed to read settings from ${settingsPath}:`, error);
        return {};
    }
}

function readWritableSettingsFile(settingsPath: string): Record<string, unknown> | null {
    if (!existsSync(settingsPath)) {
        return {};
    }

    try {
        const parsed = JSON.parse(readFileSync(settingsPath, "utf-8"));
        if (!isRecord(parsed)) {
            console.debug(
                `[powerline-footer] Refusing to write settings to non-object file at ${settingsPath}`,
            );
            return null;
        }

        return parsed;
    } catch (error) {
        // Do not overwrite malformed user settings with partial data. Surface the failure
        // through the command handler so the user can fix the file intentionally.
        console.debug(`[powerline-footer] Failed to parse settings at ${settingsPath}:`, error);
        return null;
    }
}

function readCompactionPolicyEnabled(configPath: string): boolean | undefined {
    if (!existsSync(configPath)) return undefined;
    try {
        const parsed = JSON.parse(readFileSync(configPath, "utf-8"));
        if (!isRecord(parsed) || typeof parsed.enabled !== "boolean") return false;
        return parsed.enabled;
    } catch (error) {
        console.debug(
            `[powerline-footer] Failed to read compaction policy from ${configPath}:`,
            error,
        );
        return false;
    }
}

function detectCustomCompactionEnabled(cwd: string): boolean {
    if (!existsSync(getCustomCompactionExtensionPath())) return false;

    const projectSetting = readCompactionPolicyEnabled(join(cwd, ".pi", "compaction-policy.json"));
    if (projectSetting !== undefined) return projectSetting;

    return readCompactionPolicyEnabled(getGlobalCompactionPolicyPath()) ?? false;
}

function isRecord(value: unknown): value is Record<string, unknown> {
    return typeof value === "object" && value !== null && !Array.isArray(value);
}

function readSettings(cwd: string = process.cwd()): Record<string, unknown> {
    return mergeSettings(
        readSettingsFile(getSettingsPath()),
        readSettingsFile(getProjectSettingsPath(cwd)),
    );
}

function writePowerlineSetting(
    cwd: string,
    update: (existingPowerlineSetting: unknown) => unknown,
): boolean {
    const globalSettingsPath = getSettingsPath();
    const projectSettingsPath = getProjectSettingsPath(cwd);
    const globalSettings = readWritableSettingsFile(globalSettingsPath);
    const projectSettings = readWritableSettingsFile(projectSettingsPath);

    if (globalSettings === null || projectSettings === null) {
        return false;
    }

    const writeToProject = Object.hasOwn(projectSettings, "powerline");
    const settingsPath = writeToProject ? projectSettingsPath : globalSettingsPath;
    const settings = writeToProject ? projectSettings : globalSettings;

    settings.powerline = update(settings.powerline);

    try {
        mkdirSync(dirname(settingsPath), { recursive: true });
        writeFileSync(settingsPath, JSON.stringify(settings, null, 2) + "\n");
        return true;
    } catch (error) {
        console.debug(
            `[powerline-footer] Failed to persist powerline setting to ${settingsPath}:`,
            error,
        );
        return false;
    }
}

function writePowerlinePresetSetting(
    preset: StatusLinePreset,
    cwd: string = process.cwd(),
): boolean {
    return writePowerlineSetting(cwd, (existingPowerlineSetting) =>
        nextPowerlineSettingWithPreset(existingPowerlineSetting, preset),
    );
}

function writePowerlineOptionSetting(
    cwd: string,
    updates: Partial<Pick<PowerlineConfig, "mouseScroll" | "fixedEditor">>,
    currentPreset: StatusLinePreset,
): boolean {
    return writePowerlineSetting(cwd, (existingPowerlineSetting) =>
        nextPowerlineSettingWithOptions(existingPowerlineSetting, updates, currentPreset),
    );
}

const PRESET_NAMES = Object.keys(PRESETS) as StatusLinePreset[];
const BUILTIN_HIDDEN_EXTENSION_STATUS_KEYS = ["plannotator"] as const;

function collectPowerlineHiddenExtensionStatusKeys(
    customItems: readonly CustomStatusItem[],
): Set<string> {
    const hidden = collectHiddenExtensionStatusKeys(customItems);
    for (const key of BUILTIN_HIDDEN_EXTENSION_STATUS_KEYS) hidden.add(key);
    return hidden;
}

function isValidPreset(value: unknown): value is StatusLinePreset {
    return typeof value === "string" && Object.hasOwn(PRESETS, value);
}

function normalizePreset(value: unknown): StatusLinePreset | null {
    if (typeof value !== "string") {
        return null;
    }

    const preset = value.trim().toLowerCase();
    return isValidPreset(preset) ? preset : null;
}

function hasNonWhitespaceText(text: string): boolean {
    return text.trim().length > 0;
}

function getCurrentEditorText(ctx: any, editor: any): string {
    return editor?.getExpandedText?.() ?? ctx.ui.getEditorText();
}

function normalizeShortcut(value: string): string {
    const parts = value.trim().toLowerCase().split("+");
    if (parts.length <= 1) return parts[0] ?? "";

    const modifierRank = new Map(
        SHORTCUT_MODIFIER_ORDER.map((modifier, index) => [modifier, index]),
    );
    const modifiers = parts
        .slice(0, -1)
        .sort((a, b) => (modifierRank.get(a) ?? 99) - (modifierRank.get(b) ?? 99));
    return [...modifiers, parts[parts.length - 1]].join("+");
}

function reservedShortcuts(): Set<string> {
    const shortcuts = new Set<string>(
        [...EXTRA_RESERVED_SHORTCUTS, ...APP_RESERVED_SHORTCUTS].map(normalizeShortcut),
    );

    for (const definition of Object.values(TUI_KEYBINDINGS)) {
        const defaultKeys = definition.defaultKeys;
        const keys =
            defaultKeys === undefined
                ? []
                : Array.isArray(defaultKeys)
                  ? defaultKeys
                  : [defaultKeys];
        for (const key of keys) {
            shortcuts.add(normalizeShortcut(key));
        }
    }

    return shortcuts;
}

function isValidShortcutKeyPart(keyPart: string): boolean {
    const lowerKeyPart = keyPart.toLowerCase();

    if (/^[a-z0-9]$/i.test(keyPart)) return true;
    if (/^f([1-9]|1[0-2])$/i.test(keyPart)) return true;
    if (SHORTCUT_NAMED_KEYS.has(lowerKeyPart)) return true;

    return SHORTCUT_SYMBOL_KEYS.has(keyPart);
}

function parseShortcutOverride(value: unknown): string | null {
    if (typeof value !== "string") {
        return null;
    }

    const trimmed = value.trim();
    if (!trimmed || /\s/.test(trimmed)) {
        return null;
    }

    const parts = trimmed.split("+");
    if (parts.some((part) => part.length === 0)) {
        return null;
    }

    const modifierParts = parts.slice(0, -1).map((part) => {
        const modifier = part.toLowerCase();
        return modifier === "cmd" || modifier === "command" ? "super" : modifier;
    });
    if (new Set(modifierParts).size !== modifierParts.length) {
        return null;
    }

    for (const modifier of modifierParts) {
        if (!SHORTCUT_MODIFIERS.has(modifier)) {
            return null;
        }
    }

    const keyPart = parts[parts.length - 1];
    if (!isValidShortcutKeyPart(keyPart)) {
        return null;
    }

    const normalizedKey = SHORTCUT_SYMBOL_KEYS.has(keyPart) ? keyPart : keyPart.toLowerCase();
    const normalizedShortcut = normalizeShortcut([...modifierParts, normalizedKey].join("+"));
    if (shortcutUsesSuper(normalizedShortcut) && !isSupportedSuperShortcut(normalizedShortcut)) {
        return null;
    }

    return normalizedShortcut;
}

function shortcutUsageKey(shortcut: string): string {
    return shortcutConflictKey(normalizeShortcut(shortcut));
}

function findShortcutReplacement(key: PowerlineShortcutKey, used: Set<string>): string | null {
    const preferred = DEFAULT_SHORTCUTS[key];
    if (!used.has(shortcutUsageKey(preferred))) {
        return preferred;
    }

    for (const shortcutKey of SHORTCUT_KEYS) {
        const candidate = DEFAULT_SHORTCUTS[shortcutKey];
        if (!used.has(shortcutUsageKey(candidate))) {
            return candidate;
        }
    }

    return null;
}

function resolveShortcutConfig(settings: Record<string, unknown>): PowerlineShortcuts {
    const resolved: PowerlineShortcuts = { ...DEFAULT_SHORTCUTS };
    const shortcutSettings = settings.powerlineShortcuts;

    if (isRecord(shortcutSettings)) {
        for (const key of SHORTCUT_KEYS) {
            const override = parseShortcutOverride(shortcutSettings[key]);
            if (override) {
                resolved[key] = override;
            }
        }
    }

    const used = new Set(Array.from(reservedShortcuts(), shortcutUsageKey));

    for (const key of SHORTCUT_KEYS) {
        const configured = resolved[key];
        const configuredUsageKey = shortcutUsageKey(configured);

        if (!used.has(configuredUsageKey)) {
            used.add(configuredUsageKey);
            continue;
        }

        const replacement = findShortcutReplacement(key, used);
        if (!replacement) {
            console.debug(
                `[powerline-footer] Shortcut conflict for ${key}: "${configured}" is already in use`,
            );
            continue;
        }

        console.debug(
            `[powerline-footer] Shortcut conflict for ${key}: "${configured}" replaced with "${replacement}"`,
        );

        resolved[key] = replacement;
        used.add(shortcutUsageKey(replacement));
    }

    return resolved;
}

// ═══════════════════════════════════════════════════════════════════════════
// Status Line Builder
// ═══════════════════════════════════════════════════════════════════════════

/**
 * Responsive segment layout - fits segments into top bar, overflows to secondary row.
 * When terminal is wide enough, secondary segments move up to top bar.
 * When narrow, top bar segments overflow down to secondary row.
 */
type ResponsiveLayout = {
    topContent: string;
    modeIndicatorContent: string;
    secondaryContent: string;
};

function computeResponsiveLayout(
    ctx: SegmentContext,
    presetDef: ReturnType<typeof getPreset>,
    availableWidth: number,
): ResponsiveLayout {
    void presetDef;
    return {
        topContent: renderStatuslineFooter(availableWidth, ctx),
        modeIndicatorContent: renderModeIndicatorLine(availableWidth, ctx),
        secondaryContent: "",
    };
}

// ═══════════════════════════════════════════════════════════════════════════
// Widget line budgets
// ═══════════════════════════════════════════════════════════════════════════

type WidgetSetWidget = (id: string, widget?: unknown, ...args: unknown[]) => unknown;

type WidgetBudgetSetWidgetPatchState = {
    originalSetWidget: WidgetSetWidget;
    patchedSetWidget: WidgetSetWidget;
    restore: () => void;
};

const WIDGET_BUDGET_SET_WIDGET_PATCH_KEY = Symbol.for("powerlineFooter.widgetBudgetSetWidgetPatch");

let widgetBudgetCappingEnabled = true;

function setWidgetBudgetCappingEnabled(enabled: boolean): void {
    widgetBudgetCappingEnabled = enabled;
}

function getConfiguredWidgetBudget(widgetId: string): WidgetLineBudget | undefined {
    if (!widgetBudgetCappingEnabled) return undefined;
    return config.widgetBudgets.widgets[widgetId];
}

function hasConfiguredWidgetBudgets(): boolean {
    return Object.keys(config.widgetBudgets.widgets).length > 0;
}

function compactWidgetOverflowLine(hiddenCount: number, width?: number): string {
    const line = ` ${getFgAnsiCode("sep")}… +${hiddenCount} more${ansi.reset}`;
    if (typeof width !== "number" || width <= 0 || visibleWidth(line) <= width) {
        return line;
    }

    return truncateToWidth(line, width, "…");
}

function capWidgetLineArray(
    lines: readonly string[],
    budget: WidgetLineBudget,
    width?: number,
): string[] {
    const maxLines = Math.max(1, Math.floor(budget.maxLines));
    if (lines.length <= maxLines) return [...lines];

    const keptLineCount = Math.max(0, maxLines - 1);
    const hiddenCount = lines.length - keptLineCount;
    return [...lines.slice(0, keptLineCount), compactWidgetOverflowLine(hiddenCount, width)];
}

function capWidgetRenderResult(widgetId: string, rendered: unknown, width?: number): unknown {
    const budget = getConfiguredWidgetBudget(widgetId);
    if (!budget || !Array.isArray(rendered)) return rendered;

    return capWidgetLineArray(rendered as string[], budget, width);
}

function wrapBudgetedWidgetComponent(widgetId: string, component: unknown): unknown {
    if (typeof component !== "object" || component === null) return component;

    const originalRender = Reflect.get(component, "render");
    if (typeof originalRender !== "function") return component;

    return new Proxy(component as Record<PropertyKey, unknown>, {
        get(target, prop, receiver) {
            if (prop !== "render") return Reflect.get(target, prop, receiver);

            return function renderWithPowerlineWidgetBudget(width: number, ...args: unknown[]) {
                const rendered = originalRender.apply(target, [width, ...args]);
                return capWidgetRenderResult(
                    widgetId,
                    rendered,
                    typeof width === "number" ? width : undefined,
                );
            };
        },
    });
}

function wrapBudgetedWidgetRegistration(widgetId: string, widget: unknown): unknown {
    if (!getConfiguredWidgetBudget(widgetId) || widget === undefined || widget === null) {
        return widget;
    }

    if (Array.isArray(widget)) {
        return capWidgetRenderResult(widgetId, widget);
    }

    if (typeof widget === "function") {
        return function powerlineBudgetedWidgetFactory(this: unknown, ...args: unknown[]) {
            const component = widget.apply(this, args);
            return wrapBudgetedWidgetComponent(widgetId, component);
        };
    }

    return wrapBudgetedWidgetComponent(widgetId, widget);
}

function getWidgetBudgetPatchState(ui: unknown): WidgetBudgetSetWidgetPatchState | null {
    if (typeof ui !== "object" || ui === null) return null;
    const state = Reflect.get(ui, WIDGET_BUDGET_SET_WIDGET_PATCH_KEY);
    if (typeof state !== "object" || state === null) return null;

    const maybeState = state as Partial<WidgetBudgetSetWidgetPatchState>;
    return typeof maybeState.originalSetWidget === "function" &&
        typeof maybeState.patchedSetWidget === "function" &&
        typeof maybeState.restore === "function"
        ? (maybeState as WidgetBudgetSetWidgetPatchState)
        : null;
}

function restoreExistingWidgetBudgetPatch(ui: unknown): void {
    const state = getWidgetBudgetPatchState(ui);
    state?.restore();
}

function installWidgetBudgetPatch(ctx: any): (() => void) | null {
    const ui = ctx?.ui;
    if (typeof ui !== "object" || ui === null || typeof ui.setWidget !== "function") {
        return null;
    }

    restoreExistingWidgetBudgetPatch(ui);
    if (!hasConfiguredWidgetBudgets()) return null;

    const originalSetWidget = ui.setWidget as WidgetSetWidget;
    const patchedSetWidget: WidgetSetWidget = function powerlineBudgetedSetWidget(
        widgetId: string,
        widget?: unknown,
        ...args: unknown[]
    ) {
        return originalSetWidget.call(
            ui,
            widgetId,
            wrapBudgetedWidgetRegistration(widgetId, widget),
            ...args,
        );
    };

    const patchState: WidgetBudgetSetWidgetPatchState = {
        originalSetWidget,
        patchedSetWidget,
        restore: () => {
            if (Reflect.get(ui, "setWidget") === patchedSetWidget) {
                Reflect.set(ui, "setWidget", originalSetWidget);
            }
            if (Reflect.get(ui, WIDGET_BUDGET_SET_WIDGET_PATCH_KEY) === patchState) {
                Reflect.deleteProperty(ui, WIDGET_BUDGET_SET_WIDGET_PATCH_KEY);
            }
        },
    };

    Object.defineProperty(ui, WIDGET_BUDGET_SET_WIDGET_PATCH_KEY, {
        value: patchState,
        configurable: true,
    });
    Reflect.set(ui, "setWidget", patchedSetWidget);

    return patchState.restore;
}

// ═══════════════════════════════════════════════════════════════════════════
// Extension
// ═══════════════════════════════════════════════════════════════════════════

export default function powerlineFooter(pi: ExtensionAPI) {
    const startupSettings = readSettings();
    config = parsePowerlineConfig(startupSettings.powerline, PRESET_NAMES);
    let resolvedShortcuts = resolveShortcutConfig(startupSettings);

    let enabled = true;
    let sessionStartTime = Date.now();
    let currentCtx: any = null;
    let footerDataRef: ReadonlyFooterDataProvider | null = null;
    let getThinkingLevelFn: (() => string) | null = null;
    let currentThinkingLevel: string | null = null;
    let liveAssistantUsage: SessionAssistantUsage | null = null;
    let isStreaming = false;
    let tuiRef: any = null;
    let restoreFooterStatusRepaintHook: (() => void) | null = null;
    let restoreWidgetBudgetPatch: (() => void) | null = null;
    let fixedEditorCompositor: TerminalSplitCompositor | null = null;
    let fixedStatusContainer: any = null;
    let fixedEditorContainer: any = null;
    let fixedWidgetContainerAbove: any = null;
    let fixedWidgetContainerBelow: any = null;
    let shortcutInputUnsubscribe: (() => void) | null = null;
    let lastUserPrompt = "";
    let showLastPrompt = true;
    let currentEditor: any = null;
    let bashCompletionEngine = new BashCompletionEngine();

    // Cache for the top and secondary powerline widgets.
    let lastLayoutWidth = 0;
    let lastLayoutResult: ResponsiveLayout | null = null;
    let lastLayoutTimestamp = 0;
    let layoutDirty = true;
    let forceNextLayoutRecompute = false;
    let lastEditorInputAt = 0;

    const getShellPath = () => process.env.SHELL || "/bin/sh";
    const getShellCwd = () => currentCtx?.cwd ?? process.cwd();

    const statusRenderScheduler = createRenderScheduler(() => {
        const msSinceInput = Date.now() - lastEditorInputAt;
        if (layoutDirty && !forceNextLayoutRecompute && msSinceInput < EDITOR_STATUS_DEFER_MS) {
            statusRenderScheduler.schedule(Math.max(0, EDITOR_STATUS_DEFER_MS - msSinceInput));
            return;
        }

        tuiRef?.requestRender();
    }, STATUS_RENDER_DEBOUNCE_MS);

    const resetLayoutCache = () => {
        lastLayoutResult = null;
        layoutDirty = true;
    };

    const requestStatusRender = (delayMs?: number) => {
        layoutDirty = true;
        statusRenderScheduler.schedule(delayMs);
    };

    const requestImmediateStatusRender = (options: { deferDuringTyping?: boolean } = {}) => {
        layoutDirty = true;
        if (
            options.deferDuringTyping !== false &&
            Date.now() - lastEditorInputAt < EDITOR_STATUS_DEFER_MS
        ) {
            statusRenderScheduler.schedule();
            return;
        }

        forceNextLayoutRecompute = true;
        statusRenderScheduler.cancel();
        statusRenderScheduler.schedule(0);
    };

    const installFooterStatusRepaintHook = (footerData: ReadonlyFooterDataProvider) => {
        restoreFooterStatusRepaintHook?.();
        restoreFooterStatusRepaintHook = null;

        const writableFooterData = footerData as ReadonlyFooterDataProvider & {
            setExtensionStatus?: (key: string, text: string | undefined) => void;
            clearExtensionStatuses?: () => void;
        };
        if (typeof writableFooterData.setExtensionStatus !== "function") return;

        const originalSetExtensionStatus = writableFooterData.setExtensionStatus;
        const originalClearExtensionStatuses = writableFooterData.clearExtensionStatuses;
        const setExtensionStatusAndRepaint = function setExtensionStatusAndRepaint(
            this: unknown,
            key: string,
            text: string | undefined,
        ) {
            originalSetExtensionStatus.call(this, key, text);
            requestImmediateStatusRender();
        };
        writableFooterData.setExtensionStatus = setExtensionStatusAndRepaint;

        let clearExtensionStatusesAndRepaint: (() => void) | null = null;
        if (typeof originalClearExtensionStatuses === "function") {
            clearExtensionStatusesAndRepaint = function clearExtensionStatusesAndRepaint(
                this: unknown,
            ) {
                originalClearExtensionStatuses.call(this);
                requestImmediateStatusRender();
            };
            writableFooterData.clearExtensionStatuses = clearExtensionStatusesAndRepaint;
        }

        restoreFooterStatusRepaintHook = () => {
            if (writableFooterData.setExtensionStatus === setExtensionStatusAndRepaint) {
                writableFooterData.setExtensionStatus = originalSetExtensionStatus;
            }
            if (
                clearExtensionStatusesAndRepaint &&
                writableFooterData.clearExtensionStatuses === clearExtensionStatusesAndRepaint
            ) {
                writableFooterData.clearExtensionStatuses = originalClearExtensionStatuses;
            }
        };
    };

    // Track session start
    pi.on("session_start", async (_event, ctx) => {
        sessionStartTime = Date.now();
        currentCtx = ctx;
        customCompactionEnabled = detectCustomCompactionEnabled(ctx.cwd);
        lastUserPrompt = "";
        isStreaming = false;
        liveAssistantUsage = null;

        const settings = readSettings(ctx.cwd);
        resolvedShortcuts = resolveShortcutConfig(settings);
        showLastPrompt = settings.showLastPrompt !== false;
        config = parsePowerlineConfig(settings.powerline, PRESET_NAMES);
        bashCompletionEngine = new BashCompletionEngine();

        restoreWidgetBudgetPatch?.();
        restoreWidgetBudgetPatch = null;
        setWidgetBudgetCappingEnabled(enabled);
        if (enabled && ctx.hasUI) {
            restoreWidgetBudgetPatch = installWidgetBudgetPatch(ctx);
        }

        getThinkingLevelFn =
            typeof ctx.getThinkingLevel === "function" ? () => ctx.getThinkingLevel() : null;
        currentThinkingLevel = getThinkingLevelFn?.() ?? null;

        initVibeManager(ctx);

        if (enabled && ctx.hasUI) {
            setupCustomEditor(ctx);
        }
    });

    pi.on("session_shutdown", async () => {
        statusRenderScheduler.cancel();
        restoreFooterStatusRepaintHook?.();
        restoreFooterStatusRepaintHook = null;
        restoreWidgetBudgetPatch?.();
        restoreWidgetBudgetPatch = null;
        setWidgetBudgetCappingEnabled(false);
        teardownFixedEditorCompositor({ resetExtendedKeyboardModes: true });
        shortcutInputUnsubscribe?.();
        shortcutInputUnsubscribe = null;
        currentCtx = null;
        footerDataRef = null;
        getThinkingLevelFn = null;
        currentThinkingLevel = null;
        liveAssistantUsage = null;
        tuiRef = null;
        currentEditor = null;
        resetLayoutCache();
    });

    // Check if a bash command might change git branch
    const mightChangeGitBranch = (cmd: string): boolean => {
        const gitBranchPatterns = [
            /\bgit\s+(checkout|switch|branch\s+-[dDmM]|merge|rebase|pull|reset|worktree)/,
            /\bgit\s+stash\s+(pop|apply)/,
        ];
        return gitBranchPatterns.some((p) => p.test(cmd));
    };

    // Invalidate git status on file changes, trigger re-render on potential branch changes
    pi.on("tool_result", async (event) => {
        if (event.toolName === "write" || event.toolName === "edit") {
            invalidateGitStatus();
        }
        // Check for bash commands that might change git branch
        if (event.toolName === "bash" && event.input?.command) {
            const cmd = String(event.input.command);
            if (mightChangeGitBranch(cmd)) {
                // Invalidate caches since working tree state changes with branch
                invalidateGitStatus();
                invalidateGitBranch();
                // Small delay to let git update, then re-render
                setTimeout(() => requestStatusRender(), 100);
            }
        }
    });

    pi.on("user_bash", async (event) => {
        const operations = createLocalBashOperations({ shellPath: getShellPath() });

        if (mightChangeGitBranch(event.command)) {
            invalidateGitStatus();
            invalidateGitBranch();
            setTimeout(() => requestStatusRender(), 100);
            setTimeout(() => requestStatusRender(), 300);
            setTimeout(() => requestStatusRender(), 500);
        }

        return {
            operations: {
                exec: async (command, cwd, options) => {
                    const result = await operations.exec(command, cwd, options);
                    if (result.exitCode === 0) {
                        appendProjectHistory(event.cwd, event.command, cwd);
                    }
                    return result;
                },
            },
        };
    });

    pi.on("model_select", async (_event, ctx) => {
        currentCtx = ctx;
        requestStatusRender();
    });

    pi.on("thinking_level_select", async (event, ctx) => {
        currentCtx = ctx;
        currentThinkingLevel =
            getThinkingLevelFn?.() ?? (typeof event.level === "string" ? event.level : null);
        requestImmediateStatusRender({ deferDuringTyping: false });
    });

    pi.on("session_tree", async (_event, ctx) => {
        currentCtx = ctx;
        currentThinkingLevel = null;
        liveAssistantUsage = null;
        requestImmediateStatusRender({ deferDuringTyping: false });
    });

    // Generate themed working message before agent starts (has access to user's prompt)
    pi.on("before_agent_start", async (event, ctx) => {
        lastUserPrompt = event.prompt;
        if (ctx.hasUI) {
            onVibeBeforeAgentStart(event.prompt, ctx.ui.setWorkingMessage);
        }
    });

    pi.on("agent_start", async (_event, ctx) => {
        isStreaming = true;
        liveAssistantUsage = null;
        onVibeAgentStart();
        currentCtx = ctx;
    });

    pi.on("message_update", async (event, ctx) => {
        if (
            isSessionAssistantMessage(event.message) &&
            event.message.stopReason !== "error" &&
            event.message.stopReason !== "aborted" &&
            getUsageTokenTotal(event.message.usage) > 0
        ) {
            liveAssistantUsage = event.message.usage;
            currentCtx = ctx;
            layoutDirty = true;
            statusRenderScheduler.schedule(CONTEXT_STATUS_RENDER_MS);
        }
    });

    pi.on("message_end", async (event, ctx) => {
        currentCtx = ctx;
        if (isSessionAssistantMessage(event.message)) {
            if (event.message.stopReason === "error" || event.message.stopReason === "aborted") {
                liveAssistantUsage = null;
            } else if (getUsageTokenTotal(event.message.usage) > 0) {
                liveAssistantUsage = event.message.usage;
            }
        }
        requestImmediateStatusRender({ deferDuringTyping: false });
    });

    pi.on("turn_end", async (_event, ctx) => {
        currentCtx = ctx;
        requestImmediateStatusRender({ deferDuringTyping: false });
    });

    pi.on("tool_call", async (event, ctx) => {
        if (ctx.hasUI) {
            const agentContext = getRecentAgentContext(ctx);
            onVibeToolCall(event.toolName, event.input, ctx.ui.setWorkingMessage, agentContext);
        }
    });

    // Helper to extract recent agent response text (skipping thinking blocks)
    function getRecentAgentContext(ctx: any): string | undefined {
        const sessionEvents = ctx.sessionManager?.getBranch?.() ?? [];

        // Find the most recent assistant message
        for (let i = sessionEvents.length - 1; i >= 0; i--) {
            const e = sessionEvents[i];
            if (e.type === "message" && e.message?.role === "assistant") {
                const content = e.message.content;
                if (!Array.isArray(content)) continue;

                // Extract text content, skip thinking blocks
                for (const block of content) {
                    if (block.type === "text" && block.text) {
                        // Return first ~200 chars of non-empty text
                        const text = block.text.trim();
                        if (text.length > 0) {
                            return text.slice(0, 200);
                        }
                    }
                }
            }
        }
        return undefined;
    }

    function copyTextToClipboard(ctx: any, text: string, successMessage?: string): void {
        copyToClipboard(text);
        if (successMessage) {
            ctx.ui.notify(successMessage, "info");
        }
    }

    function getEditorTextForClipboard(ctx: any): string | null {
        const text = getCurrentEditorText(ctx, currentEditor);
        if (hasNonWhitespaceText(text)) {
            return text;
        }

        ctx.ui.notify("Editor is empty", "info");
        return null;
    }

    function getChatJumpShortcutAction(data: string): ChatJumpShortcutAction | null {
        return (
            CHAT_JUMP_SHORTCUTS.find(({ shortcutKey }) =>
                matchesConfiguredShortcut(data, resolvedShortcuts[shortcutKey]),
            )?.action ?? null
        );
    }

    function getPowerlineShortcutAction(data: string): PowerlineShortcutAction | null {
        if (isKeyRelease(data)) return null;

        if (matchesConfiguredShortcut(data, resolvedShortcuts.copyEditor)) {
            return { kind: "copyEditor" };
        }
        if (matchesConfiguredShortcut(data, resolvedShortcuts.cutEditor)) {
            return { kind: "cutEditor" };
        }

        const chatJumpAction = getChatJumpShortcutAction(data);
        return chatJumpAction ? { kind: "chat", action: chatJumpAction } : null;
    }

    function runPowerlineShortcut(ctx: any, action: PowerlineShortcutAction): void {
        if (action.kind === "copyEditor" || action.kind === "cutEditor") {
            const text = getEditorTextForClipboard(ctx);
            if (!text) return;

            copyTextToClipboard(
                ctx,
                text,
                action.kind === "copyEditor" ? "Copied editor text" : undefined,
            );
            if (action.kind === "cutEditor") {
                ctx.ui.setEditorText("");
                ctx.ui.notify("Cut editor text", "info");
            }
            return;
        }

        if (action.action.kind === "lastMessage") {
            jumpToLastChatMessage(ctx, action.action.role);
            return;
        }

        if (action.action.kind === "bottom") {
            jumpChatToBottom(ctx);
            return;
        }

        jumpToChatMessage(ctx, action.action.role, action.action.direction);
    }

    pi.on("agent_end", async (_event, ctx) => {
        isStreaming = false;
        liveAssistantUsage = null;
        currentCtx = ctx;
        if (ctx.hasUI) {
            onVibeAgentEnd(ctx.ui.setWorkingMessage);
        }
        requestStatusRender();
    });

    // Command to toggle/configure
    pi.registerCommand("powerline", {
        description: "Configure powerline status (toggle, preset)",
        handler: async (args, ctx) => {
            // Update context reference (command ctx may have more methods)
            currentCtx = ctx;

            if (!args?.trim()) {
                // Toggle
                enabled = !enabled;
                if (enabled) {
                    restoreWidgetBudgetPatch?.();
                    setWidgetBudgetCappingEnabled(true);
                    restoreWidgetBudgetPatch = ctx.hasUI ? installWidgetBudgetPatch(ctx) : null;
                    setupCustomEditor(ctx);
                    ctx.ui.notify("Powerline enabled", "info");
                } else {
                    getPromptHistoryState().savedPromptHistory = [];
                    restoreWidgetBudgetPatch?.();
                    restoreWidgetBudgetPatch = null;
                    setWidgetBudgetCappingEnabled(false);
                    restoreFooterStatusRepaintHook?.();
                    restoreFooterStatusRepaintHook = null;
                    teardownFixedEditorCompositor();
                    shortcutInputUnsubscribe?.();
                    shortcutInputUnsubscribe = null;
                    // Clear all custom UI components
                    ctx.ui.setEditorComponent(undefined);
                    ctx.ui.setFooter(undefined);
                    ctx.ui.setHeader(undefined);
                    ctx.ui.setWidget("powerline-top", undefined);
                    ctx.ui.setWidget("powerline-secondary", undefined);
                    ctx.ui.setWidget("powerline-status", undefined);
                    ctx.ui.setWidget("powerline-last-prompt", undefined);
                    footerDataRef = null;
                    tuiRef = null;
                    currentEditor = null;
                    statusRenderScheduler.cancel();
                    resetLayoutCache();
                    ctx.ui.notify("Powerline disabled", "info");
                }
                return;
            }

            const normalizedArgs = args.trim().toLowerCase();
            const mouseScrollMatch = /^mouse-scroll(?:\s+(on|off|toggle))?$/.exec(normalizedArgs);
            if (mouseScrollMatch) {
                const mode = mouseScrollMatch[1] ?? "toggle";
                config.mouseScroll = mode === "toggle" ? !config.mouseScroll : mode === "on";
                if (enabled && ctx.hasUI && config.fixedEditor && tuiRef && currentEditor) {
                    installFixedEditorCompositor(ctx, tuiRef);
                }

                if (
                    writePowerlineOptionSetting(
                        ctx.cwd,
                        { mouseScroll: config.mouseScroll },
                        config.preset,
                    )
                ) {
                    ctx.ui.notify(
                        `Powerline mouse scroll ${config.mouseScroll ? "enabled" : "disabled"}`,
                        "info",
                    );
                } else {
                    ctx.ui.notify(
                        `Powerline mouse scroll ${config.mouseScroll ? "enabled" : "disabled"} (not persisted; check settings.json)`,
                        "warning",
                    );
                }
                return;
            }

            const fixedEditorMatch = /^fixed-editor(?:\s+(on|off|toggle))?$/.exec(normalizedArgs);
            if (fixedEditorMatch) {
                const mode = fixedEditorMatch[1] ?? "toggle";
                config.fixedEditor = mode === "toggle" ? !config.fixedEditor : mode === "on";
                if (enabled && ctx.hasUI) {
                    setupCustomEditor(ctx);
                }

                if (
                    writePowerlineOptionSetting(
                        ctx.cwd,
                        { fixedEditor: config.fixedEditor },
                        config.preset,
                    )
                ) {
                    ctx.ui.notify(
                        `Powerline fixed editor ${config.fixedEditor ? "enabled" : "disabled"}`,
                        "info",
                    );
                } else {
                    ctx.ui.notify(
                        `Powerline fixed editor ${config.fixedEditor ? "enabled" : "disabled"} (not persisted; check settings.json)`,
                        "warning",
                    );
                }
                return;
            }

            const preset = normalizePreset(args);
            if (preset) {
                config.preset = preset;
                resetLayoutCache();
                if (enabled) {
                    setupCustomEditor(ctx);
                }

                if (writePowerlinePresetSetting(preset, ctx.cwd)) {
                    ctx.ui.notify(`Preset set to: ${preset}`, "info");
                } else {
                    ctx.ui.notify(
                        `Preset set to: ${preset} (not persisted; check settings.json)`,
                        "warning",
                    );
                }
                return;
            }

            // Show available presets
            const presetList = Object.keys(PRESETS).join(", ");
            ctx.ui.notify(`Available presets: ${presetList}`, "info");
        },
    });

    pi.registerShortcut(resolvedShortcuts.copyEditor, {
        description: "Copy full editor text",
        handler: async (ctx) => {
            if (!enabled || !ctx.hasUI) return;

            const text = getEditorTextForClipboard(ctx);
            if (!text) return;

            copyTextToClipboard(ctx, text, "Copied editor text");
        },
    });

    pi.registerShortcut(resolvedShortcuts.cutEditor, {
        description: "Cut full editor text",
        handler: async (ctx) => {
            if (!enabled || !ctx.hasUI) return;

            const text = getEditorTextForClipboard(ctx);
            if (!text) return;

            copyTextToClipboard(ctx, text);
            ctx.ui.setEditorText("");
            ctx.ui.notify("Cut editor text", "info");
        },
    });

    for (const { shortcutKey, description, action } of CHAT_JUMP_SHORTCUTS) {
        pi.registerShortcut(resolvedShortcuts[shortcutKey], {
            description,
            handler: async (ctx) => {
                if (!enabled || !ctx.hasUI) return;
                runPowerlineShortcut(ctx, { kind: "chat", action });
            },
        });
    }

    // Command to set working message theme
    pi.registerCommand("vibe", {
        description: "Set working message theme. Usage: /vibe [theme|off|generate]",
        handler: async (args, ctx) => {
            const parts = args?.trim().split(/\s+/) || [];
            const subcommand = parts[0]?.toLowerCase();

            // No args: show current status
            if (!args || !args.trim()) {
                const theme = getVibeTheme();
                let status = `Vibe: ${theme || "off"}`;
                if (theme) {
                    const count = getVibeFileCount(theme);
                    status += count > 0 ? ` | File: ${count} vibes` : " | File: not found";
                }
                ctx.ui.notify(status, "info");
                return;
            }

            // /vibe generate <theme> [count] - generate vibes and save to file
            if (subcommand === "generate") {
                const theme = parts[1];
                const parsedCount = Number.parseInt(parts[2] ?? "", 10);
                const count = Number.isFinite(parsedCount)
                    ? Math.min(Math.max(Math.floor(parsedCount), 1), 500)
                    : 100;

                if (!theme) {
                    ctx.ui.notify("Usage: /vibe generate <theme> [count]", "error");
                    return;
                }

                ctx.ui.notify(`Generating ${count} vibes for "${theme}"...`, "info");

                const result = await generateVibesBatch(theme, count, ctx.model);

                if (result.success) {
                    ctx.ui.notify(
                        `Generated ${result.count} vibes for "${theme}" → ${result.filePath}`,
                        "info",
                    );
                } else {
                    ctx.ui.notify(`Failed to generate vibes: ${result.error}`, "error");
                }
                return;
            }

            // /vibe off - disable
            if (subcommand === "off") {
                const persisted = setVibeTheme(null);
                if (persisted) {
                    ctx.ui.notify("Vibe disabled", "info");
                } else {
                    ctx.ui.notify("Vibe disabled (not persisted; check settings.json)", "warning");
                }
                return;
            }

            // /vibe <theme> - set theme (preserve original casing)
            const theme = args.trim();
            const persisted = setVibeTheme(theme);
            if (!hasVibeFile(theme)) {
                const suffix = persisted ? "" : " (not persisted; check settings.json)";
                ctx.ui.notify(
                    `Vibe set to: ${theme} (no file found - run /vibe generate ${theme})${suffix}`,
                    "warning",
                );
            } else if (persisted) {
                ctx.ui.notify(`Vibe set to: ${theme}`, "info");
            } else {
                ctx.ui.notify(
                    `Vibe set to: ${theme} (not persisted; check settings.json)`,
                    "warning",
                );
            }
        },
    });

    function buildSegmentContext(ctx: any, theme: Theme): SegmentContext {
        const presetDef = getPreset(config.preset);
        const colors: ColorScheme = presetDef.colors ?? getDefaultColors();

        // Build usage stats and get thinking level from session
        let input = 0,
            output = 0,
            cacheRead = 0,
            cacheWrite = 0,
            cost = 0;
        let lastAssistant: AssistantMessage | undefined;
        let thinkingLevelFromSession: string | null = null;

        const sessionEvents = ctx.sessionManager?.getBranch?.() ?? [];
        for (const e of sessionEvents) {
            if (!isRecord(e)) {
                continue;
            }

            // Check for thinking level change entries
            if (e.type === "thinking_level_change" && typeof e.thinkingLevel === "string") {
                thinkingLevelFromSession = e.thinkingLevel;
            }

            if (e.type !== "message" || !isSessionAssistantMessage(e.message)) {
                continue;
            }

            const m = e.message;
            if (m.stopReason === "error" || m.stopReason === "aborted") {
                continue;
            }
            input += m.usage.input;
            output += m.usage.output;
            cacheRead += m.usage.cacheRead;
            cacheWrite += m.usage.cacheWrite;
            cost += m.usage.cost.total;
            if (getUsageTokenTotal(m.usage) > 0) {
                lastAssistant = m;
            }
        }

        // Calculate context percentage.
        const latestUsage = isStreaming
            ? (liveAssistantUsage ?? lastAssistant?.usage)
            : lastAssistant?.usage;
        const coreContextUsage =
            isStreaming && liveAssistantUsage ? null : readCoreContextUsage(ctx);
        const contextTokens =
            coreContextUsage?.contextTokens ?? (latestUsage ? getUsageTokenTotal(latestUsage) : 0);
        const contextWindow = coreContextUsage?.contextWindow ?? ctx.model?.contextWindow ?? 0;
        const contextPercent =
            coreContextUsage?.contextPercent ??
            (contextWindow > 0 ? (contextTokens / contextWindow) * 100 : 0);
        const compactionSettings = ctx.settingsManager?.getCompactionSettings?.();
        const autoCompactEnabled = compactionSettings?.enabled ?? true;
        const reserveTokens =
            typeof compactionSettings?.reserveTokens === "number"
                ? compactionSettings.reserveTokens
                : 16_384;

        // Get git status (cached)
        const gitBranch = footerDataRef?.getGitBranch() ?? null;
        const gitStatus = getGitStatus(gitBranch);
        const extensionStatuses = footerDataRef?.getExtensionStatuses() ?? new Map();
        const customItemsById = new Map(config.customItems.map((item) => [item.id, item]));
        const hiddenExtensionStatusKeys = collectPowerlineHiddenExtensionStatusKeys(
            config.customItems,
        );

        // Check if using OAuth subscription
        const usingSubscription = ctx.model
            ? (ctx.modelRegistry?.isUsingOAuth?.(ctx.model) ?? false)
            : false;

        const thinkingLevel =
            currentThinkingLevel ?? thinkingLevelFromSession ?? getThinkingLevelFn?.() ?? "off";

        return {
            model: ctx.model,
            thinkingLevel,
            sessionId: ctx.sessionManager?.getSessionId?.(),
            usageStats: { input, output, cacheRead, cacheWrite, cost },
            contextTokens,
            contextPercent,
            contextWindow,
            reserveTokens,
            autoCompactEnabled,
            customCompactionEnabled:
                customCompactionEnabled || extensionStatuses.has(CUSTOM_COMPACTION_STATUS_KEY),
            usingSubscription,
            sessionStartTime,
            shellModeActive: false,
            shellRunning: false,
            shellName: null,
            shellCwd: null,
            git: gitStatus,
            extensionStatuses,
            hiddenExtensionStatusKeys,
            customItemsById,
            options: presetDef.segmentOptions ?? {},
            theme,
            colors,
        };
    }

    /**
     * Get cached responsive layout or compute fresh one.
     * The segment context scans session state, so keep it stable across render bursts.
     */
    function getResponsiveLayout(width: number, theme: Theme): ResponsiveLayout {
        const now = Date.now();
        const cacheTtl = isStreaming ? STREAMING_LAYOUT_CACHE_TTL_MS : LAYOUT_CACHE_TTL_MS;

        if (lastLayoutResult && lastLayoutWidth === width) {
            const msSinceInput = now - lastEditorInputAt;
            const typingRecently = msSinceInput < EDITOR_STATUS_DEFER_MS;

            if (
                !forceNextLayoutRecompute &&
                typingRecently &&
                (layoutDirty || now - lastLayoutTimestamp >= cacheTtl)
            ) {
                return lastLayoutResult;
            }

            if (!layoutDirty && now - lastLayoutTimestamp < cacheTtl) {
                return lastLayoutResult;
            }
        }

        const presetDef = getPreset(config.preset);
        const segmentCtx = buildSegmentContext(currentCtx, theme);

        lastLayoutWidth = width;
        lastLayoutResult = computeResponsiveLayout(segmentCtx, presetDef, width);
        lastLayoutTimestamp = now;
        layoutDirty = false;
        forceNextLayoutRecompute = false;

        return lastLayoutResult;
    }

    function renderPowerlineStatusLines(width: number): string[] {
        if (!currentCtx || !footerDataRef) return [];

        const statuses = footerDataRef.getExtensionStatuses();
        if (!statuses || statuses.size === 0) return [];
        const hiddenExtensionStatusKeys = collectPowerlineHiddenExtensionStatusKeys(
            config.customItems,
        );

        const notifications: string[] = [];
        for (const value of getNotificationExtensionStatuses(statuses, hiddenExtensionStatusKeys)) {
            const lineContent = ` ${value}`;
            if (visibleWidth(lineContent) <= width) {
                notifications.push(lineContent);
            }
        }

        return notifications;
    }

    function renderPowerlineTopLines(width: number, theme: Theme): string[] {
        if (!currentCtx) return [];

        const layout = getResponsiveLayout(width, theme);
        return [layout.topContent, layout.modeIndicatorContent].filter(Boolean);
    }

    function renderPowerlineSecondaryLines(width: number, theme: Theme): string[] {
        if (!currentCtx) return [];

        const layout = getResponsiveLayout(width, theme);
        return layout.secondaryContent ? [layout.secondaryContent] : [];
    }

    function renderLastPromptLines(width: number): string[] {
        if (!showLastPrompt || !lastUserPrompt) return [];

        const prefix = ` ${getFgAnsiCode("sep")}↳${ansi.reset} `;
        const availableWidth = width - visibleWidth(prefix);
        if (availableWidth < 10) return [];

        let promptText = lastUserPrompt.replace(/\s+/g, " ").trim();
        if (!promptText) return [];

        promptText = truncateToWidth(promptText, availableWidth, "…");

        const styledPrompt = `${getFgAnsiCode("sep")}${promptText}${ansi.reset}`;
        const line = `${prefix}${styledPrompt}`;
        return [truncateToWidth(line, width, "…")];
    }

    function teardownFixedEditorCompositor(options?: { resetExtendedKeyboardModes?: boolean }) {
        const hadCompositor = fixedEditorCompositor !== null;
        fixedEditorCompositor?.dispose(options);
        if (!hadCompositor && options?.resetExtendedKeyboardModes) {
            try {
                process.stdout.write(emergencyTerminalModeReset());
            } catch {
                // Shutdown cleanup cannot surface useful terminal write failures.
            }
        }
        fixedEditorCompositor = null;
        fixedStatusContainer = null;
        fixedEditorContainer = null;
        fixedWidgetContainerAbove = null;
        fixedWidgetContainerBelow = null;
    }

    function findContainerWithChild(
        tui: any,
        child: any,
    ): { container: any; index: number } | null {
        const children = Array.isArray(tui?.children) ? tui.children : [];
        const index = children.findIndex(
            (candidate: any) =>
                Array.isArray(candidate?.children) && candidate.children.includes(child),
        );
        if (index === -1) return null;

        return { container: children[index], index };
    }

    function installFixedEditorCompositor(ctx: any, tui: any) {
        teardownFixedEditorCompositor();

        if (!ctx.hasUI || !config.fixedEditor) return;
        if (!tui?.terminal || typeof tui.terminal.write !== "function") {
            throw new Error(
                "[powerline-footer] Fixed editor compositor could not find tui.terminal.write()",
            );
        }
        if (!currentEditor) {
            throw new Error(
                "[powerline-footer] Fixed editor compositor expected the custom editor to be installed first",
            );
        }

        const editorContainerMatch = findContainerWithChild(tui, currentEditor);
        if (!editorContainerMatch) {
            throw new Error(
                "[powerline-footer] Fixed editor compositor could not find the editor container in TUI children",
            );
        }

        const tuiChildren = Array.isArray(tui.children) ? tui.children : [];
        fixedEditorContainer = editorContainerMatch.container;
        const statusContainerCandidate = tuiChildren[editorContainerMatch.index - 2] ?? null;
        fixedStatusContainer =
            statusContainerCandidate && typeof statusContainerCandidate.render === "function"
                ? statusContainerCandidate
                : null;
        fixedWidgetContainerAbove = tuiChildren[editorContainerMatch.index - 1] ?? null;
        fixedWidgetContainerBelow = tuiChildren[editorContainerMatch.index + 1] ?? null;

        let compositor: TerminalSplitCompositor;
        compositor = new TerminalSplitCompositor({
            tui,
            terminal: tui.terminal,
            mouseScroll: config.mouseScroll,
            keyboardScrollShortcuts: {
                up: resolvedShortcuts.scrollChatUp,
                down: resolvedShortcuts.scrollChatDown,
            },
            onCopySelection: (text) => copyTextToClipboard(ctx, text),
            getShowHardwareCursor: () =>
                typeof tui.getShowHardwareCursor === "function" && tui.getShowHardwareCursor(),
            renderCluster: (width, terminalRows) => {
                const theme = currentCtx?.ui?.theme ?? ctx.ui.theme;
                const statusContainerLines = fixedStatusContainer
                    ? compositor
                          .renderHidden(fixedStatusContainer, width)
                          .filter((line) => visibleWidth(line) > 0)
                    : [];
                const aboveWidgetLines = fixedWidgetContainerAbove
                    ? compositor.renderHidden(fixedWidgetContainerAbove, width)
                    : [];
                const belowWidgetLines = fixedWidgetContainerBelow
                    ? compositor.renderHidden(fixedWidgetContainerBelow, width)
                    : [];
                return renderFixedEditorCluster({
                    width,
                    terminalRows,
                    statusLines: [
                        ...aboveWidgetLines,
                        ...renderPowerlineStatusLines(width),
                        ...statusContainerLines,
                    ],
                    editorLines: fixedEditorContainer
                        ? compositor.renderHidden(fixedEditorContainer, width)
                        : [],
                    promptFooterLines: renderPowerlineTopLines(width, theme),
                    secondaryLines: [
                        ...renderPowerlineSecondaryLines(width, theme),
                        ...belowWidgetLines,
                    ],
                    transcriptLines: [],
                    lastPromptLines: renderLastPromptLines(width),
                });
            },
        });

        fixedEditorCompositor = compositor;
        if (fixedStatusContainer?.render) compositor.hideRenderable(fixedStatusContainer);
        if (fixedWidgetContainerAbove?.render) compositor.hideRenderable(fixedWidgetContainerAbove);
        compositor.hideRenderable(fixedEditorContainer);
        if (fixedWidgetContainerBelow?.render) compositor.hideRenderable(fixedWidgetContainerBelow);
        compositor.install();
        tui.requestRender(true);
    }

    function isChatMessageComponentForRole(component: unknown, role: ChatJumpRole): boolean {
        const componentName =
            typeof component === "object" && component !== null
                ? component.constructor?.name
                : undefined;
        if (role === "assistant") {
            return componentName === "AssistantMessageComponent";
        }

        return (
            componentName === "UserMessageComponent" ||
            componentName === "SkillInvocationMessageComponent"
        );
    }

    function renderLineCount(component: unknown, width: number): number {
        if (typeof component !== "object" || component === null) return 0;

        const render = Reflect.get(component, "render");
        if (typeof render !== "function") return 0;

        const lines = render.call(component, width);
        return Array.isArray(lines) ? lines.length : 0;
    }

    function collectMessageStartLines(
        component: unknown,
        width: number,
        role: ChatJumpRole,
        offset: number,
    ): {
        targets: number[];
        lineCount: number;
    } {
        const lineCount = renderLineCount(component, width);
        if (isChatMessageComponentForRole(component, role)) {
            return { targets: [offset], lineCount };
        }

        const children =
            typeof component === "object" && component !== null
                ? Reflect.get(component, "children")
                : null;
        if (!Array.isArray(children) || children.length === 0) {
            return { targets: [], lineCount };
        }

        const targets: number[] = [];
        let childOffset = offset;
        let childrenLineCount = 0;
        for (const child of children) {
            const result = collectMessageStartLines(child, width, role, childOffset);
            targets.push(...result.targets);
            childOffset += result.lineCount;
            childrenLineCount += result.lineCount;
        }

        return { targets, lineCount: Math.max(lineCount, childrenLineCount) };
    }

    function collectChatMessageStartLines(role: ChatJumpRole): number[] {
        const children = Array.isArray(tuiRef?.children) ? tuiRef.children : [];
        const width = Math.max(1, tuiRef?.terminal?.columns ?? 80);
        const targets: number[] = [];
        let offset = 0;

        for (const child of children) {
            const result = collectMessageStartLines(child, width, role, offset);
            targets.push(...result.targets);
            offset += result.lineCount;
        }

        return [...new Set(targets)].sort((a, b) => a - b);
    }

    function jumpToChatMessage(ctx: any, role: ChatJumpRole, direction: ChatJumpDirection): void {
        if (!fixedEditorCompositor) {
            ctx.ui.notify("Chat message jumps require /powerline fixed-editor on", "warning");
            return;
        }

        const targets = collectChatMessageStartLines(role);
        const label = role === "assistant" ? "LLM" : "user";
        if (targets.length === 0) {
            ctx.ui.notify(`No ${label} messages found`, "info");
            return;
        }

        const jumped =
            direction === "previous"
                ? fixedEditorCompositor.jumpToPreviousRootTarget(targets)
                : fixedEditorCompositor.jumpToNextRootTarget(targets);
        if (!jumped) {
            ctx.ui.notify(`No ${direction} ${label} message`, "info");
        }
    }

    function jumpToLastChatMessage(ctx: any, role: ChatJumpRole): void {
        if (!fixedEditorCompositor) {
            ctx.ui.notify("Chat message jumps require /powerline fixed-editor on", "warning");
            return;
        }

        const targets = collectChatMessageStartLines(role);
        const label = role === "assistant" ? "LLM" : "user";
        const target = targets[targets.length - 1];
        if (target === undefined) {
            ctx.ui.notify(`No ${label} messages found`, "info");
            return;
        }

        fixedEditorCompositor.jumpToRootLine(target);
    }

    function jumpChatToBottom(ctx: any): void {
        if (!fixedEditorCompositor) {
            ctx.ui.notify("Chat bottom jump requires /powerline fixed-editor on", "warning");
            return;
        }

        fixedEditorCompositor.jumpToRootBottom();
    }

    function followSubmittedEditorToBottom(): void {
        fixedEditorCompositor?.jumpToRootBottom();
    }

    function installPowerlineWidgets(ctx: any) {
        ctx.ui.setWidget(
            "powerline-status",
            () => ({
                dispose() {},
                invalidate() {
                    requestStatusRender();
                },
                render(width: number): string[] {
                    return renderPowerlineStatusLines(width);
                },
            }),
            { placement: "aboveEditor" },
        );

        // Non-fixed mode can only use Pi's shared below-editor widget stack;
        // fixed-editor mode owns ordering and keeps this block sticky under the prompt.
        ctx.ui.setWidget(
            "powerline-top",
            (_tui: any, theme: Theme) => ({
                dispose() {},
                invalidate() {
                    resetLayoutCache();
                },
                render(width: number): string[] {
                    return renderPowerlineTopLines(width, theme);
                },
            }),
            { placement: "belowEditor" },
        );

        ctx.ui.setWidget(
            "powerline-secondary",
            (_tui: any, theme: Theme) => ({
                dispose() {},
                invalidate() {
                    resetLayoutCache();
                },
                render(width: number): string[] {
                    return renderPowerlineSecondaryLines(width, theme);
                },
            }),
            { placement: "belowEditor" },
        );

        ctx.ui.setWidget(
            "powerline-last-prompt",
            () => ({
                dispose() {},
                invalidate() {},
                render(width: number): string[] {
                    return renderLastPromptLines(width);
                },
            }),
            { placement: "belowEditor" },
        );
    }

    function setupCustomEditor(ctx: any) {
        snapshotPromptHistory(currentEditor);
        if (!enabled) {
            return;
        }

        shortcutInputUnsubscribe?.();
        shortcutInputUnsubscribe =
            typeof ctx.ui.onTerminalInput === "function"
                ? ctx.ui.onTerminalInput((data: string) => {
                      if (!enabled || !ctx.hasUI || tuiRef?.hasOverlay?.()) {
                          return undefined;
                      }

                      const powerlineShortcutAction = getPowerlineShortcutAction(data);
                      if (!powerlineShortcutAction) {
                          return undefined;
                      }

                      runPowerlineShortcut(ctx, powerlineShortcutAction);
                      tuiRef?.requestRender();
                      return { consume: true };
                  })
                : null;

        teardownFixedEditorCompositor();
        ctx.ui.setWidget("powerline-top", undefined);
        ctx.ui.setWidget("powerline-secondary", undefined);
        ctx.ui.setWidget("powerline-status", undefined);
        ctx.ui.setWidget("powerline-last-prompt", undefined);

        let autocompleteFixed = false;

        const editorFactory = (tui: any, editorTheme: any, keybindings: any) => {
            const editor = new OneOffShellEditor(tui, editorTheme, keybindings, {
                keybindings,
                onEditorSubmit: () => followSubmittedEditorToBottom(),
                editorBoundaryShortcuts: {
                    start: resolvedShortcuts.editorStart,
                    end: resolvedShortcuts.editorEnd,
                },
                resolveGhostSuggestion: async (text, signal) => {
                    const oneOffBash = getOneOffBashCommandContext(text);
                    if (oneOffBash) {
                        const ghost = await bashCompletionEngine.getGhostSuggestion(
                            oneOffBash.command,
                            getShellCwd(),
                            getShellPath(),
                            signal,
                        );
                        return ghost
                            ? { ...ghost, value: `${oneOffBash.prefix}${ghost.value}` }
                            : null;
                    }

                    return null;
                },
            });

            const getInstalledAutocompleteProvider = (): AutocompleteProvider | undefined => {
                const candidate = Reflect.get(editor, "autocompleteProvider");
                if (!candidate || typeof candidate !== "object") {
                    return undefined;
                }
                if (typeof Reflect.get(candidate, "getSuggestions") !== "function") {
                    return undefined;
                }
                if (typeof Reflect.get(candidate, "applyCompletion") !== "function") {
                    return undefined;
                }
                return candidate;
            };

            const attachAutocompleteProvider = (): boolean => {
                if (editor.hasWrappedProvider()) return true;
                const defaultProvider = getInstalledAutocompleteProvider();
                if (!defaultProvider) return false;

                const oneOffBashProvider = new OneOffBashAutocompleteProvider();
                editor.installAutocompleteProvider(
                    new OneOffAwareAutocompleteProvider(defaultProvider, oneOffBashProvider),
                );
                return true;
            };

            let inheritedOnSubmit: unknown;
            Object.defineProperty(editor, "onSubmit", {
                configurable: true,
                get: () => inheritedOnSubmit,
                set(handler: unknown) {
                    inheritedOnSubmit =
                        typeof handler === "function"
                            ? (text: string) => {
                                  followSubmittedEditorToBottom();
                                  handler(text);
                              }
                            : handler;
                },
            });

            currentEditor = editor;
            trackPromptHistory(editor);
            restorePromptHistory(editor);
            attachAutocompleteProvider();

            const originalHandleInput = editor.handleInput.bind(editor);
            editor.handleInput = (data: string) => {
                lastEditorInputAt = Date.now();

                const powerlineShortcutAction = getPowerlineShortcutAction(data);
                if (powerlineShortcutAction) {
                    runPowerlineShortcut(ctx, powerlineShortcutAction);
                    return;
                }

                if (!autocompleteFixed && !getInstalledAutocompleteProvider()) {
                    autocompleteFixed = true;
                    snapshotPromptHistory(editor);
                    ctx.ui.setEditorComponent(editorFactory);
                    if (config.fixedEditor) {
                        installFixedEditorCompositor(ctx, tui);
                    }
                    currentEditor?.handleInput(data);
                    return;
                }

                attachAutocompleteProvider();
                const followUpText = keybindings.matches(data, "app.message.followUp")
                    ? getCurrentEditorText(ctx, editor)
                    : "";
                originalHandleInput(data);
                if (
                    hasNonWhitespaceText(followUpText) &&
                    !hasNonWhitespaceText(getCurrentEditorText(ctx, editor))
                ) {
                    followSubmittedEditorToBottom();
                }
            };

            const originalRender = editor.render.bind(editor);
            editor.render = (width: number): string[] => {
                if (width < 10) {
                    return originalRender(width);
                }

                const oneOffBash = getOneOffBashCommandContext(getCurrentEditorText(ctx, editor));
                const borderAnsi =
                    oneOffBash?.prefix === "!!"
                        ? ansi.getFgAnsi(203, 166, 247)
                        : oneOffBash
                          ? ansi.getFgAnsi(243, 139, 168)
                          : getFgAnsiCode("sep");
                const bc = (s: string) => `${borderAnsi}${s}${ansi.reset}`;
                const promptGlyph = oneOffBash ? "$" : "❯";
                const prompt = `${ansi.getFgAnsi(200, 200, 200)}${promptGlyph}${ansi.reset}`;
                const promptPrefix = ` ${prompt} `;
                const contPrefix = "   ";
                const contentWidth = Math.max(1, width - 3);
                const lines = originalRender(contentWidth);

                if (lines.length === 0) return lines;

                let bottomBorderIndex = lines.length - 1;
                for (let i = lines.length - 1; i >= 1; i--) {
                    const stripped = lines[i]?.replace(/\x1b\[[0-9;]*m/g, "") || "";
                    if (stripped.length > 0 && /^─{3,}/.test(stripped)) {
                        bottomBorderIndex = i;
                        break;
                    }
                }

                const result: string[] = [];
                result.push(" " + bc("─".repeat(width - 2)));

                for (let i = 1; i < bottomBorderIndex; i++) {
                    const prefix = i === 1 ? promptPrefix : contPrefix;
                    result.push(`${prefix}${lines[i] || ""}`);
                }

                if (bottomBorderIndex === 1) {
                    result.push(`${promptPrefix}${" ".repeat(contentWidth)}`);
                }

                result.push(" " + bc("─".repeat(width - 2)));

                for (let i = bottomBorderIndex + 1; i < lines.length; i++) {
                    result.push(lines[i] || "");
                }

                return result;
            };

            return editor;
        };

        ctx.ui.setEditorComponent(editorFactory);

        ctx.ui.setFooter((tui: any, _theme: Theme, footerData: ReadonlyFooterDataProvider) => {
            footerDataRef = footerData;
            tuiRef = tui;
            installFooterStatusRepaintHook(footerData);
            const unsub = footerData.onBranchChange(() => requestStatusRender());

            return {
                dispose() {
                    unsub();
                    restoreFooterStatusRepaintHook?.();
                    restoreFooterStatusRepaintHook = null;
                },
                invalidate() {
                    requestStatusRender();
                },
                render(): string[] {
                    return [];
                },
            };
        });

        if (config.fixedEditor) {
            if (tuiRef) {
                installFixedEditorCompositor(ctx, tuiRef);
            }
        } else {
            installPowerlineWidgets(ctx);
        }
    }
}
