interface ExtensionAPI {
    on(event: "input", handler: (event: InputEvent) => InputEventResult): void;
    on(
        event: "session_start",
        handler: (event: SessionStartEvent, ctx: ExtensionContext) => Promise<void> | void,
    ): void;
    getCommands(): SlashCommandInfo[];
}

interface SessionStartEvent {
    reason: "startup" | "reload" | "new" | "resume" | "fork";
}

interface ExtensionContext {
    hasUI?: boolean;
    ui?: {
        addAutocompleteProvider?: (factory: AutocompleteProviderFactory) => void;
    };
}

type AutocompleteProviderFactory = (current: AutocompleteProvider) => AutocompleteProvider;

interface AutocompleteItem {
    value: string;
    label: string;
    description?: string;
}

interface AutocompleteSuggestions {
    items: AutocompleteItem[];
    prefix: string;
}

interface AutocompleteProvider {
    getSuggestions(
        lines: string[],
        cursorLine: number,
        cursorCol: number,
        options: { signal: AbortSignal; force?: boolean },
    ): Promise<AutocompleteSuggestions | null> | AutocompleteSuggestions | null;
    applyCompletion(
        lines: string[],
        cursorLine: number,
        cursorCol: number,
        item: AutocompleteItem,
        prefix: string,
    ): {
        lines: string[];
        cursorLine: number;
        cursorCol: number;
    };
    shouldTriggerFileCompletion?(lines: string[], cursorLine: number, cursorCol: number): boolean;
}

interface InputEvent {
    text: string;
    images?: unknown[];
    source: "interactive" | "rpc" | "extension";
}

type InputEventResult =
    | { action: "continue" }
    | { action: "transform"; text: string; images?: unknown[] }
    | { action: "handled" };

interface SlashCommandInfo {
    name: string;
    description?: string;
    source: "extension" | "prompt" | "skill";
}

const SKILL_COMMAND_PREFIX = "skill:";
const EXPLICIT_SKILL_COMMAND = /^\/skill:([a-z0-9](?:[a-z0-9-]*[a-z0-9])?)(?:[ \t]+(.*))?$/;
const BARE_SKILL_COMMAND = /^\/([a-z0-9](?:[a-z0-9-]*[a-z0-9])?)(?:[ \t]+(.*))?$/;
const SAME_LINE_SKILL_TOKEN = /\/(?:skill:)?[a-z0-9](?:[a-z0-9-]*[a-z0-9])?/g;
const FENCE_START = /^\s*(```|~~~)/;
const INDENTED_CODE_LINE = /^(?: {4,}| {0,3}\t)/;
const WRAPPED_SKILL_PREFIX = "<skill ";

const BUILTIN_COMMANDS = new Set([
    "settings",
    "model",
    "scoped-models",
    "export",
    "import",
    "share",
    "copy",
    "name",
    "session",
    "changelog",
    "hotkeys",
    "fork",
    "clone",
    "tree",
    "login",
    "logout",
    "new",
    "compact",
    "resume",
    "reload",
    "quit",
]);

interface InlineSkillTransform {
    text: string;
    skillName: string;
}

interface WholeLineSkillCandidate {
    kind: "whole-line";
    lineIndex: number;
    skillName: string;
    inlineArgs: string;
}

interface SameLineSkillCandidate {
    kind: "same-line";
    lineIndex: number;
    skillName: string;
    tokenStart: number;
    tokenEnd: number;
}

type SkillCandidate = WholeLineSkillCandidate | SameLineSkillCandidate;

interface TextSpan {
    start: number;
    end: number;
}

interface MidPromptSlashToken {
    promptIndex: number;
    lineStart: number;
    lineEnd: number;
    token: string;
    prefix: string;
}

export function transformInlineSkillInvocation(
    text: string,
    commands: SlashCommandInfo[],
): InlineSkillTransform | null {
    if (text.startsWith(WRAPPED_SKILL_PREFIX)) return null;

    const skillNames = collectSkillNames(commands);
    if (skillNames.size === 0) return null;

    const nonSkillCommands = collectNonSkillCommandNames(commands);
    const lines = text.split("\n");
    const candidate = findInlineSkillCandidate(lines, skillNames, nonSkillCommands);
    if (!candidate) return null;

    const args = removeInvocationLine(lines, candidate).trim();
    return {
        skillName: candidate.skillName,
        text: args ? `/skill:${candidate.skillName} ${args}` : `/skill:${candidate.skillName}`,
    };
}

export default function inlineSkillInvocations(pi: ExtensionAPI): void {
    pi.on("session_start", async (_event, ctx) => {
        if (!ctx?.hasUI || typeof ctx.ui?.addAutocompleteProvider !== "function") return;

        ctx.ui.addAutocompleteProvider(
            (provider) => new InlineSkillAutocompleteProvider(provider, () => pi.getCommands()),
        );
    });

    pi.on("input", (event: InputEvent): InputEventResult => {
        if (event.source === "extension") return { action: "continue" };

        const transformed = transformInlineSkillInvocation(event.text, pi.getCommands());
        if (!transformed) return { action: "continue" };

        return {
            action: "transform",
            text: transformed.text,
            images: event.images,
        };
    });
}

class InlineSkillAutocompleteProvider implements AutocompleteProvider {
    private readonly defaultProvider: AutocompleteProvider;
    private readonly getCommands: () => SlashCommandInfo[];
    private skillCompletionActive = false;

    constructor(defaultProvider: AutocompleteProvider, getCommands: () => SlashCommandInfo[]) {
        this.defaultProvider = defaultProvider;
        this.getCommands = getCommands;
    }

    getSuggestions(
        lines: string[],
        cursorLine: number,
        cursorCol: number,
        options: { signal: AbortSignal; force?: boolean },
    ): Promise<AutocompleteSuggestions | null> | AutocompleteSuggestions | null {
        const token = findMidPromptSlashToken(lines, cursorLine, cursorCol);
        if (!token) {
            if (this.skillCompletionActive) {
                this.skillCompletionActive = false;
                return null;
            }
            return this.defaultProvider.getSuggestions(lines, cursorLine, cursorCol, options);
        }

        this.skillCompletionActive = true;
        const items = getSkillCompletionItems(this.getCommands(), token.prefix);
        if (items.length === 0) return null;
        return { items, prefix: token.token };
    }

    applyCompletion(
        lines: string[],
        cursorLine: number,
        cursorCol: number,
        item: AutocompleteItem,
        prefix: string,
    ): {
        lines: string[];
        cursorLine: number;
        cursorCol: number;
    } {
        const token = findMidPromptSlashToken(lines, cursorLine, cursorCol);
        if (!token) {
            this.skillCompletionActive = false;
            return this.defaultProvider.applyCompletion(lines, cursorLine, cursorCol, item, prefix);
        }

        this.skillCompletionActive = false;
        const replacement = item.value.startsWith("/") ? item.value : `/${item.value}`;
        const currentLine = lines[cursorLine] ?? "";
        const nextLines = [...lines];
        nextLines[cursorLine] =
            currentLine.slice(0, token.lineStart) + replacement + currentLine.slice(token.lineEnd);

        return {
            lines: nextLines,
            cursorLine,
            cursorCol: token.lineStart + replacement.length,
        };
    }

    shouldTriggerFileCompletion(lines: string[], cursorLine: number, cursorCol: number): boolean {
        if (findMidPromptSlashToken(lines, cursorLine, cursorCol)) return true;
        return (
            this.defaultProvider.shouldTriggerFileCompletion?.(lines, cursorLine, cursorCol) ??
            false
        );
    }
}

function getSkillCompletionItems(commands: SlashCommandInfo[], prefix: string): AutocompleteItem[] {
    return commands
        .filter((command) => command.source === "skill")
        .filter((command) => command.name.startsWith(SKILL_COMMAND_PREFIX))
        .map((command) => ({
            name: command.name.slice(SKILL_COMMAND_PREFIX.length),
            description: command.description,
        }))
        .filter((skill) => skill.name.startsWith(prefix))
        .sort((a, b) => a.name.localeCompare(b.name))
        .map((skill) => ({
            value: `/${skill.name}`,
            label: skill.name,
            ...(skill.description ? { description: skill.description } : {}),
        }));
}

function collectSkillNames(commands: SlashCommandInfo[]): Set<string> {
    const skillNames = new Set<string>();
    for (const command of commands) {
        if (command.source !== "skill") continue;
        if (!command.name.startsWith(SKILL_COMMAND_PREFIX)) continue;
        skillNames.add(command.name.slice(SKILL_COMMAND_PREFIX.length));
    }
    return skillNames;
}

function findMidPromptSlashToken(
    lines: string[],
    cursorLine: number,
    cursorCol: number,
): MidPromptSlashToken | null {
    if (cursorLine < 0 || cursorLine >= lines.length) return null;

    const line = lines[cursorLine] ?? "";
    const safeCursorCol = Math.max(0, Math.min(cursorCol, line.length));
    const beforeCursor = line.slice(0, safeCursorCol);
    const delimiterIndex = Math.max(beforeCursor.lastIndexOf(" "), beforeCursor.lastIndexOf("\t"));
    const lineStart = delimiterIndex + 1;
    const token = line.slice(lineStart, safeCursorCol);

    if (!token.startsWith("/")) return null;
    if (!/^\/[a-z0-9-]*$/.test(token)) return null;

    const promptIndex = getPromptIndex(lines, cursorLine, lineStart);
    // Index 0 is reserved for Pi's normal slash-command menu.
    if (promptIndex <= 0) return null;

    return {
        promptIndex,
        lineStart,
        lineEnd: safeCursorCol,
        token,
        prefix: token.slice(1),
    };
}

function getPromptIndex(lines: string[], cursorLine: number, lineCol: number): number {
    let index = Math.max(0, lineCol);
    for (let lineIndex = 0; lineIndex < cursorLine; lineIndex += 1) {
        index += (lines[lineIndex] ?? "").length + 1;
    }
    return index;
}

function collectNonSkillCommandNames(commands: SlashCommandInfo[]): Set<string> {
    const commandNames = new Set(BUILTIN_COMMANDS);
    for (const command of commands) {
        if (command.source === "skill") continue;
        commandNames.add(command.name);
    }
    return commandNames;
}

function findInlineSkillCandidate(
    lines: string[],
    skillNames: Set<string>,
    nonSkillCommands: Set<string>,
): SkillCandidate | null {
    let inFence = false;

    for (let lineIndex = 0; lineIndex < lines.length; lineIndex += 1) {
        const line = stripTrailingCarriageReturn(lines[lineIndex] ?? "");
        const trimmed = line.trim();

        if (INDENTED_CODE_LINE.test(line)) continue;

        if (FENCE_START.test(trimmed)) {
            inFence = !inFence;
            continue;
        }

        if (inFence || trimmed === "") continue;

        const explicit = EXPLICIT_SKILL_COMMAND.exec(trimmed);
        if (explicit) {
            const skillName = explicit[1] ?? "";
            if (skillNames.has(skillName)) {
                return {
                    kind: "whole-line",
                    lineIndex,
                    skillName,
                    inlineArgs: (explicit[2] ?? "").trim(),
                };
            }
        }

        const bare = BARE_SKILL_COMMAND.exec(trimmed);
        if (bare) {
            const skillName = bare[1] ?? "";
            if (skillNames.has(skillName) && !nonSkillCommands.has(skillName)) {
                return {
                    kind: "whole-line",
                    lineIndex,
                    skillName,
                    inlineArgs: (bare[2] ?? "").trim(),
                };
            }
        }

        const sameLine = findSameLineSkillCandidate(line, lineIndex, skillNames, nonSkillCommands);
        if (sameLine) return sameLine;
    }

    return null;
}

function findSameLineSkillCandidate(
    line: string,
    lineIndex: number,
    skillNames: Set<string>,
    nonSkillCommands: Set<string>,
): SameLineSkillCandidate | null {
    const inlineCodeSpans = findInlineCodeSpans(line);
    SAME_LINE_SKILL_TOKEN.lastIndex = 0;

    for (;;) {
        const match = SAME_LINE_SKILL_TOKEN.exec(line);
        if (!match) return null;

        const token = match[0] ?? "";
        const tokenStart = match.index;
        const tokenEnd = tokenStart + token.length;

        if (isPositionInSpans(tokenStart, inlineCodeSpans)) continue;
        if (isPositionInSpans(tokenEnd - 1, inlineCodeSpans)) continue;
        if (!hasSafeSkillTokenStart(line, tokenStart)) continue;
        if (!hasSafeSkillTokenEnd(line, tokenEnd)) continue;

        const isExplicit = token.startsWith(`/${SKILL_COMMAND_PREFIX}`);
        const skillName = isExplicit
            ? token.slice(SKILL_COMMAND_PREFIX.length + 1)
            : token.slice(1);

        if (!skillNames.has(skillName)) continue;
        if (!isExplicit && nonSkillCommands.has(skillName)) continue;

        return { kind: "same-line", lineIndex, skillName, tokenStart, tokenEnd };
    }
}

function findInlineCodeSpans(line: string): TextSpan[] {
    const spans: TextSpan[] = [];
    let index = 0;

    while (index < line.length) {
        if (line[index] !== "`") {
            index += 1;
            continue;
        }

        const spanStart = index;
        while (index < line.length && line[index] === "`") index += 1;
        const tickCount = index - spanStart;
        const delimiter = "`".repeat(tickCount);
        const closeIndex = line.indexOf(delimiter, index);
        if (closeIndex === -1) continue;

        spans.push({ start: spanStart, end: closeIndex + tickCount });
        index = closeIndex + tickCount;
    }

    return spans;
}

function isPositionInSpans(position: number, spans: TextSpan[]): boolean {
    return spans.some((span) => position >= span.start && position < span.end);
}

function hasSafeSkillTokenStart(line: string, tokenStart: number): boolean {
    if (tokenStart === 0) return true;
    const previous = line[tokenStart - 1];
    return previous === " " || previous === "\t";
}

function hasSafeSkillTokenEnd(line: string, tokenEnd: number): boolean {
    if (tokenEnd >= line.length) return true;
    const next = line[tokenEnd];
    return next === " " || next === "\t";
}

function removeInvocationLine(lines: string[], candidate: SkillCandidate): string {
    const argumentLines = [...lines];

    if (candidate.kind === "same-line") {
        argumentLines[candidate.lineIndex] = rewriteSameLineInvocation(
            argumentLines[candidate.lineIndex] ?? "",
            candidate,
        );
        return argumentLines.join("\n");
    }

    if (candidate.inlineArgs) {
        argumentLines[candidate.lineIndex] = candidate.inlineArgs;
    } else {
        argumentLines.splice(candidate.lineIndex, 1);
        removeDuplicateBlankAtJoin(argumentLines, candidate.lineIndex);
    }
    return argumentLines.join("\n");
}

function rewriteSameLineInvocation(line: string, candidate: SameLineSkillCandidate): string {
    const normalized = stripTrailingCarriageReturn(line);
    const before = normalized.slice(0, candidate.tokenStart);
    const after = normalized.slice(candidate.tokenEnd);

    if (after.trim() === "") return `${before}${after}`.trimEnd();
    return `${before}${candidate.skillName}${after}`;
}

function removeDuplicateBlankAtJoin(lines: string[], joinIndex: number): void {
    const previousIndex = joinIndex - 1;
    if (previousIndex < 0 || joinIndex >= lines.length) return;
    if (!isBlankLine(lines[previousIndex]) || !isBlankLine(lines[joinIndex])) return;
    lines.splice(joinIndex, 1);
}

function isBlankLine(line: string | undefined): boolean {
    return stripTrailingCarriageReturn(line ?? "").trim() === "";
}

function stripTrailingCarriageReturn(line: string): string {
    return line.endsWith("\r") ? line.slice(0, -1) : line;
}
