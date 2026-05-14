// @ts-nocheck
import { existsSync, readFileSync } from "node:fs";
import { basename, isAbsolute, join, relative, resolve, sep } from "node:path";
import { homedir } from "node:os";

interface ExtensionAPI {
    on(
        event: "session_start",
        handler: (event: SessionStartEvent, ctx: ExtensionContext) => Promise<void>,
    ): void;
    on(
        event: "session_shutdown",
        handler: (event: unknown, ctx: ExtensionContext) => Promise<void>,
    ): void;
    getCommands(): SlashCommandInfo[];
    getAllTools(): ToolInfo[];
    getThinkingLevel(): string;
}

interface SessionStartEvent {
    reason: "startup" | "reload" | "new" | "resume" | "fork";
}

interface ExtensionContext {
    hasUI?: boolean;
    cwd?: string;
    model?: unknown;
    getSystemPrompt?: () => string;
    ui?: {
        setHeader?: (factory: HeaderFactory | undefined) => void;
        getAllThemes?: () => Array<{ name: string; path?: string }>;
        theme?: ThemeLike;
    };
}

type HeaderFactory = (tui: unknown, theme: ThemeLike) => StartupHeader;

interface ThemeLike {
    name?: string;
    fg?: (color: string, text: string) => string;
    bold?: (text: string) => string;
}

interface SlashCommandInfo {
    name: string;
    source: "extension" | "prompt" | "skill" | string;
    sourceInfo?: SourceInfo;
}

interface ToolInfo {
    name: string;
    sourceInfo?: SourceInfo;
}

interface SourceInfo {
    path?: string;
    source?: string;
    origin?: string;
    baseDir?: string;
}

interface StartupFacts {
    version: string;
    model: string;
    provider: string;
    thinking: string;
    cwd: string;
    contextPaths: string[];
    skillNames: string[];
    promptNames: string[];
    extensionSourceNames: string[];
    themeNames: string[];
}

type JsonRecord = Record<string, unknown>;

const DOT_PI = [
    "⠿⠿⠿⠿⠿⠿⠿⠿⠿⠿⠿⠿",
    "  ⠿⠿     ⠿⠿",
    "  ⠿⠿     ⠿⠿",
    " ⠿⠿      ⠿⠿",
    "⠿⠟       ⠻⠿",
] as const;
const ASCII_PI = ["==========", "  ||   ||", "  ||   ||", " ||    ||", "=/     \\="] as const;
const ANSI_PATTERN = /\x1b\[[0-9;]*m/g;

export default function startupScreen(pi: ExtensionAPI): void {
    let currentCtx: ExtensionContext | null = null;
    let headerInstalled = false;

    const clearInstalledHeader = (ctx: ExtensionContext | null | undefined): void => {
        if (!headerInstalled || !ctx?.hasUI || typeof ctx.ui?.setHeader !== "function") return;
        ctx.ui.setHeader(undefined);
        headerInstalled = false;
    };

    pi.on("session_start", async (_event, ctx) => {
        if (!ctx?.hasUI || typeof ctx.ui?.setHeader !== "function") return;

        currentCtx = ctx;
        const settings = readMergedSettings(ctx.cwd ?? process.cwd());

        if (!isStartupScreenEnabled(settings)) {
            clearInstalledHeader(ctx);
            return;
        }

        const facts = collectStartupFacts(pi, ctx, settings);
        headerInstalled = true;
        ctx.ui.setHeader((_tui, theme) => new StartupHeader(facts, theme));
    });

    pi.on("session_shutdown", async (_event, ctx) => {
        clearInstalledHeader(ctx ?? currentCtx);
        currentCtx = null;
    });
}

class StartupHeader {
    private expanded = false;
    private readonly facts: StartupFacts;
    private readonly theme: ThemeLike;

    constructor(facts: StartupFacts, theme: ThemeLike) {
        this.facts = facts;
        this.theme = theme;
    }

    dispose(): void {}
    invalidate(): void {}

    setExpanded(expanded: boolean): void {
        this.expanded = expanded;
    }

    render(width: number): string[] {
        if (width < 44) return this.renderNarrow(width);
        return this.renderWide(width);
    }

    private renderWide(width: number): string[] {
        const contentWidth = Math.max(1, width - 1);
        const logoLines = this.renderWideLogoLines(contentWidth);

        if (!this.expanded) {
            return ["", ...logoLines.map((line) => ` ${line}`), ""];
        }

        return [
            "",
            ...logoLines.map((line) => ` ${line}`),
            "",
            ...this.expandedResourceRows(contentWidth).map((line) => ` ${line}`),
            "",
        ];
    }

    private renderWideLogoLines(contentWidth: number): string[] {
        const art = supportsUnicode() ? DOT_PI : ASCII_PI;
        const artWidth = Math.max(...art.map((line) => visibleWidth(line)));
        const gap = "   ";
        const textWidth = Math.max(8, contentWidth - artWidth - visibleWidth(gap));
        const rows = this.compactRows();

        return art.map((line, index) => {
            const left = this.colorArt(padVisible(line, artWidth));
            const right = fitVisible(rows[index] ?? "", textWidth);
            return fitVisible(`${left}${gap}${right}`, contentWidth);
        });
    }

    private renderNarrow(width: number): string[] {
        const contentWidth = Math.max(1, width - 1);
        if (this.expanded) {
            return [
                "",
                ...this.expandedResourceRows(contentWidth).map(
                    (line) => ` ${fitVisible(line, contentWidth)}`,
                ),
                "",
            ];
        }

        const rows = [
            `π ${this.facts.version} · ${this.facts.model}`,
            `${this.facts.cwd} · ${this.countSummary()}`,
            "ctrl+o details · / · !",
        ];

        return [
            "",
            ...rows.map((line, index) => {
                const colored =
                    index === 0
                        ? this.accent(line)
                        : index === rows.length - 1
                          ? this.dim(line)
                          : line;
                return ` ${fitVisible(colored, contentWidth)}`;
            }),
            "",
        ];
    }

    private compactRows(): string[] {
        return [
            this.accent(`Pi ${this.facts.version}`),
            `${this.modelText()} ${this.dim(`· ${this.facts.provider}`)}`,
            this.path(this.facts.cwd),
            this.dim(this.countSummary()),
            this.dim("ctrl+o details · / commands · ! bash"),
        ];
    }

    private expandedResourceRows(width: number): string[] {
        const rows = [
            this.dim("escape interrupt · ctrl+c/ctrl+d clear/exit · ctrl+o compact"),
            this.dim("Press ctrl+o to hide full startup help and loaded resources."),
            "",
            "Pi can explain its own features and look up its docs. Ask it how to use or extend Pi.",
            "",
            ...this.sectionRows("Context", this.facts.contextPaths, width),
            "",
            ...this.sectionRows("Skills", this.facts.skillNames, width),
            "",
            ...this.sectionRows("Prompts", this.facts.promptNames, width),
            "",
            ...this.sectionRows("Extensions", this.facts.extensionSourceNames, width),
            "",
            ...this.sectionRows("Themes", [this.activeThemeName()], width),
        ];

        return rows.map((line) => fitVisible(line, width));
    }

    private sectionRows(title: string, items: string[], width: number): string[] {
        return [
            this.model(`[${title}]`),
            ...wrapCommaList(items.length ? items : ["none"], width, "  "),
        ];
    }

    private countSummary(): string {
        return [
            pluralCount(this.facts.contextPaths.length, "context"),
            pluralCount(this.facts.skillNames.length, "skill"),
            pluralCount(this.facts.promptNames.length, "prompt"),
            pluralCount(this.facts.extensionSourceNames.length, "extension"),
        ].join(" · ");
    }

    private activeThemeName(): string {
        return this.theme.name || this.facts.themeNames[0] || "default";
    }

    private modelText(): string {
        const thinking = this.facts.thinking ? ` · ${this.facts.thinking}` : "";
        return this.model(`${this.facts.model}${thinking}`);
    }

    private colorArt(text: string): string {
        return this.fg("accent", text);
    }

    private accent(text: string): string {
        const colored = this.fg("accent", text);
        return typeof this.theme.bold === "function" ? this.theme.bold(colored) : colored;
    }

    private model(text: string): string {
        return this.fg("mdHeading", text);
    }

    private path(text: string): string {
        return this.fg("mdLink", text);
    }

    private dim(text: string): string {
        return this.fg("dim", text);
    }

    private fg(color: string, text: string): string {
        return typeof this.theme.fg === "function" ? this.theme.fg(color, text) : text;
    }
}

function collectStartupFacts(
    pi: ExtensionAPI,
    ctx: ExtensionContext,
    settings: JsonRecord,
): StartupFacts {
    const cwd = resolve(ctx.cwd ?? process.cwd());
    const modelInfo = readModelInfo(ctx.model);
    const commands = safeArray(() => pi.getCommands());
    const tools = safeArray(() => pi.getAllTools());
    const systemPrompt = safeString(() => ctx.getSystemPrompt?.());
    const themeNames = safeArray(() => ctx.ui?.getAllThemes?.() ?? [])
        .map((theme) => theme.name)
        .filter((name) => typeof name === "string" && name.trim().length > 0)
        .sort((a, b) => a.localeCompare(b));

    return {
        version: `v${readString(settings.lastChangelogVersion, "0.74.0").replace(/^v/i, "")}`,
        model: compactModelName(modelInfo.name || "model"),
        provider: compactProviderName(modelInfo.provider || "provider"),
        thinking: safeString(() => pi.getThinkingLevel()),
        cwd: formatCwd(cwd),
        contextPaths: parseContextPaths(systemPrompt, cwd),
        skillNames: commands
            .filter((command) => command.source === "skill")
            .map((command) => command.name.replace(/^skill:/, ""))
            .sort((a, b) => a.localeCompare(b)),
        promptNames: commands
            .filter((command) => command.source === "prompt")
            .map((command) => `/${command.name.replace(/^\//, "")}`)
            .sort((a, b) => a.localeCompare(b)),
        extensionSourceNames: collectExtensionSourceNames(commands, tools),
        themeNames,
    };
}

function collectExtensionSourceNames(commands: SlashCommandInfo[], tools: ToolInfo[]): string[] {
    const names = new Set<string>();

    for (const command of commands) {
        if (command.source === "extension") addSourceInfoLabel(command.sourceInfo, names);
    }

    for (const tool of tools) {
        addSourceInfoLabel(tool.sourceInfo, names);
    }

    return Array.from(names).sort((a, b) => a.localeCompare(b));
}

function addSourceInfoLabel(sourceInfo: SourceInfo | undefined, names: Set<string>): void {
    if (!sourceInfo || isBuiltInSource(sourceInfo)) return;
    const label = labelSourceInfo(sourceInfo);
    if (label) names.add(label);
}

function isBuiltInSource(sourceInfo: SourceInfo): boolean {
    const path = sourceInfo.path ?? "";
    const source = sourceInfo.source ?? "";
    return (
        source === "builtin" ||
        source === "sdk" ||
        path.startsWith("<builtin") ||
        path.startsWith("<sdk")
    );
}

function labelSourceInfo(sourceInfo: SourceInfo): string {
    const path = sourceInfo.path ?? sourceInfo.baseDir ?? "";
    if (!path) return "";

    const withoutIndex = path.replace(/\/index\.(ts|js)$/i, "").replace(/\/index$/i, "");
    const packageMatch = withoutIndex.match(/node_modules\/(?:@[^/]+\/)?([^/]+)(?:\/|$)/);
    if (packageMatch?.[1]) return packageMatch[1];

    if (withoutIndex.includes(":")) {
        const [source, subpath] = withoutIndex.split(":", 2);
        const sourceLabel = source.replace(/^@[^/]+\//, "");
        return subpath ? `${sourceLabel}:${subpath}` : sourceLabel;
    }

    return basename(withoutIndex).replace(/\.(ts|js)$/i, "");
}

function parseContextPaths(systemPrompt: string, cwd: string): string[] {
    const marker = "# Project Context";
    const start = systemPrompt.indexOf(marker);
    if (start === -1) return [];

    const tail = systemPrompt.slice(start + marker.length);
    const endMarkers = ["\n\nThe following skills", "\n<available_skills>", "\nCurrent date:"];
    const end = endMarkers
        .map((endMarker) => tail.indexOf(endMarker))
        .filter((index) => index >= 0)
        .sort((a, b) => a - b)[0];
    const contextSection = end === undefined ? tail : tail.slice(0, end);
    const paths: string[] = [];

    for (const match of contextSection.matchAll(/^##\s+(.+)$/gm)) {
        const path = match[1]?.trim();
        if (path && looksLikeContextPath(path)) paths.push(formatPath(path, cwd));
    }

    return paths;
}

function readModelInfo(model: unknown): { name: string; provider: string } {
    if (!isRecord(model)) return { name: "", provider: "" };

    const id = readString(model.id, "");
    const name = readString(model.name, id);
    const providerValue = model.provider;
    let provider = "";

    if (typeof providerValue === "string") {
        provider = providerValue;
    } else if (isRecord(providerValue)) {
        provider = readString(providerValue.name, readString(providerValue.id, ""));
    }

    return { name, provider };
}

function readMergedSettings(cwd: string): JsonRecord {
    return mergeRecords(
        readSettingsFile(join(getAgentDir(), "settings.json")),
        readSettingsFile(join(cwd, ".pi", "settings.json")),
    );
}

function readSettingsFile(path: string): JsonRecord {
    try {
        if (!existsSync(path)) return {};
        const parsed = JSON.parse(readFileSync(path, "utf-8"));
        return isRecord(parsed) ? parsed : {};
    } catch (error) {
        return {};
    }
}

function mergeRecords(base: JsonRecord, override: JsonRecord): JsonRecord {
    const result: JsonRecord = { ...base };
    for (const [key, value] of Object.entries(override)) {
        const previous = result[key];
        result[key] = isRecord(previous) && isRecord(value) ? mergeRecords(previous, value) : value;
    }
    return result;
}

function isStartupScreenEnabled(settings: JsonRecord): boolean {
    const config = settings.startupScreen;
    if (!isRecord(config)) return true;
    return config.enabled !== false;
}

function looksLikeContextPath(path: string): boolean {
    return (
        path.startsWith("/") ||
        path.startsWith("~") ||
        path.startsWith(".") ||
        path.includes(sep) ||
        path.includes("/") ||
        /(?:AGENTS|CLAUDE)\.md$/i.test(path)
    );
}

function formatCwd(cwd: string): string {
    const home = getHomeDir();
    if (cwd === home) return "~";
    if (cwd.startsWith(`${home}${sep}`)) return `~/${cwd.slice(home.length + 1)}`;
    return cwd;
}

function formatPath(path: string, cwd: string): string {
    const home = getHomeDir();
    const absolute = isAbsolute(path) ? resolve(path) : resolve(cwd, path);
    const relativeToCwd = relative(cwd, absolute);

    if (relativeToCwd === "") return ".";
    if (!relativeToCwd.startsWith("..") && !isAbsolute(relativeToCwd)) return relativeToCwd || ".";
    if (absolute === home) return "~";
    if (absolute.startsWith(`${home}${sep}`)) return `~/${absolute.slice(home.length + 1)}`;
    return absolute;
}

function getAgentDir(): string {
    return process.env.PI_CODING_AGENT_DIR || join(getHomeDir(), ".pi", "agent");
}

function getHomeDir(): string {
    return process.env.HOME || process.env.USERPROFILE || homedir();
}

function compactModelName(name: string): string {
    return name
        .replace(/^openai\//, "")
        .replace(/^anthropic\//, "")
        .replace(/^google\//, "");
}

function compactProviderName(name: string): string {
    return name.replace(/^openai-/, "").replace(/^google-/, "google");
}

function pluralCount(count: number, label: string): string {
    return `${count} ${label}${count === 1 ? "" : "s"}`;
}

function wrapCommaList(items: string[], width: number, indent: string): string[] {
    const maxWidth = Math.max(8, width - visibleWidth(indent));
    const rows: string[] = [];
    let current = "";

    for (let i = 0; i < items.length; i++) {
        const token = `${items[i]}${i === items.length - 1 ? "" : ","}`;
        const next = current ? `${current} ${token}` : token;

        if (current && visibleWidth(next) > maxWidth) {
            rows.push(`${indent}${current}`);
            current = token;
        } else {
            current = next;
        }
    }

    if (current) rows.push(`${indent}${current}`);
    return rows;
}

function supportsUnicode(): boolean {
    return process.env.LC_ALL !== "C" && process.env.LANG !== "C";
}

function fitVisible(text: string, width: number): string {
    if (width <= 0) return "";
    const current = visibleWidth(text);
    if (current <= width) return `${text}${" ".repeat(width - current)}`;
    return truncateVisible(text, Math.max(1, width - 1)) + "…";
}

function padVisible(text: string, width: number): string {
    const current = visibleWidth(text);
    return current >= width ? text : `${text}${" ".repeat(width - current)}`;
}

function truncateVisible(text: string, width: number): string {
    let result = "";
    let consumed = 0;
    let inAnsi = false;

    for (let i = 0; i < text.length; i++) {
        const char = text[i];
        if (char === "\x1b") inAnsi = true;
        if (inAnsi) {
            result += char;
            if (char === "m") inAnsi = false;
            continue;
        }

        if (consumed + 1 > width) break;
        result += char;
        consumed++;
    }

    return result;
}

function visibleWidth(text: string): number {
    return Array.from(text.replace(ANSI_PATTERN, "")).length;
}

function readString(value: unknown, fallback: string): string {
    return typeof value === "string" && value.trim() ? value.trim() : fallback;
}

function safeString(fn: () => unknown): string {
    try {
        const value = fn();
        return typeof value === "string" ? value : "";
    } catch {
        return "";
    }
}

function safeArray<T>(fn: () => T[] | readonly T[] | undefined): T[] {
    try {
        const value = fn();
        return Array.isArray(value) ? [...value] : [];
    } catch {
        return [];
    }
}

function isRecord(value: unknown): value is JsonRecord {
    return typeof value === "object" && value !== null && !Array.isArray(value);
}
