// @ts-nocheck
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
type UserMessageComponentCtor = {
    prototype: {
        render?: RenderFunction;
        [key: symbol]: unknown;
    };
};

const PATCH_FLAG = Symbol.for("av:pi-user-message-style-patch");
const PATCH_VERSION = 3;
const STATE_KEY = Symbol.for("av:pi-user-message-style-state");
const USER_LABEL = " User ";
const USER_LABEL_FG = "\x1b[38;2;215;119;87m"; // #D77757
const RESET = "\x1b[0m";
const DEFAULT_BG = "\x1b[49m";
const SOURCE_BORDER_COLOR = "\x1b[38;5;238m";
const BORDER_FG = "\x1b[38;2;73;77;100m"; // catppuccin-macchiato surface1 (#494d64)
const ANSI_RE = /\x1b\[[0-9;?]*[ -/]*[@-~]/g;
const FALLBACK_USER_BG = "#2B2E3F";

type PatchState = {
    userLabelFg: string;
    userMessageBg: string;
};

type PatchMeta = {
    wrapped?: RenderFunction;
    version?: number;
};

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

function getPatchState(): PatchState {
    const globals = globalThis as typeof globalThis & { [STATE_KEY]?: PatchState };
    globals[STATE_KEY] = {
        userLabelFg: USER_LABEL_FG,
        userMessageBg: resolveConfiguredUserMessageBg(),
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

function styleUserLabel(line: string): string {
    const state = getPatchState();
    return recolorBorder(
        line.replace(
            USER_LABEL,
            `${DEFAULT_BG}${state.userLabelFg}${USER_LABEL}${RESET}${DEFAULT_BG}`,
        ),
    );
}

function styleUserMessageBody(line: string): string {
    const state = getPatchState();
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

function styleUserMessageLine(line: string): string {
    const plain = stripAnsi(line);
    if (plain.includes("╭")) return styleUserLabel(line);
    if (plain.includes("╰")) return recolorBorder(line);
    if (plain.includes("│")) return styleUserMessageBody(line);
    return line;
}

function installPatch(UserMessageComponent: UserMessageComponentCtor): void {
    const proto = UserMessageComponent.prototype;
    if (typeof proto.render !== "function") return;

    const meta = proto[PATCH_FLAG] as PatchMeta | boolean | undefined;
    if (typeof meta === "object" && meta.wrapped === proto.render && meta.version === PATCH_VERSION)
        return;

    const originalRender = proto.render;
    const wrapped: RenderFunction = function patchedUserMessageStyle(width: number): string[] {
        const lines = originalRender.call(this, width);
        return lines.map(styleUserMessageLine);
    };

    proto.render = wrapped;
    proto[PATCH_FLAG] = { wrapped, version: PATCH_VERSION } satisfies PatchMeta;
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
