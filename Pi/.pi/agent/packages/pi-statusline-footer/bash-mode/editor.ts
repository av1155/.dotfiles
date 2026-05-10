import { CustomEditor } from "@mariozechner/pi-coding-agent";
import { isKeyRelease, matchesKey, truncateToWidth, visibleWidth } from "@mariozechner/pi-tui";
import type { KeybindingsManager } from "@mariozechner/pi-coding-agent/dist/core/keybindings.js";
import type { AutocompleteProvider } from "@mariozechner/pi-tui";
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

function isPrintableInput(data: string): boolean {
    return data.length === 1 && data.charCodeAt(0) >= 32;
}

function matchesEditorBoundaryShortcut(data: string, shortcut: string): boolean {
    return matchesConfiguredShortcut(data, shortcut);
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

    installAutocompleteProvider(provider: AutocompleteProvider): void {
        this.setAutocompleteProvider(provider);
        this.wrappedProviderInstalled = true;
    }

    hasWrappedProvider(): boolean {
        return this.wrappedProviderInstalled;
    }

    getGhostSuggestion(): GhostSuggestion | null {
        return this.isOneOffBashCommandContext() ? this.ghost : null;
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
                oneOffBashCommand &&
                this.keybindingsRef.matches(data, "tui.editor.cursorRight") &&
                this.acceptGhostSuggestion()
            ) {
                return;
            }

            super.handleInput(data);
        }

        if (!this.isOneOffBashCommandContext()) {
            this.clearGhostSuggestion();
            return;
        }

        if (
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
        ) {
            this.scheduleGhostUpdate();
        }
    }

    render(width: number): string[] {
        const oneOffBash = getOneOffBashCommandContext(this.getExpandedText());
        const lines = oneOffBash
            ? this.renderWithHiddenOneOffPrefix(width, oneOffBash)
            : super.render(width);
        if (!oneOffBash) return this.withAutocompleteBottomSpacer(lines);
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
        const ghost = `\x1b[38;5;244m${shownSuffix}\x1b[0m`;
        lines[contentLine] = `${displayText}${cursorBlock}${ghost}${padding}`;
        return this.withAutocompleteBottomSpacer(lines);
    }

    private withAutocompleteBottomSpacer(lines: string[]): string[] {
        const isShowingAutocomplete = Reflect.get(this, "isShowingAutocomplete");
        return typeof isShowingAutocomplete === "function" && isShowingAutocomplete.call(this)
            ? [...lines, ""]
            : lines;
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
        if (text.includes("\n")) return false;

        const cursor = this.getCursor();
        if (cursor.line !== 0 || cursor.col !== text.length) return false;

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
