export type CompletionSource =
    | "project-history"
    | "global-history"
    | "git"
    | "path"
    | "executable"
    | "skill";

export interface GhostSuggestion {
    value: string;
    source: CompletionSource;
    color?: string;
}

export interface ExtendedCompletionItem {
    value: string;
    label: string;
    description?: string;
    replacement: string;
    startCol: number;
    endCol: number;
    source: CompletionSource;
    score: number;
}
