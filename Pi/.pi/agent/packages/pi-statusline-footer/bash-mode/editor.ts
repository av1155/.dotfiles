import { CustomEditor } from "@mariozechner/pi-coding-agent";
import { isKeyRelease, truncateToWidth, visibleWidth } from "@mariozechner/pi-tui";
import type { KeybindingsManager } from "@mariozechner/pi-coding-agent/dist/core/keybindings.js";
import type { AutocompleteProvider } from "@mariozechner/pi-tui";
import { ansi } from "../colors.js";
import { matchesConfiguredShortcut } from "../shortcuts.ts";
import { getOneOffBashCommandContext, type OneOffBashCommandContext } from "./completion.ts";
import type { GhostSuggestion } from "./types.ts";

interface EditorBoundaryShortcuts {
    start: string;
    end: string;
}

interface OneOffShellEditorOptions {
    keybindings: KeybindingsManager;
    onEditorSubmit?: () => void;
    editorBoundaryShortcuts?: EditorBoundaryShortcuts;
    resolveGhostSuggestion: (text: string, signal: AbortSignal) => Promise<GhostSuggestion | null>;
}

const DEFAULT_EDITOR_BOUNDARY_SHORTCUTS: EditorBoundaryShortcuts = {
    start: "super+shift+up",
    end: "super+shift+down",
};
const DEFAULT_GHOST_COLOR = "\x1b[38;5;244m";

interface TrailingSkillToken {
    start: number;
    prefix: string;
}

function isPrintableInput(data: string): boolean {
    return data.length === 1 && data.charCodeAt(0) >= 32;
}

function matchesEditorBoundaryShortcut(data: string, shortcut: string): boolean {
    return matchesConfiguredShortcut(data, shortcut);
}

function findTrailingSkillToken(text: string): TrailingSkillToken | null {
    let tokenStart = text.length;
    while (tokenStart > 0 && !/\s/.test(text[tokenStart - 1] ?? "")) {
        tokenStart -= 1;
    }

    const token = text.slice(tokenStart);
    if (tokenStart <= 0 || !/^\/[a-z0-9-]*$/.test(token)) return null;
    return { start: tokenStart, prefix: token.slice(1) };
}

function hexToRgb(hex: string): [number, number, number] | null {
    const value = hex.trim().replace(/^#/, "");
    if (!/^[0-9a-f]{6}$/i.test(value)) return null;
    return [
        parseInt(value.slice(0, 2), 16),
        parseInt(value.slice(2, 4), 16),
        parseInt(value.slice(4, 6), 16),
    ];
}

function getGhostColorAnsi(color: string | undefined): string {
    if (!color) return DEFAULT_GHOST_COLOR;
    const rgb = color.startsWith("#") ? hexToRgb(color) : null;
    return rgb ? ansi.getFgAnsi(...rgb) : color;
}

export class OneOffShellEditor extends CustomEditor {
    private readonly keybindingsRef: KeybindingsManager;
    private readonly optionsRef: OneOffShellEditorOptions;
    private wrappedProviderInstalled = false;
    private ghost: GhostSuggestion | null = null;
    private ghostAbort: AbortController | null = null;
    private ghostToken = 0;

    constructor(
        tui: any,
        theme: any,
        keybindings: KeybindingsManager,
        options: OneOffShellEditorOptions,
    ) {
        super(tui, theme, keybindings);
        this.keybindingsRef = keybindings;
        this.optionsRef = options;
    }

    setAutocompleteProvider(provider: AutocompleteProvider): void {
        super.setAutocompleteProvider(provider);
        this.wrappedProviderInstalled = false;
    }

    installAutocompleteProvider(provider: AutocompleteProvider): void {
        this.setAutocompleteProvider(provider);
        this.wrappedProviderInstalled = true;
    }

    hasWrappedProvider(): boolean {
        return this.wrappedProviderInstalled;
    }

    getGhostSuggestion(): GhostSuggestion | null {
        return this.isRenderableGhostSuggestion() ? this.ghost : null;
    }

    refreshGhostSuggestion(): void {
        this.scheduleGhostUpdate();
    }

    clearGhostSuggestion(): void {
        this.ghostAbort?.abort();
        this.ghostAbort = null;
        this.ghost = null;
    }

    handleInput(data: string): void {
        const pasteInProgress =
            data.includes("\x1b[200~") || Reflect.get(this, "isInPaste") === true;
        if (pasteInProgress) {
            super.handleInput(data);
            if (Reflect.get(this, "isInPaste") === true) {
                return;
            }
        } else {
            const oneOffBashCommand = this.isOneOffBashCommandContext();
            const editorBoundaryShortcuts =
                this.optionsRef.editorBoundaryShortcuts ?? DEFAULT_EDITOR_BOUNDARY_SHORTCUTS;

            if (
                !isKeyRelease(data) &&
                matchesEditorBoundaryShortcut(data, editorBoundaryShortcuts.start)
            ) {
                this.moveCursorToEditorBoundary("start");
                return;
            }

            if (
                !isKeyRelease(data) &&
                matchesEditorBoundaryShortcut(data, editorBoundaryShortcuts.end)
            ) {
                this.moveCursorToEditorBoundary("end");
                return;
            }

            if (oneOffBashCommand && this.keybindingsRef.matches(data, "tui.input.tab")) {
                this.acceptGhostSuggestion();
                return;
            }

            if (
                !oneOffBashCommand &&
                this.keybindingsRef.matches(data, "tui.input.tab") &&
                this.isPrefixedSkillGhostSuggestion() &&
                this.acceptGhostSuggestion()
            ) {
                return;
            }

            if (
                (oneOffBashCommand || this.isPrefixedSkillGhostSuggestion()) &&
                this.keybindingsRef.matches(data, "tui.editor.cursorRight") &&
                this.acceptGhostSuggestion()
            ) {
                return;
            }

            super.handleInput(data);
        }

        if (this.shouldScheduleGhostUpdate(data, pasteInProgress)) {
            this.scheduleGhostUpdate();
        }
    }

    render(width: number): string[] {
        const text = this.getExpandedText();
        const oneOffBash = getOneOffBashCommandContext(text);
        const lines = oneOffBash
            ? this.renderWithHiddenOneOffPrefix(width, oneOffBash)
            : super.render(width);

        if (!this.ghost) return this.withAutocompleteBottomSpacer(lines);
        if (this.ghost.source === "skill") {
            return this.renderSkillGhostSuffix(lines, width, text);
        }
        if (!oneOffBash) return this.withAutocompleteBottomSpacer(lines);
        return this.renderOneOffGhostSuffix(lines, width, oneOffBash);
    }

    private withAutocompleteBottomSpacer(lines: string[]): string[] {
        const isShowingAutocomplete = Reflect.get(this, "isShowingAutocomplete");
        return typeof isShowingAutocomplete === "function" && isShowingAutocomplete.call(this)
            ? [...lines, ""]
            : lines;
    }

    private renderOneOffGhostSuffix(
        lines: string[],
        width: number,
        oneOffBash: OneOffBashCommandContext,
    ): string[] {
        if (!this.ghost) return this.withAutocompleteBottomSpacer(lines);

        const text = this.getText();
        if (text.includes("\n")) return this.withAutocompleteBottomSpacer(lines);
        const cursor = this.getCursor();
        if (cursor.line !== 0 || cursor.col !== text.length) {
            return this.withAutocompleteBottomSpacer(lines);
        }
        if (!this.ghost.value.startsWith(text) || this.ghost.value === text) {
            return this.withAutocompleteBottomSpacer(lines);
        }
        if (lines.length < 3) return this.withAutocompleteBottomSpacer(lines);

        const displayText = text.slice(oneOffBash.offset);
        const displayGhostValue = this.ghost.value.slice(oneOffBash.offset);
        const suffix = displayGhostValue.slice(displayText.length);
        const contentLine = 1;
        const cursorBlock = "\x1b[7m \x1b[0m";
        const availableWidth = Math.max(0, width - visibleWidth(displayText) - 1);
        if (availableWidth === 0) return this.withAutocompleteBottomSpacer(lines);

        const shownSuffix = truncateToWidth(suffix, availableWidth, "", true);
        if (!shownSuffix) return this.withAutocompleteBottomSpacer(lines);

        const padding = " ".repeat(
            Math.max(0, width - visibleWidth(displayText) - 1 - visibleWidth(shownSuffix)),
        );
        const ghost = `${getGhostColorAnsi(this.ghost.color)}${shownSuffix}${ansi.reset}`;
        lines[contentLine] = `${displayText}${cursorBlock}${ghost}${padding}`;
        return this.withAutocompleteBottomSpacer(lines);
    }

    private renderSkillGhostSuffix(lines: string[], width: number, text: string): string[] {
        if (!this.ghost || !this.isPrefixedSkillGhostSuggestion()) {
            return this.withAutocompleteBottomSpacer(lines);
        }

        const currentVisualLine = this.getCurrentVisualLineInfo(width);
        if (!currentVisualLine) return this.withAutocompleteBottomSpacer(lines);
        if (
            currentVisualLine.renderedLineIndex < 1 ||
            currentVisualLine.renderedLineIndex >= lines.length
        ) {
            return this.withAutocompleteBottomSpacer(lines);
        }

        const cursor = this.getCursor();
        const editorLines = this.getEditorLines();
        const currentLine = editorLines[cursor.line] ?? "";
        const displayText = currentLine.slice(currentVisualLine.startCol, cursor.col);
        const suffix = this.ghost.value.slice(text.length);
        const { contentWidth, leftPadding, rightPadding } = this.getRenderPadding(width);
        const cursorBlock = "\x1b[7m \x1b[0m";
        const availableWidth = Math.max(0, contentWidth - visibleWidth(displayText) - 1);
        if (availableWidth === 0) return this.withAutocompleteBottomSpacer(lines);

        const shownSuffix = truncateToWidth(suffix, availableWidth, "", true);
        if (!shownSuffix) return this.withAutocompleteBottomSpacer(lines);

        const padding = " ".repeat(
            Math.max(0, contentWidth - visibleWidth(displayText) - 1 - visibleWidth(shownSuffix)),
        );
        const ghost = `${getGhostColorAnsi(this.ghost.color)}${shownSuffix}${ansi.reset}`;
        lines[currentVisualLine.renderedLineIndex] =
            `${leftPadding}${displayText}${cursorBlock}${ghost}${padding}${rightPadding}`;
        return this.withAutocompleteBottomSpacer(lines);
    }

    private getEditorLines(): string[] {
        const getLines = Reflect.get(this, "getLines");
        if (typeof getLines === "function") {
            const lines = getLines.call(this);
            if (Array.isArray(lines) && lines.every((line) => typeof line === "string")) {
                return lines;
            }
        }
        return this.getText().split("\n");
    }

    private getEditorPaddingX(): number {
        const getPaddingX = Reflect.get(this, "getPaddingX");
        if (typeof getPaddingX !== "function") return 0;
        const padding = getPaddingX.call(this);
        return typeof padding === "number" && Number.isFinite(padding) ? padding : 0;
    }

    private getRenderPadding(width: number): {
        contentWidth: number;
        leftPadding: string;
        rightPadding: string;
    } {
        const maxPadding = Math.max(0, Math.floor((width - 1) / 2));
        const paddingX = Math.min(this.getEditorPaddingX(), maxPadding);
        const contentWidth = Math.max(1, width - paddingX * 2);
        const padding = " ".repeat(paddingX);
        return { contentWidth, leftPadding: padding, rightPadding: padding };
    }

    private getCurrentVisualLineInfo(
        width: number,
    ): { renderedLineIndex: number; startCol: number } | null {
        const buildVisualLineMap = Reflect.get(this, "buildVisualLineMap");
        const findCurrentVisualLine = Reflect.get(this, "findCurrentVisualLine");
        if (
            typeof buildVisualLineMap !== "function" ||
            typeof findCurrentVisualLine !== "function"
        ) {
            return null;
        }

        const lastWidth = Reflect.get(this, "lastWidth");
        const layoutWidth = typeof lastWidth === "number" && lastWidth > 0 ? lastWidth : width;
        const visualLines = buildVisualLineMap.call(this, layoutWidth);
        if (!Array.isArray(visualLines)) return null;
        const visualLineIndex = findCurrentVisualLine.call(this, visualLines);
        if (typeof visualLineIndex !== "number" || visualLineIndex < 0) return null;

        const scrollOffset = Reflect.get(this, "scrollOffset");
        const visibleOffset = typeof scrollOffset === "number" ? scrollOffset : 0;
        const visualLine = visualLines[visualLineIndex] as Record<string, unknown> | undefined;
        const startCol = typeof visualLine?.startCol === "number" ? visualLine.startCol : 0;
        return { renderedLineIndex: 1 + visualLineIndex - visibleOffset, startCol };
    }

    private shouldScheduleGhostUpdate(data: string, pasteInProgress: boolean): boolean {
        return (
            pasteInProgress ||
            isPrintableInput(data) ||
            this.keybindingsRef.matches(data, "tui.editor.deleteCharBackward") ||
            this.keybindingsRef.matches(data, "tui.editor.deleteCharForward") ||
            this.keybindingsRef.matches(data, "tui.editor.deleteWordBackward") ||
            this.keybindingsRef.matches(data, "tui.editor.deleteWordForward") ||
            this.keybindingsRef.matches(data, "tui.editor.deleteToLineStart") ||
            this.keybindingsRef.matches(data, "tui.editor.deleteToLineEnd") ||
            this.keybindingsRef.matches(data, "tui.input.newLine") ||
            this.keybindingsRef.matches(data, "tui.editor.cursorLeft") ||
            this.keybindingsRef.matches(data, "tui.editor.cursorRight")
        );
    }

    private isRenderableGhostSuggestion(): boolean {
        if (!this.ghost) return false;
        if (this.ghost.source === "skill") return this.isPrefixedSkillGhostSuggestion();

        const text = this.getExpandedText();
        return (
            this.isOneOffBashCommandContext() &&
            !text.includes("\n") &&
            this.isCursorAtEndOfText(text) &&
            this.ghost.value.startsWith(text) &&
            this.ghost.value !== text
        );
    }

    private isPrefixedSkillGhostSuggestion(): boolean {
        if (!this.ghost || this.ghost.source !== "skill") return false;
        const text = this.getExpandedText();
        const token = findTrailingSkillToken(text);
        return (
            token !== null &&
            token.prefix.length > 0 &&
            this.isCursorAtEndOfText(text) &&
            this.ghost.value.startsWith(text) &&
            this.ghost.value !== text
        );
    }

    private isCursorAtEndOfText(text: string): boolean {
        const cursor = this.getCursor();
        const lines = text.split("\n");
        const lastLineIndex = Math.max(0, lines.length - 1);
        return cursor.line === lastLineIndex && cursor.col === (lines[lastLineIndex] ?? "").length;
    }

    private isOneOffBashCommandContext(): boolean {
        return getOneOffBashCommandContext(this.getExpandedText()) !== null;
    }

    private renderWithHiddenOneOffPrefix(
        width: number,
        oneOffBash: OneOffBashCommandContext,
    ): string[] {
        const stateCandidate = Reflect.get(this, "state");
        if (!stateCandidate || typeof stateCandidate !== "object") {
            return super.render(width);
        }

        const state = stateCandidate as Record<string, unknown>;
        const lines = Reflect.get(state, "lines");
        if (!Array.isArray(lines) || lines.some((line) => typeof line !== "string")) {
            return super.render(width);
        }

        const originalLines = [...lines] as string[];
        const originalCursorLine = Reflect.get(state, "cursorLine");
        const originalCursorCol = Reflect.get(state, "cursorCol");

        const displayLines = [...originalLines];
        displayLines[0] = displayLines[0].slice(oneOffBash.offset);
        Reflect.set(state, "lines", displayLines);
        if (originalCursorLine === 0 && typeof originalCursorCol === "number") {
            Reflect.set(state, "cursorCol", Math.max(0, originalCursorCol - oneOffBash.offset));
        }

        try {
            return super.render(width);
        } finally {
            Reflect.set(state, "lines", originalLines);
            Reflect.set(state, "cursorLine", originalCursorLine);
            Reflect.set(state, "cursorCol", originalCursorCol);
        }
    }

    private moveCursorToEditorBoundary(position: "start" | "end"): void {
        const state = Reflect.get(this, "state");
        const lines = state && typeof state === "object" ? Reflect.get(state, "lines") : null;
        if (!state || typeof state !== "object" || !Array.isArray(lines)) {
            throw new Error("Editor cursor state is unavailable");
        }

        const editorState = state as Record<string, unknown>;
        if (position === "start") {
            Reflect.set(editorState, "cursorLine", 0);
            Reflect.set(editorState, "cursorCol", 0);
        } else {
            const lastLine = Math.max(0, lines.length - 1);
            Reflect.set(editorState, "cursorLine", lastLine);
            Reflect.set(
                editorState,
                "cursorCol",
                typeof lines[lastLine] === "string" ? lines[lastLine].length : 0,
            );
        }

        Reflect.set(this, "lastAction", null);
        Reflect.set(this, "preferredVisualCol", null);
        Reflect.set(this, "snappedFromCursorCol", null);
        this.tui.requestRender();
    }

    private acceptGhostSuggestion(): boolean {
        if (!this.ghost) return false;
        const text = this.getExpandedText();
        if (this.ghost.source !== "skill" && text.includes("\n")) return false;
        if (!this.isCursorAtEndOfText(text)) return false;
        if (!this.ghost.value.startsWith(text) || this.ghost.value === text) return false;

        this.setText(this.ghost.value);
        this.clearGhostSuggestion();
        return true;
    }

    private scheduleGhostUpdate(): void {
        const text = this.getExpandedText();
        const currentToken = ++this.ghostToken;
        this.ghostAbort?.abort();

        const controller = new AbortController();
        this.ghostAbort = controller;
        this.optionsRef
            .resolveGhostSuggestion(text, controller.signal)
            .then((ghost) => {
                if (controller.signal.aborted || currentToken !== this.ghostToken) return;
                this.ghost = ghost;
                this.tui.requestRender();
            })
            .catch((error) => {
                if (error instanceof Error && error.message === "aborted") return;
                console.debug("[powerline-footer] Failed to resolve bash ghost suggestion:", error);
            });
    }
}
