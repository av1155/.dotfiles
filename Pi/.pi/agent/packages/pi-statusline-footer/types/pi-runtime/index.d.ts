// Local type shims for Pi runtime extension packages.
// These declarations are intentionally minimal: Pi loads these modules at
// runtime, but this dotfiles repo does not vendor Pi's package dependencies.

interface PiProcessLike {
    env: Record<string, string | undefined>;
    cwd(): string;
    stdout: { write(chunk: string): void };
    once(event: string, listener: (...args: any[]) => void): void;
    removeListener(event: string, listener: (...args: any[]) => void): void;
}

declare const process: PiProcessLike;

declare module "node:fs" {
    export const readFileSync: any;
    export const writeFileSync: any;
    export const existsSync: any;
    export const mkdirSync: any;
    export const readdirSync: any;
}

declare module "node:child_process" {
    export const spawn: any;
    export const spawnSync: any;
}

declare module "node:path" {
    export const basename: any;
    export const dirname: any;
    export const isAbsolute: any;
    export const join: any;
    export const resolve: any;
}

declare module "node:os" {
    export const homedir: any;
}

declare module "node:url" {
    export const fileURLToPath: any;
}

declare module "@mariozechner/pi-coding-agent" {
    export type ThemeColor = string;
    export type Theme = any;
    export type ExtensionAPI = any;
    export type ExtensionContext = any;
    export type ReadonlyFooterDataProvider = any;

    export const copyToClipboard: any;
    export const createLocalBashOperations: any;

    export class CustomEditor {
        protected tui: any;
        constructor(tui: any, theme: any, keybindings: any);
        handleInput(data: string): void;
        render(width: number): string[];
        setAutocompleteProvider(provider: any): void;
        getExpandedText(): string;
        getText(): string;
        setText(text: string): void;
        getCursor(): { line: number; col: number };
    }
}

declare module "@mariozechner/pi-coding-agent/dist/core/keybindings.js" {
    export type KeybindingsManager = any;
}

declare module "@mariozechner/pi-ai" {
    export type AssistantMessage = any;
    export type Context = any;
    export const complete: any;
}

declare module "@mariozechner/pi-tui" {
    export type AutocompleteItem = any;
    export type AutocompleteProvider = any;
    export type AutocompleteSuggestions = any;

    export const TUI_KEYBINDINGS: any;
    export const isKeyRelease: any;
    export const matchesKey: any;
    export const truncateToWidth: any;
    export const visibleWidth: any;

    export class Text {
        constructor(text?: string, paddingX?: number, paddingY?: number, customBgFn?: any);
        setText(text: string): void;
        render(width: number): string[];
    }
}

declare module "@earendil-works/pi-tui" {
    export const truncateToWidth: any;
    export const visibleWidth: any;
}
