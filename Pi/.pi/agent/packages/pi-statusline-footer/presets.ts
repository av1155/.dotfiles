import type { ColorScheme, PresetDef, StatusLinePreset } from "./types.js";
import { getDefaultColors } from "./theme.js";

const DEFAULT_COLORS: ColorScheme = getDefaultColors();

const BASELINE_PRESET: PresetDef = {
    leftSegments: [
        "model",
        "thinking",
        "shell_mode",
        "path",
        "git",
        "context_pct",
        "cache_read",
        "cost",
    ],
    rightSegments: [],
    secondarySegments: ["extension_statuses"],
    separator: "powerline-thin",
    colors: DEFAULT_COLORS,
    segmentOptions: {
        model: { showThinkingLevel: false },
        path: { mode: "basename" },
        git: { showBranch: true, showStaged: true, showUnstaged: true, showUntracked: true },
    },
};

export const PRESETS: Record<StatusLinePreset, PresetDef> = {
    default: BASELINE_PRESET,
    custom: BASELINE_PRESET,
};

export function getPreset(name: StatusLinePreset): PresetDef {
    return PRESETS[name] ?? PRESETS.default;
}
