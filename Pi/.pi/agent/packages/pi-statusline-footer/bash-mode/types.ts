export interface GhostSuggestion {
    value: string;
    source: "project-history" | "global-history" | "git" | "path" | "executable";
}

export interface ExtendedCompletionItem {
    value: string;
    label: string;
    description?: string;
    replacement: string;
    startCol: number;
    endCol: number;
    source: "project-history" | "global-history" | "git" | "path" | "executable";
    score: number;
}
