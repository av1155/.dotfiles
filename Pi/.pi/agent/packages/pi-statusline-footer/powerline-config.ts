import { visibleWidth } from "@mariozechner/pi-tui";
import type {
    ColorValue,
    CustomItemPosition,
    CustomStatusItem,
    PresetDef,
    StatusLinePreset,
    StatusLineSegmentId,
} from "./types.ts";

export interface WidgetLineBudget {
    maxLines: number;
}

export interface PowerlineWidgetBudgets {
    widgets: Record<string, WidgetLineBudget>;
}

export interface PowerlineConfig {
    preset: StatusLinePreset;
    customItems: CustomStatusItem[];
    mouseScroll: boolean;
    fixedEditor: boolean;
    widgetBudgets: PowerlineWidgetBudgets;
}

const DEFAULT_WIDGET_BUDGET_MAX_LINES = 4;
const MAX_WIDGET_BUDGET_LINES = 100;
const WIDGET_BUDGET_CONTAINER_KEYS = new Set(["widgets", "defaultMaxLines", "maxLines"]);

function isRecord(value: unknown): value is Record<string, unknown> {
    return typeof value === "object" && value !== null && !Array.isArray(value);
}

function normalizePreset(
    value: unknown,
    presets: readonly StatusLinePreset[],
): StatusLinePreset | null {
    if (typeof value !== "string") return null;
    const normalized = value.trim().toLowerCase();
    return (presets as readonly string[]).includes(normalized)
        ? (normalized as StatusLinePreset)
        : null;
}

function normalizeCustomItemId(value: unknown): string | null {
    if (typeof value !== "string") return null;
    const normalized = value.trim();
    if (!normalized) return null;
    return /^[a-zA-Z0-9_-]+$/.test(normalized) ? normalized : null;
}

function normalizeWidgetId(value: unknown): string | null {
    if (typeof value !== "string") return null;
    const normalized = value.trim();
    return normalized.length > 0 ? normalized : null;
}

function normalizeLineCount(value: unknown): number | null {
    let count: number;
    if (typeof value === "number") {
        count = value;
    } else if (typeof value === "string" && /^\d+$/.test(value.trim())) {
        count = Number(value.trim());
    } else {
        return null;
    }

    if (!Number.isFinite(count)) return null;
    const normalized = Math.floor(count);
    if (normalized < 1) return null;
    return Math.min(normalized, MAX_WIDGET_BUDGET_LINES);
}

function normalizeWidgetBudgetEntry(
    raw: unknown,
    defaultMaxLines: number = DEFAULT_WIDGET_BUDGET_MAX_LINES,
): WidgetLineBudget | null {
    if (raw === false || raw === null) return null;
    if (raw === true || raw === undefined) return { maxLines: defaultMaxLines };

    const directLineCount = normalizeLineCount(raw);
    if (directLineCount !== null) return { maxLines: directLineCount };

    if (!isRecord(raw)) return null;
    if (raw.enabled === false) return null;

    return {
        maxLines: normalizeLineCount(raw.maxLines ?? raw.lines ?? raw.limit) ?? defaultMaxLines,
    };
}

function addWidgetBudgetEntry(
    widgets: Record<string, WidgetLineBudget>,
    id: unknown,
    raw: unknown,
    defaultMaxLines: number,
): void {
    const widgetId = normalizeWidgetId(id);
    if (!widgetId) return;

    const budget = normalizeWidgetBudgetEntry(raw, defaultMaxLines);
    if (budget) widgets[widgetId] = budget;
}

function normalizeWidgetBudgetEntries(raw: unknown): Record<string, WidgetLineBudget> {
    const widgets: Record<string, WidgetLineBudget> = {};
    if (!isRecord(raw)) return widgets;

    const defaultMaxLines =
        normalizeLineCount(raw.defaultMaxLines ?? raw.maxLines) ?? DEFAULT_WIDGET_BUDGET_MAX_LINES;
    const configuredWidgets = raw.widgets;

    if (Array.isArray(configuredWidgets)) {
        for (const widgetId of configuredWidgets) {
            addWidgetBudgetEntry(widgets, widgetId, true, defaultMaxLines);
        }
        return widgets;
    }

    if (isRecord(configuredWidgets)) {
        for (const [widgetId, entry] of Object.entries(configuredWidgets)) {
            addWidgetBudgetEntry(widgets, widgetId, entry, defaultMaxLines);
        }
        return widgets;
    }

    for (const [widgetId, entry] of Object.entries(raw)) {
        if (WIDGET_BUDGET_CONTAINER_KEYS.has(widgetId)) continue;
        addWidgetBudgetEntry(widgets, widgetId, entry, defaultMaxLines);
    }

    return widgets;
}

function normalizeWidgetBudgets(raw: unknown): PowerlineWidgetBudgets {
    return { widgets: normalizeWidgetBudgetEntries(raw) };
}

function normalizeCustomItemPosition(value: unknown): CustomItemPosition {
    if (value === "left" || value === "right" || value === "secondary") return value;
    return "right";
}

function normalizeCustomColor(value: unknown): ColorValue | undefined {
    if (typeof value !== "string") return undefined;
    const normalized = value.trim();
    return normalized ? (normalized as ColorValue) : undefined;
}

function normalizeCustomPrefix(value: unknown): string | undefined {
    if (typeof value !== "string") return undefined;
    const normalized = value.trim();
    return normalized ? normalized : undefined;
}

function normalizeCustomStatusItem(raw: unknown, idOverride?: string): CustomStatusItem | null {
    if (!isRecord(raw)) return null;
    const id = normalizeCustomItemId(idOverride ?? raw.id);
    if (!id) return null;

    const statusKey =
        typeof raw.statusKey === "string" && raw.statusKey.trim() ? raw.statusKey.trim() : id;

    return {
        id,
        statusKey,
        position: normalizeCustomItemPosition(raw.position),
        color: normalizeCustomColor(raw.color),
        prefix: normalizeCustomPrefix(raw.prefix),
        hideWhenMissing: raw.hideWhenMissing !== false,
        excludeFromExtensionStatuses: raw.excludeFromExtensionStatuses !== false,
    };
}

function normalizeCustomItems(raw: unknown): CustomStatusItem[] {
    const normalized: CustomStatusItem[] = [];

    if (Array.isArray(raw)) {
        for (const entry of raw) {
            const item = normalizeCustomStatusItem(entry);
            if (item) normalized.push(item);
        }
    } else if (isRecord(raw)) {
        for (const [id, entry] of Object.entries(raw)) {
            const item = normalizeCustomStatusItem(entry, id);
            if (item) normalized.push(item);
        }
    }

    const deduped = new Map<string, CustomStatusItem>();
    for (const item of normalized) {
        deduped.set(item.id, item);
    }

    return [...deduped.values()];
}

export function parsePowerlineConfig(
    value: unknown,
    presets: readonly StatusLinePreset[],
): PowerlineConfig {
    const defaultConfig: PowerlineConfig = {
        preset: "default",
        customItems: [],
        mouseScroll: true,
        fixedEditor: true,
        widgetBudgets: { widgets: {} },
    };

    const directPreset = normalizePreset(value, presets);
    if (directPreset) return { ...defaultConfig, preset: directPreset };

    if (!isRecord(value)) return defaultConfig;

    return {
        preset: normalizePreset(value.preset, presets) ?? defaultConfig.preset,
        customItems: normalizeCustomItems(value.customItems),
        mouseScroll: value.mouseScroll !== false,
        fixedEditor: value.fixedEditor !== false,
        widgetBudgets: normalizeWidgetBudgets(value.widgetBudgets),
    };
}

export function mergeSegmentsWithCustomItems(
    presetDef: PresetDef,
    customItems: readonly CustomStatusItem[],
): {
    leftSegments: StatusLineSegmentId[];
    rightSegments: StatusLineSegmentId[];
    secondarySegments: StatusLineSegmentId[];
} {
    const left: StatusLineSegmentId[] = [...presetDef.leftSegments];
    const right: StatusLineSegmentId[] = [...presetDef.rightSegments];
    const secondary: StatusLineSegmentId[] = [...(presetDef.secondarySegments ?? [])];

    for (const item of customItems) {
        const segmentId: StatusLineSegmentId = `custom:${item.id}`;
        if (item.position === "left") left.push(segmentId);
        else if (item.position === "secondary") secondary.push(segmentId);
        else right.push(segmentId);
    }

    return { leftSegments: left, rightSegments: right, secondarySegments: secondary };
}

export function nextPowerlineSettingWithPreset(
    existingPowerlineSetting: unknown,
    preset: StatusLinePreset,
): unknown {
    if (!isRecord(existingPowerlineSetting)) {
        return preset;
    }
    return { ...existingPowerlineSetting, preset };
}

export function nextPowerlineSettingWithOptions(
    existingPowerlineSetting: unknown,
    updates: Partial<Pick<PowerlineConfig, "mouseScroll" | "fixedEditor">>,
    currentPreset: StatusLinePreset,
): unknown {
    if (!isRecord(existingPowerlineSetting)) {
        return { preset: currentPreset, ...updates };
    }
    return { ...existingPowerlineSetting, ...updates };
}

export function collectHiddenExtensionStatusKeys(
    customItems: readonly CustomStatusItem[],
): Set<string> {
    const hidden = new Set<string>();
    for (const item of customItems) {
        if (item.excludeFromExtensionStatuses) hidden.add(item.statusKey);
    }
    return hidden;
}

export function isNotificationExtensionStatus(value: string): boolean {
    return value.trimStart().startsWith("[");
}

export function getNotificationExtensionStatuses(
    statuses: ReadonlyMap<string, string>,
    hiddenKeys: ReadonlySet<string>,
): string[] {
    const notifications: string[] = [];
    for (const [statusKey, value] of statuses.entries()) {
        if (hiddenKeys.has(statusKey) || !value || !isNotificationExtensionStatus(value)) {
            continue;
        }
        notifications.push(value);
    }
    return notifications;
}

export function normalizeExtensionStatusValue(value: string): string | null {
    if (!value || visibleWidth(value) <= 0) {
        return null;
    }

    const stripped = value.replace(/(\x1b\[[0-9;]*m|\s|·|[|])+$/, "");
    return visibleWidth(stripped) > 0 ? stripped : null;
}

export function normalizeCompactExtensionStatus(value: string): string | null {
    if (isNotificationExtensionStatus(value)) {
        return null;
    }

    return normalizeExtensionStatusValue(value);
}
