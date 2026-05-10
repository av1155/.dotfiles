const WORKED_DURATION_KEY = "_piClaudeStyleWorkedDurationMs";
const WORKED_DURATION_MARKER = "Worked for";
const WORKED_LINE_RE = /^✻ Worked for [^\r\n]+$/;
const ANSI_RE = /\x1b(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~]|\][^\x07]*(?:\x07|\x1b\\))/g;

interface ExtensionAPI {
    on(event: "message_end", handler: (event: MessageEndEvent) => Promise<void> | void): void;
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

function isRecord(value: unknown): value is Record<string, unknown> {
    return typeof value === "object" && value !== null;
}

function isTextBlock(value: unknown): value is AssistantTextBlock {
    return isRecord(value) && value.type === "text" && typeof value.text === "string";
}

export function stripAnsi(text: string): string {
    return text.replace(ANSI_RE, "");
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

export default function piClaudeStyleInterop(pi: ExtensionAPI): void {
    pi.on("message_end", async (event) => {
        cleanAssistantMessage(event.message);
    });
}
