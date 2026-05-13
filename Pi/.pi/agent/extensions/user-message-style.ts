// @ts-nocheck
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";
import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

interface ExtensionAPI {
    on(
        event: "session_start" | "turn_start",
        handler: (event: unknown, ctx: unknown) => Promise<void> | void,
    ): void;
}

type RenderFunction = (this: unknown, width: number) => string[];
type InvalidateFunction = (this: unknown, ...args: unknown[]) => unknown;
type UserMessageComponentCtor = {
    prototype: {
        render?: RenderFunction;
        invalidate?: InvalidateFunction;
        [key: symbol]: unknown;
    };
};

const PATCH_FLAG = Symbol.for("av:pi-user-message-style-patch");
const PATCH_VERSION = 8;
const STATE_KEY = Symbol.for("av:pi-user-message-style-state");
const RAW_TEXT_CACHE_KEY = Symbol.for("av:pi-user-message-style-raw-text");
const RENDER_CACHE_KEY = Symbol.for("av:pi-user-message-style-render-cache");
const USER_LABEL = " User ";
const USER_LABEL_FG = "\x1b[38;2;215;119;87m"; // #D77757
const RESET = "\x1b[0m";
const DEFAULT_BG = "\x1b[49m";
const SOURCE_BORDER_COLOR = "\x1b[38;5;238m";
const BORDER_FG = "\x1b[38;2;73;77;100m"; // catppuccin-macchiato surface1 (#494d64)
const SEPARATOR_FG = "\x1b[38;2;148;148;148m"; // #949494
const ANSI_RE = /\x1b\[[0-9;?]*[ -/]*[@-~]/g;
const OSC_RE = /\x1b\][^\x07]*(?:\x07|\x1b\\)/g;
const OSC133_ZONE_START = "\x1b]133;A\x07";
const OSC133_ZONE_END = "\x1b]133;B\x07";
const OSC133_ZONE_FINAL = "\x1b]133;C\x07";
const FALLBACK_USER_BG = "#2B2E3F";
const DEFAULT_COLLAPSE_ENABLED = true;
const DEFAULT_COLLAPSE_LINE_THRESHOLD = 40;
const DEFAULT_COLLAPSE_CHAR_THRESHOLD = 6000;
const DEFAULT_COLLAPSE_HEAD_LINES = 110;
const DEFAULT_COLLAPSE_TAIL_LINES = 32;
const MIN_COLLAPSE_THRESHOLD = 1;
const MAX_COLLAPSE_SEGMENT_LINES = 240;

type CollapseSettings = {
    enabled: boolean;
    lineThreshold: number;
    charThreshold: number;
    headLines: number;
    tailLines: number;
};

type PatchState = {
    userLabelFg: string;
    userMessageBg: string;
    collapse: CollapseSettings;
};

type PatchMeta = {
    wrapped?: RenderFunction;
    invalidate?: InvalidateFunction;
    originalRender?: RenderFunction;
    originalInvalidate?: InvalidateFunction;
    version?: number;
};

type RenderMode = "normal" | "collapsed";

type RenderCache = {
    key: string;
    lines: string[];
};

type UnknownRecord = Record<string | symbol, unknown>;

type ThemeJson = {
    vars?: Record<string, string | number>;
    colors?: Record<string, string | number>;
};

function getAgentDir(): string {
    return process.env.PI_CODING_AGENT_DIR ?? join(homedir(), ".pi", "agent");
}

function readJson(path: string): Record<string, unknown> | null {
    try {
        if (!existsSync(path)) return null;
        return JSON.parse(readFileSync(path, "utf8")) as Record<string, unknown>;
    } catch {
        return null;
    }
}

function colorToBgAnsi(value: string | number | undefined): string {
    if (value === undefined || value === "") return DEFAULT_BG;
    if (typeof value === "number" && Number.isFinite(value)) {
        return `\x1b[48;5;${Math.max(0, Math.min(255, Math.floor(value)))}m`;
    }
    if (typeof value !== "string") return DEFAULT_BG;

    const hex = value.trim();
    const match = hex.match(/^#?([0-9a-fA-F]{6})$/);
    if (!match) return DEFAULT_BG;

    const raw = match[1];
    const r = Number.parseInt(raw.slice(0, 2), 16);
    const g = Number.parseInt(raw.slice(2, 4), 16);
    const b = Number.parseInt(raw.slice(4, 6), 16);
    return `\x1b[48;2;${r};${g};${b}m`;
}

function resolveConfiguredUserMessageBg(): string {
    const agentDir = getAgentDir();
    const settings = readJson(join(agentDir, "settings.json"));
    const themeName = typeof settings?.theme === "string" ? settings.theme : "catppuccin-macchiato";
    const theme = readJson(join(agentDir, "themes", `${themeName}.json`)) as ThemeJson | null;
    const raw = theme?.colors?.userMessageBg ?? FALLBACK_USER_BG;
    const resolved =
        typeof raw === "string" && theme?.vars && raw in theme.vars ? theme.vars[raw] : raw;
    return colorToBgAnsi(resolved as string | number | undefined);
}

function positiveInteger(value: unknown, fallback: number): number {
    if (typeof value !== "number" || !Number.isFinite(value)) return fallback;
    return Math.max(MIN_COLLAPSE_THRESHOLD, Math.floor(value));
}

function boundedSegmentLines(value: unknown, fallback: number): number {
    if (typeof value !== "number" || !Number.isFinite(value)) return fallback;
    return Math.max(0, Math.min(MAX_COLLAPSE_SEGMENT_LINES, Math.floor(value)));
}

function resolveCollapseSettings(): CollapseSettings {
    const settings = readJson(join(getAgentDir(), "settings.json"));
    const raw = isRecord(settings?.userMessageCollapse) ? settings.userMessageCollapse : {};
    return {
        enabled: typeof raw.enabled === "boolean" ? raw.enabled : DEFAULT_COLLAPSE_ENABLED,
        lineThreshold: positiveInteger(raw.lineThreshold, DEFAULT_COLLAPSE_LINE_THRESHOLD),
        charThreshold: positiveInteger(raw.charThreshold, DEFAULT_COLLAPSE_CHAR_THRESHOLD),
        headLines: boundedSegmentLines(
            raw.headLines ?? raw.previewLines,
            DEFAULT_COLLAPSE_HEAD_LINES,
        ),
        tailLines: boundedSegmentLines(raw.tailLines, DEFAULT_COLLAPSE_TAIL_LINES),
    };
}

function getPatchState(): PatchState {
    const globals = globalThis as typeof globalThis & { [STATE_KEY]?: PatchState };
    globals[STATE_KEY] = {
        userLabelFg: USER_LABEL_FG,
        userMessageBg: resolveConfiguredUserMessageBg(),
        collapse: resolveCollapseSettings(),
    };
    return globals[STATE_KEY];
}

function stripAnsi(text: string): string {
    return text.replace(ANSI_RE, "");
}

function keepConfiguredBg(text: string, bg: string): string {
    return text.replace(/\x1b\[49m/g, bg).replace(/\x1b\[0m/g, `${RESET}${bg}`);
}

function recolorBorder(line: string): string {
    return line.split(SOURCE_BORDER_COLOR).join(BORDER_FG);
}

function styleUserLabel(line: string, state = getPatchState()): string {
    return recolorBorder(
        line.replace(
            USER_LABEL,
            `${DEFAULT_BG}${state.userLabelFg}${USER_LABEL}${RESET}${DEFAULT_BG}`,
        ),
    );
}

function styleUserMessageBody(line: string, state = getPatchState()): string {
    const firstBorder = line.indexOf("│");
    const lastBorder = line.lastIndexOf("│");
    if (firstBorder === -1 || lastBorder <= firstBorder) return line;

    const rightBorderColor = line.lastIndexOf(SOURCE_BORDER_COLOR, lastBorder);
    const interiorStart = firstBorder + "│".length;
    const interiorEnd = rightBorderColor > interiorStart ? rightBorderColor : lastBorder;

    const before = line.slice(0, interiorStart);
    const interior = keepConfiguredBg(line.slice(interiorStart, interiorEnd), state.userMessageBg);
    const after = line.slice(interiorEnd);
    return recolorBorder(`${before}${RESET}${state.userMessageBg}${interior}${DEFAULT_BG}${after}`);
}

function styleUserMessageLine(line: string, state = getPatchState()): string {
    if (line.includes(BORDER_FG) && !line.includes(SOURCE_BORDER_COLOR)) return line;
    const plain = stripAnsi(line);
    if (plain.includes("╭")) return styleUserLabel(line, state);
    if (plain.includes("╰")) return recolorBorder(line);
    if (plain.includes("│")) return styleUserMessageBody(line, state);
    return line;
}

function isRecord(value: unknown): value is UnknownRecord {
    return typeof value === "object" && value !== null;
}

function getStringProperty(value: unknown, key: string | symbol): string | null {
    return isRecord(value) && typeof value[key] === "string" ? value[key] : null;
}

function extractMarkdownText(value: unknown): string | null {
    if (!isRecord(value)) return null;

    const directText = getStringProperty(value, "text");
    if (directText !== null) return directText;

    const children = value.children;
    if (Array.isArray(children)) {
        for (const child of children) {
            const childText = extractMarkdownText(child);
            if (childText !== null) return childText;
        }
    }

    return null;
}

function extractUserMessageText(component: unknown): string | null {
    const cached = getStringProperty(component, RAW_TEXT_CACHE_KEY);
    if (cached !== null) return cached;
    if (!isRecord(component)) return null;

    const text = extractMarkdownText(component);
    if (text !== null) {
        component[RAW_TEXT_CACHE_KEY] = text;
    }
    return text;
}

function stripControlSequences(text: string): string {
    return text.replace(OSC_RE, "").replace(ANSI_RE, "");
}

function normalizePlainText(text: string): string {
    return stripControlSequences(text).replace(/\r\n?/g, "\n").replace(/\t/g, "   ");
}

function countPhysicalLines(text: string): number {
    return normalizePlainText(text).split("\n").length;
}

function plainVisibleWidth(text: string): number {
    return visibleWidth(text);
}

function slicePlainToWidth(text: string, width: number): string {
    return stripControlSequences(truncateToWidth(text, Math.max(0, width), "", false));
}

function truncatePlainToWidth(text: string, width: number, ellipsis = "…"): string {
    if (width <= 0) return "";
    if (plainVisibleWidth(text) <= width) return text;
    const ellipsisWidth = Math.min(width, plainVisibleWidth(ellipsis));
    if (ellipsisWidth >= width) return slicePlainToWidth(ellipsis, width);
    return `${slicePlainToWidth(text, width - ellipsisWidth)}${ellipsis}`;
}

function wrapPlainText(text: string, width: number): string[] {
    if (width <= 0) return [""];
    const words = text
        .trimEnd()
        .split(/(\s+)/)
        .filter((part) => part.length > 0);
    if (words.length === 0) return [""];

    const lines: string[] = [];
    let current = "";
    for (const word of words) {
        const isSpace = /^\s+$/.test(word);
        const candidate = current + word;
        if (plainVisibleWidth(candidate) <= width) {
            current = candidate;
            continue;
        }

        if (current.trim().length > 0) {
            lines.push(current.trimEnd());
            current = isSpace ? "" : word.trimStart();
        } else if (!isSpace) {
            let remaining = word;
            while (plainVisibleWidth(remaining) > width) {
                const chunk = slicePlainToWidth(remaining, width);
                if (!chunk) break;
                lines.push(chunk);
                remaining = remaining.slice(chunk.length);
            }
            current = remaining;
        }
    }

    if (current.trim().length > 0) lines.push(current.trimEnd());
    return lines.length > 0 ? lines : [""];
}

function userBorder(width: number, top: boolean): string {
    if (width <= 1) return `${SOURCE_BORDER_COLOR}│${DEFAULT_BG}`;
    const left = top ? "╭" : "╰";
    const right = top ? "╮" : "╯";
    if (!top || width < 10) {
        return `${SOURCE_BORDER_COLOR}${left}${"─".repeat(Math.max(0, width - 2))}${right}${DEFAULT_BG}`;
    }

    const prefix = "─";
    const suffixWidth = Math.max(
        0,
        width - 2 - plainVisibleWidth(prefix) - plainVisibleWidth(USER_LABEL),
    );
    return `${SOURCE_BORDER_COLOR}${left}${prefix}${DEFAULT_BG}${USER_LABEL}${SOURCE_BORDER_COLOR}${"─".repeat(suffixWidth)}${right}${DEFAULT_BG}`;
}

function userBodyLine(content: string, width: number, contentFg?: string): string {
    if (width <= 3) return truncatePlainToWidth(content, width);
    const innerWidth = Math.max(1, width - 4);
    const fitted = truncatePlainToWidth(content, innerWidth);
    const padding = " ".repeat(Math.max(0, innerWidth - plainVisibleWidth(fitted)));
    const styledContent = contentFg ? `${contentFg}${fitted}${RESET}${DEFAULT_BG}` : fitted;
    return `${SOURCE_BORDER_COLOR}│${DEFAULT_BG} ${styledContent}${padding} ${SOURCE_BORDER_COLOR}│${DEFAULT_BG}`;
}

function separatorText(summary: string, width: number): string {
    const label = `──── ${summary} `;
    if (plainVisibleWidth(label) >= width) return truncatePlainToWidth(label.trim(), width);
    return `${label}${"─".repeat(width - plainVisibleWidth(label))}`;
}

type PreviewSegment = {
    lines: string[];
    startIndex: number;
    endIndex: number;
    charsShown: number;
    contentTruncated: boolean;
};

function selectHeadLines(
    sourceLines: string[],
    startIndex: number,
    lineLimit: number,
    contentWidth: number,
): PreviewSegment {
    const lines: string[] = [];
    let charsShown = 0;
    let contentTruncated = false;
    let index = startIndex;

    for (; index < sourceLines.length && lines.length < lineLimit; index += 1) {
        const sourceLine = sourceLines[index] ?? "";
        const wrapped = wrapPlainText(sourceLine, contentWidth);
        const slots = Math.max(0, lineLimit - lines.length);
        const visibleWrapped = wrapped.slice(0, slots);
        lines.push(...visibleWrapped);

        if (wrapped.length > slots) {
            contentTruncated = true;
            charsShown += visibleWrapped.join("").length;
            index += 1;
            break;
        }

        charsShown += sourceLine.length + 1;
    }

    if (lines.length === lineLimit && (index < sourceLines.length || contentTruncated)) {
        lines[lines.length - 1] = truncatePlainToWidth(
            lines[lines.length - 1] ?? "",
            contentWidth,
            "…",
        );
    }

    return {
        lines,
        startIndex,
        endIndex: index,
        charsShown,
        contentTruncated,
    };
}

function selectTailLines(
    sourceLines: string[],
    minIndex: number,
    lineLimit: number,
    contentWidth: number,
): PreviewSegment {
    if (lineLimit <= 0 || minIndex >= sourceLines.length) {
        return {
            lines: [],
            startIndex: sourceLines.length,
            endIndex: sourceLines.length,
            charsShown: 0,
            contentTruncated: false,
        };
    }

    const chunks: string[][] = [];
    let charsShown = 0;
    let contentTruncated = false;
    let lineCount = 0;
    let index = sourceLines.length - 1;

    for (; index >= minIndex && lineCount < lineLimit; index -= 1) {
        const sourceLine = sourceLines[index] ?? "";
        const wrapped = wrapPlainText(sourceLine, contentWidth);
        const slots = Math.max(0, lineLimit - lineCount);
        const visibleWrapped =
            wrapped.length > slots ? wrapped.slice(Math.max(0, wrapped.length - slots)) : wrapped;
        chunks.unshift(visibleWrapped);
        lineCount += visibleWrapped.length;

        if (wrapped.length > slots) {
            contentTruncated = true;
            charsShown += visibleWrapped.join("").length;
            break;
        }

        charsShown += sourceLine.length + 1;
    }

    const lines = chunks.flat();
    if (contentTruncated && lines.length > 0) {
        lines[0] = truncatePlainToWidth(`…${lines[0]}`, contentWidth);
    }

    return {
        lines,
        startIndex: index + 1,
        endIndex: sourceLines.length,
        charsShown,
        contentTruncated,
    };
}

function selectCollapsedPreview(
    text: string,
    settings: CollapseSettings,
    contentWidth: number,
): {
    lines: string[];
    hiddenLines: number;
    hiddenChars: number;
} {
    const normalized = normalizePlainText(text);
    const sourceLines = normalized.split("\n");
    let startIndex = 0;
    while (startIndex < sourceLines.length && sourceLines[startIndex]?.trim().length === 0) {
        startIndex += 1;
    }

    if (startIndex >= sourceLines.length) {
        return { lines: [""], hiddenLines: 0, hiddenChars: 0 };
    }

    const head = selectHeadLines(sourceLines, startIndex, settings.headLines, contentWidth);
    const tail = selectTailLines(sourceLines, head.endIndex, settings.tailLines, contentWidth);
    const hiddenLines = Math.max(0, tail.startIndex - head.endIndex);
    const hiddenChars = Math.max(0, normalized.length - head.charsShown - tail.charsShown);

    return {
        lines: [...head.lines, ...tail.lines],
        hiddenLines,
        hiddenChars,
    };
}

function shouldCollapseUserMessage(text: string, settings: CollapseSettings): boolean {
    if (!settings.enabled) return false;
    const normalized = normalizePlainText(text);
    return (
        normalized.split("\n").length > settings.lineThreshold ||
        normalized.length > settings.charThreshold
    );
}

function renderCollapsedUserMessage(
    text: string,
    width: number,
    settings: CollapseSettings,
    state: PatchState,
): string[] {
    const safeWidth = Math.max(1, Math.floor(width));
    if (safeWidth < 8) {
        const line = truncatePlainToWidth("User prompt hidden", safeWidth);
        return [`${OSC133_ZONE_START}${line}${OSC133_ZONE_END}${OSC133_ZONE_FINAL}`];
    }

    const contentWidth = Math.max(1, safeWidth - 4);
    const preview = selectCollapsedPreview(text, settings, contentWidth);
    const summary =
        preview.hiddenLines > 0
            ? `(${preview.hiddenLines} line${preview.hiddenLines === 1 ? "" : "s"} hidden)`
            : `(${preview.hiddenChars} char${preview.hiddenChars === 1 ? "" : "s"} hidden)`;

    const previewLines =
        preview.hiddenLines > 0 || preview.hiddenChars > 0
            ? [
                  ...preview.lines.slice(0, settings.headLines).map((content) => ({ content })),
                  { content: separatorText(summary, contentWidth), fg: SEPARATOR_FG },
                  ...preview.lines.slice(settings.headLines).map((content) => ({ content })),
              ]
            : preview.lines.map((content) => ({ content }));
    const bodyLines = [{ content: "" }, ...previewLines, { content: "" }];

    const lines = [
        userBorder(safeWidth, true),
        ...bodyLines.map((line) => userBodyLine(line.content, safeWidth, line.fg)),
        userBorder(safeWidth, false),
    ].map((line) => styleUserMessageLine(line, state));

    lines[0] = OSC133_ZONE_START + lines[0];
    lines[lines.length - 1] += OSC133_ZONE_END + OSC133_ZONE_FINAL;
    return lines;
}

function hashText(text: string): string {
    let hash = 0x811c9dc5;
    for (let index = 0; index < text.length; index += 1) {
        hash ^= text.charCodeAt(index);
        hash = Math.imul(hash, 0x01000193) >>> 0;
    }
    return hash.toString(16);
}

function renderCacheKey(width: number, text: string, mode: RenderMode, state: PatchState): string {
    return [
        mode,
        Math.max(1, Math.floor(width)),
        text.length,
        hashText(text),
        state.userLabelFg,
        state.userMessageBg,
        state.collapse.enabled ? 1 : 0,
        state.collapse.lineThreshold,
        state.collapse.charThreshold,
        state.collapse.headLines,
        state.collapse.tailLines,
    ].join(":");
}

function getCachedLines(component: unknown, key: string): string[] | null {
    if (!isRecord(component)) return null;
    const cache = component[RENDER_CACHE_KEY] as RenderCache | undefined;
    return cache?.key === key && Array.isArray(cache.lines) ? cache.lines : null;
}

function setCachedLines(component: unknown, key: string, lines: string[]): void {
    if (!isRecord(component)) return;
    component[RENDER_CACHE_KEY] = { key, lines } satisfies RenderCache;
}

function clearRenderCache(component: unknown): void {
    if (!isRecord(component)) return;
    delete component[RENDER_CACHE_KEY];
}

function installPatch(UserMessageComponent: UserMessageComponentCtor): void {
    const proto = UserMessageComponent.prototype;
    if (typeof proto.render !== "function") return;

    const meta = proto[PATCH_FLAG] as PatchMeta | boolean | undefined;
    if (
        typeof meta === "object" &&
        meta.wrapped === proto.render &&
        meta.invalidate === proto.invalidate &&
        meta.version === PATCH_VERSION
    ) {
        return;
    }

    const originalRender =
        typeof meta === "object" && typeof meta.originalRender === "function"
            ? meta.originalRender
            : proto.render;
    const originalInvalidate =
        typeof meta === "object" && typeof meta.originalInvalidate === "function"
            ? meta.originalInvalidate
            : proto.invalidate;
    const wrapped: RenderFunction = function patchedUserMessageStyle(width: number): string[] {
        const state = getPatchState();
        const rawText = extractUserMessageText(this) ?? "";
        const mode: RenderMode =
            rawText && shouldCollapseUserMessage(rawText, state.collapse) ? "collapsed" : "normal";
        const cacheKey = renderCacheKey(width, rawText, mode, state);
        const cached = getCachedLines(this, cacheKey);
        if (cached) return cached;

        if (mode === "collapsed") {
            const collapsed = renderCollapsedUserMessage(rawText, width, state.collapse, state);
            setCachedLines(this, cacheKey, collapsed);
            return collapsed;
        }

        const lines = originalRender.call(this, width);
        const styled = lines.map((line) => styleUserMessageLine(line, state));
        setCachedLines(this, cacheKey, styled);
        return styled;
    };
    const invalidate: InvalidateFunction = function patchedUserMessageInvalidate(
        ...args: unknown[]
    ): unknown {
        clearRenderCache(this);
        return originalInvalidate?.apply(this, args);
    };

    proto.render = wrapped;
    proto.invalidate = invalidate;
    proto[PATCH_FLAG] = {
        wrapped,
        invalidate,
        originalRender,
        originalInvalidate,
        version: PATCH_VERSION,
    } satisfies PatchMeta;
}

let componentPromise: Promise<UserMessageComponentCtor | null> | null = null;

async function loadUserMessageComponent(): Promise<UserMessageComponentCtor | null> {
    for (const specifier of ["@mariozechner/pi-coding-agent", "@earendil-works/pi-coding-agent"]) {
        try {
            const module = (await import(specifier)) as {
                UserMessageComponent?: UserMessageComponentCtor;
            };
            if (module.UserMessageComponent?.prototype) {
                return module.UserMessageComponent;
            }
        } catch {
            // Try the next package name. Pi has used both names across versions.
        }
    }
    return null;
}

async function installUserMessageStylePatch(): Promise<void> {
    getPatchState();
    componentPromise ??= loadUserMessageComponent();
    const UserMessageComponent = await componentPromise;
    if (UserMessageComponent) installPatch(UserMessageComponent);
}

export default function userMessageStyle(pi: ExtensionAPI): void {
    pi.on("session_start", installUserMessageStylePatch);
    pi.on("turn_start", installUserMessageStylePatch);
}
