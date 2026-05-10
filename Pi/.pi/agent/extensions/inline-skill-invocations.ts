interface ExtensionAPI {
    on(event: "input", handler: (event: InputEvent) => InputEventResult): void;
    getCommands(): SlashCommandInfo[];
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
    source: "extension" | "prompt" | "skill";
}

const SKILL_COMMAND_PREFIX = "skill:";
const EXPLICIT_SKILL_COMMAND = /^\/skill:([a-z0-9](?:[a-z0-9-]*[a-z0-9])?)(?:[ \t]+(.*))?$/;
const BARE_SKILL_COMMAND = /^\/([a-z0-9](?:[a-z0-9-]*[a-z0-9])?)(?:[ \t]+(.*))?$/;
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

interface SkillCandidate {
    lineIndex: number;
    skillName: string;
    inlineArgs: string;
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

function collectSkillNames(commands: SlashCommandInfo[]): Set<string> {
    const skillNames = new Set<string>();
    for (const command of commands) {
        if (command.source !== "skill") continue;
        if (!command.name.startsWith(SKILL_COMMAND_PREFIX)) continue;
        skillNames.add(command.name.slice(SKILL_COMMAND_PREFIX.length));
    }
    return skillNames;
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
            if (!skillNames.has(skillName)) continue;
            return { lineIndex, skillName, inlineArgs: (explicit[2] ?? "").trim() };
        }

        const bare = BARE_SKILL_COMMAND.exec(trimmed);
        if (!bare) continue;

        const skillName = bare[1] ?? "";
        if (!skillNames.has(skillName)) continue;
        if (nonSkillCommands.has(skillName)) continue;

        return { lineIndex, skillName, inlineArgs: (bare[2] ?? "").trim() };
    }

    return null;
}

function removeInvocationLine(lines: string[], candidate: SkillCandidate): string {
    const argumentLines = [...lines];
    if (candidate.inlineArgs) {
        argumentLines[candidate.lineIndex] = candidate.inlineArgs;
    } else {
        argumentLines.splice(candidate.lineIndex, 1);
        removeDuplicateBlankAtJoin(argumentLines, candidate.lineIndex);
    }
    return argumentLines.join("\n");
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
