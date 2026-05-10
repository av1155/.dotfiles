const WORKED_DURATION_KEY = "_piClaudeStyleWorkedDurationMs";
const WORKED_DURATION_MARKER = "Worked for";
const WORKED_LINE_RE = /^✻ Worked for [^\r\n]+$/;
const ANSI_RE = /\x1b(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~]|\][^\x07]*(?:\x07|\x1b\\))/g;
const RENDER_PATCH_FLAG = Symbol.for("pi-claude-style-interop:final-duration-row-patch");
const RENDER_PATCH_VERSION = 1;

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

type RenderPatchMeta = {
    wrapped?: UpdateContentFunction;
    version?: number;
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

let componentPromise: Promise<AssistantMessageComponentCtor | null> | null = null;

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

async function installAssistantDurationPatch(): Promise<void> {
    componentPromise ??= loadAssistantMessageComponent();
    const AssistantMessageComponent = await componentPromise;
    if (AssistantMessageComponent) {
        installFinalDurationRowPatch(AssistantMessageComponent);
    }
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
    await installAssistantDurationPatch();
    pi.on("session_start", installAssistantDurationPatch);
    pi.on("turn_start", installAssistantDurationPatch);
    pi.on("message_end", async (event) => {
        cleanAssistantMessage(event.message);
    });
}
