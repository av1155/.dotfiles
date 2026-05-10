import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";
import type { SegmentContext } from "./types.js";

const SEP = " │ ";
const CACHE_ICON = "󰆼";
const TIMER_ICON = "⏱";
const MODE_SHORTCUT_LABEL = "(ctrl+alt+p to cycle)";
const PLAN_MODE_LABEL = "⏸ plan mode on";
const AUTO_MODE_LABEL = "⏵⏵ auto mode on";
const PLAN_MODE_COLOR = "#5FAFAF";
const AUTO_MODE_COLOR = "#FFD700";
const STATUS_HEALTHY = "healthy";
const STATUS_PARTIAL = "partial";
const STATUS_INACTIVE = "inactive";
const BAND_WARN = "warn";
const BAND_ERROR = "error";
const PROVIDER_OPENAI_CODEX = "openai-codex";
const PROVIDER_GITHUB_COPILOT = "github-copilot";
const SUBSCRIPTION_BACKED_OAUTH_PROVIDERS = new Set([
    PROVIDER_OPENAI_CODEX,
    PROVIDER_GITHUB_COPILOT,
]);
const LOCAL_PROVIDER_PATTERN = /ollama|lmstudio|lm-studio|vllm|local/i;

const COLORS = {
    text: "#949494",
    less: "#595A61",
    contextHealthyBg: "#3E4E4C",
    contextHealthyFg: "#A6E3A1",
    contextWarnBg: "#514F50",
    contextWarnFg: "#F9E2AF",
    contextErrorBg: "#51394D",
    contextErrorFg: "#F38BA8",
    gitModified: "#F9E2AF",
    gitUntracked: "#93E2D5",
    gitGood: "#A6E3A1",
    red: "#F38BA8",
} as const;

const RAINBOW_COLORS = [
    "#b281d6",
    "#d787af",
    "#febc38",
    "#e4c00f",
    "#89d281",
    "#00afaf",
    "#178fb9",
    "#b281d6",
] as const;

type InfraStatusKind = typeof STATUS_HEALTHY | typeof STATUS_PARTIAL | typeof STATUS_INACTIVE;
type InfraStatus = { kind: InfraStatusKind; label: string; count?: string };

type ContextBand = typeof STATUS_HEALTHY | typeof BAND_WARN | typeof BAND_ERROR;

export function renderStatuslineFooter(width: number, ctx: SegmentContext): string {
    const budget = Math.max(20, width - 2);
    const candidateSets = buildCandidates(budget, ctx);

    for (const segments of candidateSets) {
        const line = joinSegments(segments);
        if (visibleWidth(line) <= width) return ` ${line} `;
    }

    return truncateToWidth(
        ` ${joinSegments(candidateSets[candidateSets.length - 1] ?? [])} `,
        width,
        "…",
    );
}

export function renderModeIndicatorLine(width: number, ctx: SegmentContext): string {
    if (width <= 0) return "";

    const isPlanMode = isPlannotatorPlanModeActive(ctx);
    const modeLabel = isPlanMode ? PLAN_MODE_LABEL : AUTO_MODE_LABEL;
    const color = isPlanMode ? PLAN_MODE_COLOR : AUTO_MODE_COLOR;
    const label = `${modeLabel} ${MODE_SHORTCUT_LABEL}`;
    const labelWidth = Math.max(0, width - 1);
    const visibleLabel =
        labelWidth <= 0
            ? ""
            : visibleWidth(label) <= labelWidth
              ? label
              : truncateToWidth(label, labelWidth, "…");

    return ` ${visibleLabel ? styleModeLabel(visibleLabel, modeLabel, color) : ""}`;
}

function styleModeLabel(visibleLabel: string, modeLabel: string, color: string): string {
    if (!visibleLabel.startsWith(modeLabel)) return fg(color, visibleLabel);

    const shortcutLabel = visibleLabel.slice(modeLabel.length);
    return `${fg(color, modeLabel)}${text(shortcutLabel)}`;
}

function isPlannotatorPlanModeActive(ctx: SegmentContext): boolean {
    const raw = stripAnsi(ctx.extensionStatuses.get("plannotator") ?? "")
        .trim()
        .toLowerCase();

    return raw.includes("⏸") || raw.includes("plan");
}

const TIER_COMPACT = 0;
const TIER_NARROW = 1;
const TIER_MEDIUM = 2;
const TIER_ROOMY = 3;
const TIER_FULL = 4;

type WidthTier =
    | typeof TIER_COMPACT
    | typeof TIER_NARROW
    | typeof TIER_MEDIUM
    | typeof TIER_ROOMY
    | typeof TIER_FULL;

interface CandidateParts {
    contextFull: string;
    contextCompact: string;
    contextZero: string;
    modelFull: string;
    modelCompact: string;
    modelZero: string;
    gitFull: string;
    gitCompact: string;
    gitZero: string;
    tokensFull: string;
    tokensCompact: string;
    tokenLevel1: string;
    tokenLevel2: string;
    billing: string;
    duration: string;
    lsp: string;
    mcp: string;
}

const CONTEXT_FULL_LEVELS = [0, 1, 2, 2, 3] as const;
const MODEL_FULL_LEVELS = [0, 1, 1, 2, 2] as const;
const GIT_FULL_LEVELS = [0, 1, 2, 2, 3] as const;
const TOKEN_FULL_LEVELS = [0, 1, 2, 2, 3] as const;
const COMPACT_LEVELS = [0, 1, 1, 1, 1] as const;
const CANDIDATE_BUILDERS = [
    compactCandidateSets,
    narrowCandidateSets,
    mediumCandidateSets,
    roomyCandidateSets,
    fullCandidateSets,
] as const;

function buildCandidates(width: number, ctx: SegmentContext): string[][] {
    const tier = widthTier(width);
    return CANDIDATE_BUILDERS[tier](buildCandidateParts(tier, ctx));
}

function widthTier(width: number): WidthTier {
    if (width >= 110) return TIER_FULL;
    if (width >= 90) return TIER_ROOMY;
    if (width >= 75) return TIER_MEDIUM;
    if (width >= 50) return TIER_NARROW;
    return TIER_COMPACT;
}

function buildCandidateParts(tier: WidthTier, ctx: SegmentContext): CandidateParts {
    const compactLevel = COMPACT_LEVELS[tier];
    const fullInfraOnly = tier === TIER_FULL;
    const duration =
        tier >= TIER_ROOMY
            ? less(`${TIMER_ICON} ${formatDuration(Date.now() - ctx.sessionStartTime)}`)
            : "";

    return {
        contextFull: contextSegment(ctx, CONTEXT_FULL_LEVELS[tier]),
        contextCompact: contextSegment(ctx, compactLevel),
        contextZero: contextSegment(ctx, 0),
        modelFull: modelSegment(ctx, MODEL_FULL_LEVELS[tier]),
        modelCompact: modelSegment(ctx, compactLevel),
        modelZero: modelSegment(ctx, 0),
        gitFull: gitSegment(ctx, GIT_FULL_LEVELS[tier]),
        gitCompact: gitSegment(ctx, compactLevel),
        gitZero: gitSegment(ctx, 0),
        tokensFull: tokenSegment(ctx, TOKEN_FULL_LEVELS[tier]),
        tokensCompact: tokenSegment(ctx, compactLevel),
        tokenLevel1: tokenSegment(ctx, 1),
        tokenLevel2: tokenSegment(ctx, 2),
        billing: billingSegment(ctx),
        duration,
        lsp: infraSegment(parseLspStatus(ctx.extensionStatuses), fullInfraOnly) ?? "",
        mcp: infraSegment(parseMcpStatus(ctx.extensionStatuses), fullInfraOnly) ?? "",
    };
}

function fullCandidateSets(parts: CandidateParts): string[][] {
    return [
        [
            parts.contextFull,
            parts.modelFull,
            parts.gitFull,
            parts.tokensFull,
            parts.billing,
            parts.lsp,
            parts.mcp,
            parts.duration,
        ],
        [
            parts.contextFull,
            parts.modelFull,
            parts.gitFull,
            parts.tokensFull,
            parts.billing,
            parts.duration,
        ],
        [
            parts.contextFull,
            parts.modelFull,
            parts.gitFull,
            parts.tokenLevel2,
            parts.billing,
            parts.duration,
        ],
        [parts.contextCompact, parts.modelFull, parts.gitFull, parts.tokenLevel2, parts.billing],
        [parts.contextCompact, parts.modelCompact, parts.gitCompact, parts.tokensCompact],
        [parts.contextZero, parts.modelZero, parts.gitZero],
    ];
}

function roomyCandidateSets(parts: CandidateParts): string[][] {
    return [
        [
            parts.contextFull,
            parts.modelFull,
            parts.gitFull,
            parts.tokensFull,
            parts.billing,
            parts.duration,
        ],
        [
            parts.contextFull,
            parts.modelFull,
            parts.gitFull,
            parts.tokenLevel1,
            parts.billing,
            parts.duration,
        ],
        [parts.contextCompact, parts.modelFull, parts.gitCompact, parts.tokenLevel1, parts.billing],
        [parts.contextCompact, parts.modelCompact, parts.gitCompact, parts.tokensCompact],
        [parts.contextZero, parts.modelZero, parts.gitZero],
    ];
}

function mediumCandidateSets(parts: CandidateParts): string[][] {
    return [
        [parts.contextFull, parts.modelFull, parts.gitFull, parts.tokensFull, parts.billing],
        [parts.contextFull, parts.modelFull, parts.gitFull, parts.tokenLevel1, parts.billing],
        [parts.contextCompact, parts.modelCompact, parts.gitCompact, parts.tokensCompact],
        [parts.contextZero, parts.modelZero, parts.gitZero],
    ];
}

function narrowCandidateSets(parts: CandidateParts): string[][] {
    return [
        [parts.contextFull, parts.gitFull, parts.modelFull, parts.tokensFull],
        [parts.contextCompact, parts.gitCompact, parts.modelCompact, parts.tokensCompact],
        [parts.contextZero, parts.gitZero, parts.modelZero],
    ];
}

function compactCandidateSets(parts: CandidateParts): string[][] {
    return [
        [parts.contextFull, parts.gitFull, parts.modelFull],
        [parts.contextZero, parts.gitZero],
    ];
}

function contextSegment(ctx: SegmentContext, level: number): string {
    const pct = Number.isFinite(ctx.contextPercent) ? ctx.contextPercent : 0;
    const pctText = `${Math.round(pct)}%`;
    const windowText =
        level >= 3 && ctx.contextWindow > 0 ? `/${formatTokens(ctx.contextWindow)}` : "";
    const textPart = text(`${pctText}${windowText}`);
    if (level <= 0) return textPart;

    const barWidth = contextBarWidth(level);
    const filled = Math.min(barWidth, Math.max(0, Math.floor((pct * barWidth) / 100)));
    const band = contextBand(ctx);
    const [barFg, barBg] = contextBandColors(band);
    const bar = fgBg(barFg, barBg, `${"█".repeat(filled)}${"░".repeat(barWidth - filled)}`);
    return `${bar} ${textPart}`;
}

function contextBarWidth(level: number): number {
    if (level >= 3) return 14;
    if (level === 2) return 10;
    if (level === 1) return 8;
    return 0;
}

function contextBand(ctx: SegmentContext): ContextBand {
    if (!ctx.contextWindow || ctx.contextWindow <= 0) return STATUS_HEALTHY;
    const reserveTokens = ctx.reserveTokens ?? 16_384;
    const autoPct = ctx.autoCompactEnabled
        ? ((ctx.contextWindow - reserveTokens) / ctx.contextWindow) * 100
        : 100;
    const warnPct = Math.max(0, autoPct - 20);
    const errorPct = Math.max(0, autoPct - 10);
    if (ctx.contextPercent >= errorPct) return BAND_ERROR;
    if (ctx.contextPercent >= warnPct) return BAND_WARN;
    return STATUS_HEALTHY;
}

function contextBandColors(band: ContextBand): [string, string] {
    if (band === BAND_ERROR) return [COLORS.contextErrorFg, COLORS.contextErrorBg];
    if (band === BAND_WARN) return [COLORS.contextWarnFg, COLORS.contextWarnBg];
    return [COLORS.contextHealthyFg, COLORS.contextHealthyBg];
}

function modelSegment(ctx: SegmentContext, level: number): string {
    const model = ctx.model;
    if (!model) return less("no-model");
    const provider = friendlyProvider(model.provider ?? model.providerId ?? "");
    const modelName = shortenModelName(model);
    const base = level <= 0 || !provider ? modelName : `${provider}:${modelName}`;
    const baseText = text(base);
    if (ctx.thinkingLevel === "off" || level < 2) return baseText;

    const thinkingText = shortThinkingLevel(ctx.thinkingLevel);
    const styledThinking =
        ctx.thinkingLevel === "high" || ctx.thinkingLevel === "xhigh"
            ? rainbow(thinkingText)
            : text(thinkingText);
    return `${baseText}${text(" · ")}${styledThinking}`;
}

interface GitStatusPart {
    minimumLevel: number;
    count?: number;
    color: string;
    prefix: string;
}

function gitSegment(ctx: SegmentContext, level: number): string {
    const git = ctx.git;
    if (!git.branch) return "";
    const icon = git.isWorktree ? "🔀" : "🌿";
    const maxBranchWidth = level >= 3 ? 38 : level >= 2 ? 28 : level >= 1 ? 18 : 12;
    const branch = truncateToWidth(git.branch, maxBranchWidth, "…");
    return [text(`${icon} ${branch}`), ...gitStatusParts(ctx, level)].join(" ");
}

function gitStatusParts(ctx: SegmentContext, level: number): string[] {
    const git = ctx.git;
    const parts: GitStatusPart[] = [
        { minimumLevel: 1, count: git.staged, color: COLORS.gitGood, prefix: "+" },
        { minimumLevel: 1, count: git.unstaged, color: COLORS.gitModified, prefix: "~" },
        { minimumLevel: 2, count: git.untracked, color: COLORS.gitUntracked, prefix: "?" },
        { minimumLevel: 3, count: git.ahead, color: COLORS.gitGood, prefix: "↑" },
        { minimumLevel: 3, count: git.behind, color: COLORS.red, prefix: "↓" },
    ];

    return parts
        .filter((part) => level >= part.minimumLevel && (part.count ?? 0) > 0)
        .map((part) => fg(part.color, `${part.prefix}${part.count}`));
}

function tokenSegment(ctx: SegmentContext, level: number): string {
    const usage = ctx.usageStats;
    const cache = usage.cacheRead + usage.cacheWrite;
    const parts: string[] = [];
    if (level <= 0) {
        if (usage.input || usage.output) {
            return text(`${formatTokens(usage.input)}/${formatTokens(usage.output)}`);
        }
        return "";
    }
    if (usage.input > 0) parts.push(`↓${formatTokens(usage.input)}`);
    if (usage.output > 0) parts.push(`↑${formatTokens(usage.output)}`);
    if (level >= 2 && cache > 0) parts.push(`${CACHE_ICON}${formatTokens(cache)}`);
    return parts.length ? text(parts.join(" ")) : "";
}

function billingSegment(ctx: SegmentContext): string {
    const model = ctx.model;
    if (!model) return "";
    const provider = model.provider ?? model.providerId ?? "";
    const cost = ctx.usageStats.cost;
    const subscriptionBackedOauth =
        ctx.usingSubscription && SUBSCRIPTION_BACKED_OAUTH_PROVIDERS.has(provider);

    // Codex and Copilot OAuth usage is subscription-backed even when pi's
    // provider metadata exposes estimated token cost. Show cost for API-key
    // billing and for metered OAuth providers such as Claude extra usage.
    if (subscriptionBackedOauth) return less("♢ sub");
    if (LOCAL_PROVIDER_PATTERN.test(provider)) return less("local");
    if (cost > 0) return less(formatCost(cost));
    return less("api");
}

function infraSegment(status: InfraStatus, showInactive: boolean): string | null {
    if (status.kind === STATUS_INACTIVE && !showInactive) return null;
    const dot = status.kind === STATUS_HEALTHY ? "●" : status.kind === STATUS_PARTIAL ? "◌" : "○";
    const dotColor =
        status.kind === STATUS_HEALTHY
            ? COLORS.gitGood
            : status.kind === STATUS_PARTIAL
              ? COLORS.contextWarnFg
              : COLORS.less;
    const count = status.count ? ` ${status.count}` : "";
    return `${fg(dotColor, dot)} ${less(`${status.label}${count}`)}`;
}

function parseLspStatus(statuses: ReadonlyMap<string, string>): InfraStatus {
    const raw = stripAnsi(statuses.get("pi-lens-lsp") ?? "").trim();
    const activeCount = raw.match(/\bLSP\s+Active\s*\((\d+)\)/i)?.[1];
    if (activeCount) return { kind: STATUS_HEALTHY, label: "LSP", count: activeCount };
    if (/\bactive\b/i.test(raw)) return { kind: STATUS_HEALTHY, label: "LSP" };
    if (/inactive|disabled|off|unavailable/i.test(raw) || !raw)
        return { kind: STATUS_INACTIVE, label: "LSP" };

    return { kind: STATUS_PARTIAL, label: "LSP" };
}

function parseMcpStatus(statuses: ReadonlyMap<string, string>): InfraStatus {
    const raw = stripAnsi(statuses.get("mcp") ?? "").trim();
    if (/\bconnecting\b/i.test(raw)) return { kind: STATUS_PARTIAL, label: "MCP" };

    const ratio =
        raw.match(/\bMCP:\s*(\d+)\s*\/\s*(\d+)\s+servers\b/i) ??
        raw.match(/\b(\d+)\s*\/\s*(\d+)\b/);
    if (ratio) {
        const connected = Number(ratio[1]);
        const total = Number(ratio[2]);
        if (connected <= 0) return { kind: STATUS_INACTIVE, label: "MCP" };
        return {
            kind: connected === total ? STATUS_HEALTHY : STATUS_PARTIAL,
            label: "MCP",
            count: String(connected),
        };
    }

    if (/needs-auth|failed|error|degraded/i.test(raw))
        return { kind: STATUS_PARTIAL, label: "MCP" };
    if (/connected|active|ready|enabled/i.test(raw)) return { kind: STATUS_HEALTHY, label: "MCP" };
    return { kind: STATUS_INACTIVE, label: "MCP" };
}

function stripAnsi(value: string): string {
    return value.replace(/\x1b\[[0-9;?]*[ -/]*[@-~]/g, "");
}

function joinSegments(segments: string[]): string {
    return segments.filter(Boolean).join(less(SEP));
}

function text(value: string): string {
    return fg(COLORS.text, value);
}

function less(value: string): string {
    return fg(COLORS.less, value);
}

function fg(hex: string, value: string): string {
    return `${hexToFgAnsi(hex)}${value}\x1b[0m`;
}

function fgBg(fgHex: string, bgHex: string, value: string): string {
    return `${hexToFgAnsi(fgHex)}${hexToBgAnsi(bgHex)}${value}\x1b[0m`;
}

function rainbow(value: string): string {
    let result = "";
    let colorIndex = 0;
    for (const char of value) {
        if (char === " ") {
            result += char;
            continue;
        }
        result += `${hexToFgAnsi(RAINBOW_COLORS[colorIndex % RAINBOW_COLORS.length])}${char}`;
        colorIndex++;
    }
    return `${result}\x1b[0m`;
}

function hexToFgAnsi(hex: string): string {
    const [r, g, b] = hexToRgb(hex);
    return `\x1b[38;2;${r};${g};${b}m`;
}

function hexToBgAnsi(hex: string): string {
    const [r, g, b] = hexToRgb(hex);
    return `\x1b[48;2;${r};${g};${b}m`;
}

function hexToRgb(hex: string): [number, number, number] {
    const h = hex.replace("#", "");
    return [parseInt(h.slice(0, 2), 16), parseInt(h.slice(2, 4), 16), parseInt(h.slice(4, 6), 16)];
}

function friendlyProvider(provider: string): string {
    const labels: Record<string, string> = {
        [PROVIDER_OPENAI_CODEX]: "Codex",
        [PROVIDER_GITHUB_COPILOT]: "Copilot",
        anthropic: "Claude",
        google: "Google",
        "google-vertex": "Google",
        openai: "OpenAI",
        openrouter: "OpenRouter",
        "amazon-bedrock": "Bedrock",
        "azure-openai-responses": "Azure",
        "cloudflare-ai-gateway": "Cloudflare",
        "cloudflare-workers-ai": "Cloudflare",
        "vercel-ai-gateway": "Vercel",
    };
    if (labels[provider]) return labels[provider];
    if (LOCAL_PROVIDER_PATTERN.test(provider)) return "Local";
    return provider
        .split("-")
        .filter(Boolean)
        .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
        .join("");
}

function shortenModelName(model: { id?: string; name?: string }): string {
    let name = model.id || model.name || "model";
    name = name.replace(/^claude-/, "");
    name = name.replace(/-20\d{6}$/, "");
    name = name.replace(/sonnet-(\d)-(\d)/, "sonnet-$1.$2");
    name = name.replace(/opus-(\d)-(\d)/, "opus-$1.$2");
    name = name.replace(/haiku-(\d)-(\d)/, "haiku-$1.$2");
    return truncateToWidth(name, 28, "…");
}

function shortThinkingLevel(level: string): string {
    return level === "medium" ? "med" : level;
}

function formatTokens(value: number): string {
    if (value < 1_000) return Math.round(value).toString();
    if (value < 10_000) return `${(value / 1_000).toFixed(1)}k`;
    if (value < 1_000_000) return `${Math.round(value / 1_000)}k`;
    if (value < 10_000_000) return `${(value / 1_000_000).toFixed(1)}M`;
    return `${Math.round(value / 1_000_000)}M`;
}

function formatCost(cost: number): string {
    if (cost < 0.01) return `$${cost.toFixed(3)}`;
    if (cost < 1) return `$${cost.toFixed(2)}`;
    return `$${cost.toFixed(2)}`;
}

function formatDuration(ms: number): string {
    const seconds = Math.floor(ms / 1_000);
    const days = Math.floor(seconds / 86_400);
    const hours = Math.floor((seconds % 86_400) / 3_600);
    const minutes = Math.floor((seconds % 3_600) / 60);
    if (days > 0) return hours > 0 ? `${days}d${hours}h` : `${days}d`;
    if (hours > 0) return minutes > 0 ? `${hours}h${minutes}m` : `${hours}h`;
    if (minutes > 0) return `${minutes}m`;
    return `${seconds}s`;
}
