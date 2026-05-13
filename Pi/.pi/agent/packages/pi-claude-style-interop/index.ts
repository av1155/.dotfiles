// @ts-nocheck
import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join, relative } from "node:path";

const WORKED_DURATION_KEY = "_piClaudeStyleWorkedDurationMs";
const WORKED_DURATION_MARKER = "Worked for";
const WORKED_LINE_RE = /^✻ Worked for [^\r\n]+$/;
const ANSI_RE = /\x1b(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~]|\][^\x07]*(?:\x07|\x1b\\))/g;
const WRAP_MARK_RE = /\uE000/g;
const RENDER_PATCH_FLAG = Symbol.for("pi-claude-style-interop:final-duration-row-patch");
const TOOL_RENDER_PATCH_FLAG = Symbol.for("pi-claude-style-interop:direct-mcp-tool-render-patch");
const RENDER_PATCH_VERSION = 1;
const TOOL_RENDER_PATCH_VERSION = 7;
const SETTINGS_CACHE_TTL_MS = 5_000;
const CORE_TOOL_NAMES = new Set(["read", "bash", "edit", "write", "grep", "find", "ls"]);

// Tools with explicit handling in pi-claude-style-tools 1.0.25. Keep this
// centralized so future package updates only need this inventory adjusted.
const CLAUDE_STYLE_HANDLED_TOOL_NAMES = new Set([
    "apply_patch",
    "mcp",
    "webfetch",
    "question",
    "questionnaire",
    "context_tag",
    "context_log",
    "context_checkout",
    "annotate",
    "web_search",
    "code_search",
    "fetch_content",
    "get_search_content",
    "alpha_search",
    "alpha_get_paper",
    "alpha_ask_paper",
    "alpha_annotate_paper",
    "alpha_list_annotations",
    "alpha_read_code",
    "Skill",
    "EnterPlanMode",
    "ExitPlanMode",
    "Agent",
    "get_subagent_result",
    "steer_subagent",
    "TaskCreate",
    "TaskList",
    "TaskGet",
    "TaskUpdate",
    "TaskOutput",
    "TaskStop",
    "TaskExecute",
]);
const SPLIT_CONTEXT_TOKENS = new Set([
    "definition",
    "references",
    "hover",
    "signaturehelp",
    "documentsymbol",
    "workspacesymbol",
    "codeaction",
    "rename",
    "implementation",
    "preparecallhierarchy",
    "incomingcalls",
    "outgoingcalls",
    "workspacediagnostics",
    "javascript",
    "typescript",
    "tsx",
    "python",
    "shell",
    "bash",
    "json",
    "yaml",
    "html",
    "css",
    "go",
    "rust",
    "java",
    "c",
    "cpp",
    "ruby",
    "php",
    "swift",
    "kotlin",
    "dart",
    "sql",
]);

interface ExtensionAPI {
    on(event: "message_end", handler: (event: MessageEndEvent) => Promise<void> | void): void;
    on(
        event: "session_start" | "turn_start",
        handler: (event?: unknown, ctx?: unknown) => Promise<void> | void,
    ): void;
}

interface MessageEndEvent {
    message?: unknown;
}

type AssistantTextBlock = {
    type: "text";
    text: string;
    [key: string]: unknown;
};

type AssistantMessage = {
    role?: unknown;
    stopReason?: unknown;
    content?: unknown;
    [WORKED_DURATION_KEY]?: unknown;
};

type UpdateContentFunction = (this: unknown, message: unknown) => void;

type AssistantMessageComponentCtor = {
    prototype: {
        updateContent?: UpdateContentFunction;
        [key: symbol]: unknown;
    };
};

type ToolRendererFunction = (...args: unknown[]) => unknown;
type GetToolRendererFunction = (this: unknown) => ToolRendererFunction | undefined;
type GetRenderContextFunction = (this: unknown, lastComponent: unknown) => ToolRenderContext;

type ToolExecutionComponentCtor = {
    prototype: {
        getCallRenderer?: GetToolRendererFunction;
        getResultRenderer?: GetToolRendererFunction;
        getRenderContext?: GetRenderContextFunction;
        [key: symbol]: unknown;
    };
};

type RenderPatchMeta = {
    wrapped?: UpdateContentFunction;
    version?: number;
};

type ToolRenderPatchMeta = {
    getCallRenderer?: GetToolRendererFunction;
    getResultRenderer?: GetToolRendererFunction;
    getRenderContext?: GetRenderContextFunction;
    originalGetCallRenderer?: GetToolRendererFunction;
    originalGetResultRenderer?: GetToolRendererFunction;
    originalGetRenderContext?: GetRenderContextFunction;
    version?: number;
};

type RenderTheme = {
    fg?: (name: string, text: string) => string;
    bold?: (text: string) => string;
};

type ToolRenderContext = {
    args?: unknown;
    state?: Record<string, unknown>;
    cwd?: string;
    toolCallId?: string;
    invalidate?: () => void;
    executionStarted?: boolean;
    argsComplete?: boolean;
    isPartial?: boolean;
    expanded?: boolean;
    isError?: boolean;
    lastComponent?: unknown;
};

type ToolRenderResultOptions = {
    expanded?: boolean;
    isPartial?: boolean;
};

type DirectMcpIdentity = {
    server?: string;
    tool?: string;
};

type InteropSettings = {
    mcpOutputMode?: "hidden" | "summary" | "preview";
    previewLines?: number;
    expandedPreviewMaxLines?: number;
};

let settingsCache: { value: InteropSettings; timestamp: number } | null = null;

function isRecord(value: unknown): value is Record<string | symbol, unknown> {
    return typeof value === "object" && value !== null;
}

function isTextBlock(value: unknown): value is AssistantTextBlock {
    return isRecord(value) && value.type === "text" && typeof value.text === "string";
}

function getStringProperty(value: unknown, key: string): string | null {
    return isRecord(value) && typeof value[key] === "string" ? value[key] : null;
}

function getRecordProperty(value: unknown, key: string): Record<string | symbol, unknown> | null {
    const property = isRecord(value) ? value[key] : undefined;
    return isRecord(property) ? property : null;
}

export function stripAnsi(text: string): string {
    return text.replace(ANSI_RE, "");
}

function stripControlSequences(text: string): string {
    return stripAnsi(text).replace(WRAP_MARK_RE, "");
}

function visibleWidth(text: string): number {
    return Array.from(stripControlSequences(text)).length;
}

function padToWidth(text: string, width: number): string {
    const padding = Math.max(0, width - visibleWidth(text));
    return `${text}${" ".repeat(padding)}`;
}

function truncatePlain(text: string, maxWidth: number): string {
    if (maxWidth <= 0) {
        return "";
    }
    if (visibleWidth(text) <= maxWidth) {
        return text;
    }
    const plain = stripControlSequences(text);
    if (maxWidth === 1) {
        return "…";
    }
    return `${Array.from(plain)
        .slice(0, maxWidth - 1)
        .join("")}…`;
}

function renderPlainLine(line: string, width: number): string {
    const normalized = line.replace(/\t/g, "   ");
    const fitted = visibleWidth(normalized) > width ? truncatePlain(normalized, width) : normalized;
    return padToWidth(fitted, width);
}

class InteropTextComponent {
    private value = "";
    private cachedValue?: string;
    private cachedWidth?: number;
    private cachedLines?: string[];

    constructor(text = "") {
        this.value = text;
    }

    setText(text: string): void {
        if (this.value === text) {
            return;
        }
        this.value = text;
        this.invalidate();
    }

    invalidate(): void {
        this.cachedValue = undefined;
        this.cachedWidth = undefined;
        this.cachedLines = undefined;
    }

    render(width: number): string[] {
        const safeWidth = Math.max(1, Math.floor(width));
        if (this.cachedLines && this.cachedValue === this.value && this.cachedWidth === safeWidth) {
            return this.cachedLines;
        }

        if (!this.value || this.value.trim() === "") {
            this.cachedValue = this.value;
            this.cachedWidth = safeWidth;
            this.cachedLines = [];
            return this.cachedLines;
        }

        const lines = this.value.split(/\r?\n/).map((line) => renderPlainLine(line, safeWidth));
        this.cachedValue = this.value;
        this.cachedWidth = safeWidth;
        this.cachedLines = lines;
        return lines;
    }
}

function makeText(lastComponent: unknown, text: string): InteropTextComponent {
    const component =
        lastComponent instanceof InteropTextComponent ? lastComponent : new InteropTextComponent();
    component.setText(text);
    return component;
}

export function isWorkedDurationLine(line: string): boolean {
    return line.includes(WORKED_DURATION_MARKER) && WORKED_LINE_RE.test(stripAnsi(line).trim());
}

export function stripWorkedDurationLinesFromText(text: string): string {
    if (!text.includes(WORKED_DURATION_MARKER)) {
        return text;
    }

    return text
        .split(/\r?\n/)
        .filter((line) => !isWorkedDurationLine(line))
        .join("\n")
        .replace(/\n{3,}/g, "\n\n");
}

function hasFinalWorkedDuration(message: unknown): boolean {
    return isRecord(message) && typeof message[WORKED_DURATION_KEY] === "number";
}

function getContentChildren(component: unknown): unknown[] | null {
    if (!isRecord(component)) {
        return null;
    }

    const contentContainer = component.contentContainer;
    if (!isRecord(contentContainer) || !Array.isArray(contentContainer.children)) {
        return null;
    }

    return contentContainer.children;
}

function isSingleLineSpacerComponent(value: unknown): boolean {
    return isRecord(value) && value.lines === 1;
}

function isWorkedDurationTextComponent(value: unknown): boolean {
    return isRecord(value) && typeof value.text === "string" && isWorkedDurationLine(value.text);
}

export function removeTrailingLiveWorkedDurationRow(component: unknown, message: unknown): boolean {
    if (!isRecord(message) || message.role !== "assistant" || hasFinalWorkedDuration(message)) {
        return false;
    }

    const children = getContentChildren(component);
    if (!children || children.length === 0) {
        return false;
    }

    const lastChild = children[children.length - 1];
    if (!isWorkedDurationTextComponent(lastChild)) {
        return false;
    }

    children.pop();
    if (isSingleLineSpacerComponent(children[children.length - 1])) {
        children.pop();
    }

    return true;
}

export function installFinalDurationRowPatch(
    AssistantMessageComponent: AssistantMessageComponentCtor,
): boolean {
    const proto = AssistantMessageComponent.prototype;
    if (typeof proto.updateContent !== "function") {
        return false;
    }

    const meta = proto[RENDER_PATCH_FLAG] as RenderPatchMeta | undefined;
    if (
        isRecord(meta) &&
        meta.wrapped === proto.updateContent &&
        meta.version === RENDER_PATCH_VERSION
    ) {
        return false;
    }

    const originalUpdateContent = proto.updateContent;
    const wrapped: UpdateContentFunction = function patchedFinalDurationRow(
        message: unknown,
    ): void {
        originalUpdateContent.call(this, message);
        removeTrailingLiveWorkedDurationRow(this, message);
    };

    proto.updateContent = wrapped;
    proto[RENDER_PATCH_FLAG] = { wrapped, version: RENDER_PATCH_VERSION } satisfies RenderPatchMeta;
    return true;
}

function themeFg(theme: RenderTheme, key: string, text: string): string {
    try {
        if (typeof theme?.fg === "function") {
            return theme.fg(key, text);
        }
    } catch {
        // Fall through to plain text.
    }
    return text;
}

function themeBold(theme: RenderTheme, text: string): string {
    try {
        if (typeof theme?.bold === "function") {
            return theme.bold(text);
        }
    } catch {
        // Fall through to plain text.
    }
    return text;
}

function toolIdentityText(theme: RenderTheme, text: string): string {
    return themeFg(theme, "toolTitle", themeBold(theme, text));
}

function toolContextText(theme: RenderTheme, text: string): string {
    return themeFg(theme, "accent", text);
}

function toolDetailText(theme: RenderTheme, text: string): string {
    return themeFg(theme, "muted", text);
}

function readJsonFile(path: string): Record<string, unknown> | null {
    try {
        if (!path || !existsSync(path)) {
            return null;
        }
        const parsed = JSON.parse(readFileSync(path, "utf8"));
        return isRecord(parsed) ? parsed : null;
    } catch {
        return null;
    }
}

function settingsPaths(): string[] {
    const paths = [join(process.cwd(), ".pi", "settings.json")];
    const agentDir = process.env.PI_CODING_AGENT_DIR;
    if (agentDir) {
        paths.push(join(agentDir, "settings.json"));
    }
    paths.push(join(homedir(), ".pi", "agent", "settings.json"));
    paths.push(join(homedir(), ".pi", "settings.json"));
    return [...new Set(paths)];
}

function readSettings(): InteropSettings {
    const now = Date.now();
    if (settingsCache && now - settingsCache.timestamp < SETTINGS_CACHE_TTL_MS) {
        return settingsCache.value;
    }

    for (const path of settingsPaths()) {
        const json = readJsonFile(path);
        if (!json) {
            continue;
        }
        const value: InteropSettings = {
            mcpOutputMode:
                json.mcpOutputMode === "hidden" ||
                json.mcpOutputMode === "summary" ||
                json.mcpOutputMode === "preview"
                    ? json.mcpOutputMode
                    : undefined,
            previewLines: typeof json.previewLines === "number" ? json.previewLines : undefined,
            expandedPreviewMaxLines:
                typeof json.expandedPreviewMaxLines === "number"
                    ? json.expandedPreviewMaxLines
                    : undefined,
        };
        settingsCache = { value, timestamp: now };
        return value;
    }

    const value: InteropSettings = {};
    settingsCache = { value, timestamp: now };
    return value;
}

function positiveInteger(value: unknown, fallback: number): number {
    if (typeof value !== "number" || !Number.isFinite(value) || value <= 0) {
        return fallback;
    }
    return Math.floor(value);
}

function mcpOutputMode(): "hidden" | "summary" | "preview" {
    return readSettings().mcpOutputMode ?? "preview";
}

function previewLimit(): number {
    return positiveInteger(readSettings().previewLines, 8);
}

function expandedPreviewLimit(): number {
    return positiveInteger(readSettings().expandedPreviewMaxLines, 4000);
}

function getToolName(component: unknown): string {
    return getStringProperty(component, "toolName") ?? "";
}

function getToolDefinition(component: unknown): Record<string | symbol, unknown> | null {
    return getRecordProperty(component, "toolDefinition");
}

function getToolDefinitionLabel(component: unknown): string {
    return getStringProperty(getToolDefinition(component), "label") ?? "";
}

function getToolLabel(component: unknown): string {
    const label = getToolDefinitionLabel(component).trim();
    if (label && !/^MCP:\s*/i.test(label)) {
        return label;
    }
    return humanizeToolName(getToolName(component));
}

function getDefinitionRenderer(
    component: unknown,
    key: "renderCall" | "renderResult",
): ToolRendererFunction | undefined {
    const definition = getToolDefinition(component);
    const renderer = definition?.[key];
    return typeof renderer === "function" ? (renderer as ToolRendererFunction) : undefined;
}

function isClaudeStyleHandledTool(toolName: string): boolean {
    return CORE_TOOL_NAMES.has(toolName) || CLAUDE_STYLE_HANDLED_TOOL_NAMES.has(toolName);
}

function getBuiltInToolDefinition(component: unknown): Record<string | symbol, unknown> | null {
    return getRecordProperty(component, "builtInToolDefinition");
}

function hasOnlyCustomDefinition(component: unknown): boolean {
    return getToolDefinition(component) !== null && getBuiltInToolDefinition(component) === null;
}

function getDirectMcpToolFromLabel(component: unknown): string | undefined {
    const label = getToolDefinitionLabel(component).trim();
    const match = label.match(/^MCP:\s*(.+)$/i);
    return match?.[1]?.trim() || undefined;
}

function directMcpIdentityFromDetails(result: unknown): DirectMcpIdentity | null {
    const details = getRecordProperty(result, "details");
    if (!details) {
        return null;
    }
    const server = getStringProperty(details, "server") ?? undefined;
    const tool = getStringProperty(details, "tool") ?? undefined;
    return server || tool ? { server, tool } : null;
}

function inferServerFromToolName(
    toolName: string,
    originalTool: string | undefined,
): string | undefined {
    if (!toolName || !originalTool) {
        return undefined;
    }

    const suffix = `_${originalTool}`;
    if (!toolName.endsWith(suffix)) {
        return undefined;
    }

    const prefix = toolName.slice(0, -suffix.length);
    return prefix ? prefix.replace(/_/g, "-") : undefined;
}

function getDirectMcpIdentity(component: unknown, result?: unknown): DirectMcpIdentity | null {
    const toolName = getToolName(component);
    if (!toolName || toolName === "mcp" || CORE_TOOL_NAMES.has(toolName)) {
        return null;
    }

    const labelTool = getDirectMcpToolFromLabel(component);
    const details = directMcpIdentityFromDetails(result ?? getRecordProperty(component, "result"));
    if (!labelTool && !details) {
        return null;
    }

    const tool = details?.tool ?? labelTool;
    const server = details?.server ?? inferServerFromToolName(toolName, tool);
    return { server, tool };
}

function isDirectMcpTool(component: unknown, result?: unknown): boolean {
    return getDirectMcpIdentity(component, result) !== null;
}

function humanizeToolName(name: string): string {
    if (!name) {
        return "Tool";
    }
    return name
        .replace(/([a-z0-9])([A-Z])/g, "$1 $2")
        .replace(/[_:-]+/g, " ")
        .replace(/\b\w/g, (char) => char.toUpperCase());
}

function normalizedComparable(text: string): string {
    return stripControlSequences(text)
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, "")
        .trim();
}

function summarizeText(text: string, maxWidth: number): string {
    const normalized = stripControlSequences(text).replace(/\s+/g, " ").trim();
    if (!normalized) {
        return "";
    }
    return visibleWidth(normalized) > maxWidth ? truncatePlain(normalized, maxWidth) : normalized;
}

function getStringArg(args: unknown, ...keys: string[]): string {
    if (!isRecord(args)) {
        return "";
    }
    for (const key of keys) {
        const value = args[key];
        if (typeof value === "string" && value.trim()) {
            return value.trim();
        }
    }
    return "";
}

function shortPath(cwd: string | undefined, filePath: string): string {
    if (!filePath) {
        return "";
    }
    if (!filePath.startsWith("/") || !cwd) {
        return filePath;
    }
    try {
        const rel = relative(cwd, filePath);
        if (rel && !rel.startsWith("..") && !rel.startsWith("/")) {
            return rel;
        }
    } catch {
        // Fall through to home-shortened path.
    }
    const home = homedir();
    return home && filePath.startsWith(home) ? filePath.replace(home, "~") : filePath;
}

function isContextModeIdentity(identity: DirectMcpIdentity): boolean {
    return identity.server === "context-mode" || identity.tool?.startsWith("ctx_") === true;
}

function summarizeDirectMcpArgs(
    identity: DirectMcpIdentity,
    args: unknown,
    ctx: ToolRenderContext,
): string {
    if (isContextModeIdentity(identity)) {
        const parts: string[] = [];
        const language = getStringArg(args, "language");
        const path = getStringArg(args, "path");
        const intent = getStringArg(args, "intent");
        if (language) {
            parts.push(language);
        }
        if (path) {
            parts.push(shortPath(ctx.cwd, path));
        } else if (intent) {
            parts.push(summarizeText(intent, 56));
        }
        return parts.join(" ");
    }

    const value = getStringArg(
        args,
        "path",
        "file_path",
        "url",
        "query",
        "name",
        "subject",
        "operation",
        "action",
        "intent",
        "prompt",
    );
    return value ? summarizeText(value, 72) : "";
}

function getStringArrayArg(args: unknown, ...keys: string[]): string[] {
    if (!isRecord(args)) {
        return [];
    }
    for (const key of keys) {
        const value = args[key];
        if (!Array.isArray(value)) {
            continue;
        }
        return value.filter(
            (item): item is string => typeof item === "string" && item.trim().length > 0,
        );
    }
    return [];
}

function summarizeArray(items: string[], singular: string, plural: string, maxWidth = 48): string {
    if (items.length === 0) {
        return "";
    }
    if (items.length === 1) {
        return summarizeText(items[0], maxWidth);
    }
    return `${summarizeText(items[0], maxWidth)} (+${items.length - 1} ${items.length === 2 ? singular : plural})`;
}

function summarizeQuestions(args: unknown): string {
    if (!isRecord(args) || !Array.isArray(args.questions)) {
        return "";
    }
    const count = args.questions.length;
    if (count === 0) {
        return "";
    }
    const first = isRecord(args.questions[0])
        ? getStringProperty(args.questions[0], "question")
        : null;
    const suffix = count === 1 ? "" : ` (+${count - 1} questions)`;
    return `${first ? summarizeText(first, 48) : `${count} questions`}${suffix}`;
}

function formatLineLocation(args: unknown): string {
    if (!isRecord(args)) {
        return "";
    }
    const line = typeof args.line === "number" ? args.line : undefined;
    const character = typeof args.character === "number" ? args.character : undefined;
    if (line === undefined) {
        return "";
    }
    return character === undefined ? `:${line}` : `:${line}:${character}`;
}

function summarizeGenericArgs(toolName: string, args: unknown, ctx: ToolRenderContext): string {
    if (toolName === "ask_user_question") {
        return summarizeQuestions(args);
    }

    if (toolName === "lsp_navigation") {
        const operation = getStringArg(args, "operation") || "operation";
        const filePath = getStringArg(args, "filePath", "path");
        const query = getStringArg(args, "query");
        const target = filePath
            ? `${shortPath(ctx.cwd, filePath)}${formatLineLocation(args)}`
            : query;
        return target ? `${operation} ${summarizeText(target, 54)}` : operation;
    }

    if (toolName === "ast_grep_search" || toolName === "ast_grep_replace") {
        const lang = getStringArg(args, "lang", "language");
        const pattern = getStringArg(args, "pattern");
        const paths = summarizeArray(getStringArrayArg(args, "paths"), "path", "paths", 28);
        const parts = [lang, pattern ? summarizeText(pattern, 42) : "", paths].filter(Boolean);
        return parts.join(" ");
    }

    if (toolName === "plannotator_submit_plan") {
        const filePath = getStringArg(args, "filePath", "path");
        return filePath ? shortPath(ctx.cwd, filePath) : "submit plan";
    }

    if (toolName.startsWith("memory_")) {
        return (
            getStringArg(args, "query", "key", "id", "category", "type") ||
            (toolName === "memory_stats" ? "stats" : "")
        );
    }

    const urls = summarizeArray(getStringArrayArg(args, "urls"), "url", "urls");
    if (urls) {
        return urls;
    }

    const paths = summarizeArray(getStringArrayArg(args, "paths"), "path", "paths");
    if (paths) {
        return paths;
    }

    const questions = summarizeQuestions(args);
    if (questions) {
        return questions;
    }

    const value = getStringArg(
        args,
        "operation",
        "action",
        "query",
        "pattern",
        "filePath",
        "path",
        "file_path",
        "url",
        "name",
        "subject",
        "key",
        "id",
        "tool",
        "server",
        "description",
        "intent",
        "prompt",
    );
    if (!value) {
        return "";
    }
    return summarizeText(value, 72);
}

function suppressDuplicateSummary(label: string, toolName: string, summary: string): string {
    if (!summary) {
        return "";
    }
    const normalized = normalizedComparable(summary);
    if (!normalized) {
        return "";
    }
    if (
        normalized === normalizedComparable(label) ||
        normalized === normalizedComparable(toolName)
    ) {
        return "";
    }
    return summary;
}

function splitCallSummary(summary: string): { context: string; detail: string } {
    if (!summary) {
        return { context: "", detail: "" };
    }
    const suffixMatch = summary.match(/^(.+?)\s+(\(\+\d+\s+.+\))$/);
    if (suffixMatch) {
        return { context: suffixMatch[1], detail: suffixMatch[2] };
    }
    const spaceIndex = summary.indexOf(" ");
    if (spaceIndex === -1) {
        return { context: summary, detail: "" };
    }
    const first = summary.slice(0, spaceIndex);
    if (!SPLIT_CONTEXT_TOKENS.has(first.toLowerCase())) {
        return { context: summary, detail: "" };
    }
    return {
        context: first,
        detail: summary.slice(spaceIndex + 1),
    };
}

type BlinkEntry = {
    invalidate: () => void;
    lastSeen: number;
};

const BLINK_INTERVAL_MS = 500;
const BLINK_STALE_MS = 60_000;
const blinkEntries = new Map<unknown, BlinkEntry>();
let blinkTimer: ReturnType<typeof setTimeout> | null = null;
let blinkPhase = false;

function blinkKey(ctx: ToolRenderContext): unknown {
    return ctx.toolCallId ?? ctx.state ?? ctx;
}

function scheduleBlinkTick(): void {
    if (blinkTimer || blinkEntries.size === 0) {
        return;
    }
    blinkTimer = setTimeout(() => {
        blinkTimer = null;
        blinkPhase = !blinkPhase;
        const now = Date.now();
        for (const [key, entry] of blinkEntries) {
            if (now - entry.lastSeen > BLINK_STALE_MS) {
                blinkEntries.delete(key);
                continue;
            }
            entry.invalidate();
        }
        scheduleBlinkTick();
    }, BLINK_INTERVAL_MS);
    (blinkTimer as { unref?: () => void }).unref?.();
}

function trackPendingBlink(ctx: ToolRenderContext): void {
    const invalidate = typeof ctx.invalidate === "function" ? ctx.invalidate : () => {};
    blinkEntries.set(blinkKey(ctx), { invalidate, lastSeen: Date.now() });
    scheduleBlinkTick();
}

function clearPendingBlink(ctx: ToolRenderContext): void {
    blinkEntries.delete(blinkKey(ctx));
}

function statusDot(ctx: ToolRenderContext, theme: RenderTheme): string {
    const pending = !ctx.executionStarted || ctx.isPartial;
    if (pending) {
        trackPendingBlink(ctx);
        return `${themeFg(theme, blinkPhase ? "success" : "muted", blinkPhase ? "●" : "○")} `;
    }

    clearPendingBlink(ctx);
    const color = ctx.isError ? "error" : "success";
    return `${themeFg(theme, color, "●")} `;
}

function renderDirectMcpCall(
    component: unknown,
    args: unknown,
    theme: RenderTheme,
    ctx: ToolRenderContext,
): InteropTextComponent {
    const identity = getDirectMcpIdentity(component, getRecordProperty(component, "result")) ?? {
        tool: getToolName(component),
    };
    const target =
        [identity.server, identity.tool].filter(Boolean).join(":") || getToolName(component);
    const title = toolIdentityText(theme, "MCP");
    const targetText = target ? ` ${toolContextText(theme, target)}` : "";
    const summary = summarizeDirectMcpArgs(identity, args, ctx);
    const summaryText = summary ? ` ${toolDetailText(theme, summary)}` : "";
    return makeText(
        ctx.lastComponent,
        `${statusDot(ctx, theme)}${title}${targetText}${summaryText}`,
    );
}

function renderGenericToolCall(
    component: unknown,
    args: unknown,
    theme: RenderTheme,
    ctx: ToolRenderContext,
): InteropTextComponent {
    const toolName = getToolName(component);
    const label = getToolLabel(component);
    const rawSummary = summarizeGenericArgs(toolName, args, ctx);
    const summary = suppressDuplicateSummary(label, toolName, rawSummary);
    const title = toolIdentityText(theme, label);
    const parts = splitCallSummary(summary);
    const contextText = parts.context ? ` ${toolContextText(theme, parts.context)}` : "";
    const detailText = parts.detail ? ` ${toolDetailText(theme, parts.detail)}` : "";
    return makeText(
        ctx.lastComponent,
        `${statusDot(ctx, theme)}${title}${contextText}${detailText}`,
    );
}

function getResultTextLines(result: unknown): string[] {
    if (!isRecord(result) || !Array.isArray(result.content)) {
        return [];
    }

    const lines: string[] = [];
    for (const block of result.content) {
        if (!isRecord(block)) {
            continue;
        }
        if (block.type === "text" && typeof block.text === "string") {
            lines.push(...block.text.split(/\r?\n/));
            continue;
        }
        if (block.type === "image") {
            const mimeType = typeof block.mimeType === "string" ? block.mimeType : "image";
            lines.push(`[image: ${mimeType}]`);
        }
    }
    return lines;
}

function hasErrorDetails(result: unknown): boolean {
    const details = getRecordProperty(result, "details");
    return details ? details.error !== undefined : false;
}

function branchBlock(text: string, theme: RenderTheme): string {
    if (!text.trim()) {
        return "";
    }
    const lines = text.split("\n");
    const first = `${themeFg(theme, "dim", "└─")} ${lines[0] ?? ""}`;
    const rest = lines.slice(1).map((line) => `   ${line}`);
    return [first, ...rest].join("\n");
}

function buildPreviewText(
    lines: string[],
    maxLines: number,
    theme: RenderTheme,
    isError: boolean,
): string {
    if (lines.length === 0) {
        return themeFg(theme, "muted", "(no output)");
    }

    const shown = lines.slice(0, maxLines);
    const color = isError ? "error" : "toolOutput";
    const preview = shown.map((line) => themeFg(theme, color, line || " "));
    if (lines.length > maxLines) {
        preview.push(themeFg(theme, "warning", `(display capped at ${maxLines} lines)`));
    }
    return preview.join("\n");
}

function renderDirectMcpResult(
    result: unknown,
    options: ToolRenderResultOptions,
    theme: RenderTheme,
    ctx: ToolRenderContext,
): InteropTextComponent {
    if (options.isPartial) {
        return makeText(
            ctx.lastComponent,
            branchBlock(themeFg(theme, "dim", "MCP running..."), theme),
        );
    }

    const mode = mcpOutputMode();
    if (mode === "hidden") {
        return makeText(ctx.lastComponent, "");
    }

    const isError = ctx.isError === true || hasErrorDetails(result);
    const lines = getResultTextLines(result).filter((line, index, all) => {
        return line.length > 0 || index < all.length - 1;
    });

    if (lines.length === 0) {
        const done = isError
            ? themeFg(theme, "error", "Failed")
            : themeFg(theme, "success", "Done");
        return makeText(ctx.lastComponent, branchBlock(done, theme));
    }

    const statusText = isError
        ? themeFg(theme, "error", lines[0] || "Failed")
        : themeFg(theme, "muted", `${lines.length} line${lines.length === 1 ? "" : "s"} returned`);

    if (mode === "summary") {
        return makeText(ctx.lastComponent, branchBlock(statusText, theme));
    }

    const expanded = options.expanded === true || ctx.expanded === true;
    const showPreview = expanded || isError;
    if (!showPreview) {
        return makeText(
            ctx.lastComponent,
            branchBlock(`${statusText}${themeFg(theme, "muted", " • Ctrl+O to expand")}`, theme),
        );
    }

    const maxLines = expanded ? expandedPreviewLimit() : previewLimit();
    const preview = buildPreviewText(lines, maxLines, theme, isError);
    return makeText(ctx.lastComponent, branchBlock(`${statusText}\n${preview}`, theme));
}

function renderGenericToolResult(
    component: unknown,
    result: unknown,
    options: ToolRenderResultOptions,
    theme: RenderTheme,
    ctx: ToolRenderContext,
): InteropTextComponent {
    if (options.isPartial) {
        const label = getToolLabel(component);
        return makeText(
            ctx.lastComponent,
            branchBlock(themeFg(theme, "dim", `${label} running...`), theme),
        );
    }

    const isError = ctx.isError === true || hasErrorDetails(result);
    const lines = getResultTextLines(result).filter((line, index, all) => {
        return line.length > 0 || index < all.length - 1;
    });

    if (lines.length === 0) {
        const done = isError
            ? themeFg(theme, "error", "Failed")
            : themeFg(theme, "success", "Done");
        return makeText(ctx.lastComponent, branchBlock(done, theme));
    }

    const statusText = isError
        ? themeFg(theme, "error", lines[0] || "Failed")
        : themeFg(theme, "muted", `${lines.length} line${lines.length === 1 ? "" : "s"} returned`);

    const expanded = options.expanded === true || ctx.expanded === true;
    if (!expanded && !isError) {
        return makeText(
            ctx.lastComponent,
            branchBlock(`${statusText}${themeFg(theme, "muted", " • Ctrl+O to expand")}`, theme),
        );
    }

    const maxLines = expanded ? expandedPreviewLimit() : previewLimit();
    const preview = buildPreviewText(lines, maxLines, theme, isError);
    return makeText(ctx.lastComponent, branchBlock(`${statusText}\n${preview}`, theme));
}

function callDefinitionRenderer(
    renderer: ToolRendererFunction,
    component: unknown,
    args: unknown[],
): unknown {
    const definition = getToolDefinition(component);
    return renderer.apply(definition ?? component, args);
}

export function installDirectMcpToolRendererPatch(
    ToolExecutionComponent: ToolExecutionComponentCtor,
): boolean {
    const proto = ToolExecutionComponent.prototype;
    if (
        typeof proto.getCallRenderer !== "function" ||
        typeof proto.getResultRenderer !== "function" ||
        typeof proto.getRenderContext !== "function"
    ) {
        return false;
    }

    const meta = proto[TOOL_RENDER_PATCH_FLAG] as ToolRenderPatchMeta | undefined;
    if (
        isRecord(meta) &&
        meta.getCallRenderer === proto.getCallRenderer &&
        meta.getResultRenderer === proto.getResultRenderer &&
        meta.getRenderContext === proto.getRenderContext &&
        meta.version === TOOL_RENDER_PATCH_VERSION
    ) {
        return false;
    }

    const originalGetCallRenderer =
        isRecord(meta) && typeof meta.originalGetCallRenderer === "function"
            ? meta.originalGetCallRenderer
            : proto.getCallRenderer;
    const originalGetResultRenderer =
        isRecord(meta) && typeof meta.originalGetResultRenderer === "function"
            ? meta.originalGetResultRenderer
            : proto.getResultRenderer;
    const originalGetRenderContext =
        isRecord(meta) && typeof meta.originalGetRenderContext === "function"
            ? meta.originalGetRenderContext
            : proto.getRenderContext;

    const getRenderContext: GetRenderContextFunction = function patchedToolRenderContext(
        lastComponent: unknown,
    ): ToolRenderContext {
        const context = originalGetRenderContext.call(this, lastComponent);
        if (isRecord(this) && this.result) {
            const result = this.result;
            const firstLine =
                getResultTextLines(result).find((line) => line.trim().length > 0) ?? "";
            context.executionStarted = true;
            context.isError =
                context.isError === true ||
                (isRecord(result) && result.isError === true) ||
                hasErrorDetails(result) ||
                /^error\b\s*:?/i.test(firstLine.trim());
            if (context.isPartial !== true) {
                context.argsComplete = true;
            }
        }
        return context;
    };

    const getCallRenderer: GetToolRendererFunction = function patchedToolCallRenderer() {
        const previousRenderer = originalGetCallRenderer.call(this);
        const toolName = getToolName(this);
        if (isDirectMcpTool(this, getRecordProperty(this, "result"))) {
            return (args: unknown, theme: RenderTheme, ctx: ToolRenderContext) =>
                renderDirectMcpCall(this, args, theme, ctx);
        }
        if (isClaudeStyleHandledTool(toolName)) {
            return previousRenderer;
        }
        if (!toolName || CORE_TOOL_NAMES.has(toolName)) {
            return previousRenderer;
        }
        return (args: unknown, theme: RenderTheme, ctx: ToolRenderContext) =>
            renderGenericToolCall(this, args, theme, ctx);
    };

    const getResultRenderer: GetToolRendererFunction = function patchedToolResultRenderer() {
        const previousRenderer = originalGetResultRenderer.call(this);
        const toolName = getToolName(this);
        if (isDirectMcpTool(this, getRecordProperty(this, "result"))) {
            return (
                result: unknown,
                options: ToolRenderResultOptions,
                theme: RenderTheme,
                ctx: ToolRenderContext,
            ) => renderDirectMcpResult(result, options, theme, ctx);
        }
        if (isClaudeStyleHandledTool(toolName)) {
            return previousRenderer;
        }
        const definitionRenderer = hasOnlyCustomDefinition(this)
            ? getDefinitionRenderer(this, "renderResult")
            : undefined;
        if (definitionRenderer) {
            return (...args: unknown[]) => callDefinitionRenderer(definitionRenderer, this, args);
        }
        if (!toolName || CORE_TOOL_NAMES.has(toolName)) {
            return previousRenderer;
        }
        return (
            result: unknown,
            options: ToolRenderResultOptions,
            theme: RenderTheme,
            ctx: ToolRenderContext,
        ) => renderGenericToolResult(this, result, options, theme, ctx);
    };

    proto.getCallRenderer = getCallRenderer;
    proto.getResultRenderer = getResultRenderer;
    proto.getRenderContext = getRenderContext;
    proto[TOOL_RENDER_PATCH_FLAG] = {
        getCallRenderer,
        getResultRenderer,
        getRenderContext,
        originalGetCallRenderer,
        originalGetResultRenderer,
        originalGetRenderContext,
        version: TOOL_RENDER_PATCH_VERSION,
    } satisfies ToolRenderPatchMeta;
    return true;
}

let assistantComponentPromise: Promise<AssistantMessageComponentCtor | null> | null = null;
let toolExecutionComponentPromise: Promise<ToolExecutionComponentCtor | null> | null = null;

async function loadAssistantMessageComponent(): Promise<AssistantMessageComponentCtor | null> {
    for (const specifier of ["@mariozechner/pi-coding-agent", "@earendil-works/pi-coding-agent"]) {
        try {
            const module = (await import(specifier)) as {
                AssistantMessageComponent?: AssistantMessageComponentCtor;
            };
            if (module.AssistantMessageComponent?.prototype) {
                return module.AssistantMessageComponent;
            }
        } catch {
            // Try the next package name. Pi has used both names across versions.
        }
    }
    return null;
}

async function loadToolExecutionComponent(): Promise<ToolExecutionComponentCtor | null> {
    for (const specifier of ["@mariozechner/pi-coding-agent", "@earendil-works/pi-coding-agent"]) {
        try {
            const module = (await import(specifier)) as {
                ToolExecutionComponent?: ToolExecutionComponentCtor;
            };
            if (module.ToolExecutionComponent?.prototype) {
                return module.ToolExecutionComponent;
            }
        } catch {
            // Try the next package name. Pi has used both names across versions.
        }
    }
    return null;
}

async function installAssistantDurationPatch(): Promise<void> {
    assistantComponentPromise ??= loadAssistantMessageComponent();
    const AssistantMessageComponent = await assistantComponentPromise;
    if (AssistantMessageComponent) {
        installFinalDurationRowPatch(AssistantMessageComponent);
    }
}

async function installToolRendererPatch(): Promise<void> {
    toolExecutionComponentPromise ??= loadToolExecutionComponent();
    const ToolExecutionComponent = await toolExecutionComponentPromise;
    if (ToolExecutionComponent) {
        installDirectMcpToolRendererPatch(ToolExecutionComponent);
    }
}

async function installRuntimePatches(): Promise<void> {
    await Promise.all([installAssistantDurationPatch(), installToolRendererPatch()]);
}

export function cleanAssistantMessage(message: unknown): boolean {
    if (!isRecord(message) || message.role !== "assistant") {
        return false;
    }

    const assistantMessage = message as AssistantMessage;
    if (assistantMessage.stopReason === "toolUse") {
        return false;
    }

    // Only clean messages produced by pi-claude-style-tools. This keeps the
    // cleanup narrow and preserves the duration metadata that its renderer uses
    // to show the visible presentation row.
    if (typeof assistantMessage[WORKED_DURATION_KEY] !== "number") {
        return false;
    }

    if (!Array.isArray(assistantMessage.content)) {
        return false;
    }

    let changed = false;
    for (const block of assistantMessage.content) {
        if (!isTextBlock(block)) {
            continue;
        }

        const nextText = stripWorkedDurationLinesFromText(block.text);
        if (nextText !== block.text) {
            block.text = nextText;
            changed = true;
        }
    }

    return changed;
}

export default async function piClaudeStyleInterop(pi: ExtensionAPI): Promise<void> {
    await installRuntimePatches();
    pi.on("session_start", installRuntimePatches);
    pi.on("turn_start", installRuntimePatches);
    pi.on("message_end", async (event) => {
        cleanAssistantMessage(event.message);
    });
}
