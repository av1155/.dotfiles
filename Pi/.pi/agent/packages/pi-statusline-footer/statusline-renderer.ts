import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";
import type { SegmentContext } from "./types.js";

const SEP = " │ ";
const CACHE_ICON = "󰆼";
const AUTO_COMPACT_ICON = "↯";
const TIMER_ICON = "⏱";

const COLORS = {
    text: "#949494",
    less: "#595A61",
    contextHealthyBg: "#404E49",
    contextHealthyFg: "#A6E3A1",
    contextWarnBg: "#585451",
    contextWarnFg: "#F9E2AF",
    contextErrorBg: "#4F454C",
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

type InfraStatus = { kind: "healthy" | "partial" | "inactive"; label: string; count?: string };

type ContextBand = "healthy" | "warn" | "error";

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

function buildCandidates(width: number, ctx: SegmentContext): string[][] {
    const full = width >= 110;
    const roomy = width >= 90;
    const medium = width >= 75;
    const narrow = width >= 50;

    const contextFull = contextSegment(ctx, full ? 3 : medium ? 2 : narrow ? 1 : 0);
    const contextCompact = contextSegment(ctx, narrow ? 1 : 0);
    const modelFull = modelSegment(ctx, full || roomy ? 2 : narrow ? 1 : 0);
    const modelCompact = modelSegment(ctx, narrow ? 1 : 0);
    const gitFull = gitSegment(ctx, full ? 3 : medium ? 2 : narrow ? 1 : 0);
    const gitCompact = gitSegment(ctx, narrow ? 1 : 0);
    const tokensFull = tokenSegment(ctx, full ? 3 : medium || roomy ? 2 : narrow ? 1 : 0);
    const tokensCompact = tokenSegment(ctx, narrow ? 1 : 0);
    const billing = billingSegment(ctx);
    const duration = roomy
        ? less(`${TIMER_ICON} ${formatDuration(Date.now() - ctx.sessionStartTime)}`)
        : "";
    const lsp = infraSegment(parseLspStatus(ctx.extensionStatuses), full) ?? "";
    const mcp = infraSegment(parseMcpStatus(ctx.extensionStatuses), full) ?? "";

    if (full) {
        return [
            [contextFull, modelFull, gitFull, tokensFull, billing, lsp, mcp, duration],
            [contextFull, modelFull, gitFull, tokensFull, billing, duration],
            [contextFull, modelFull, gitFull, tokenSegment(ctx, 2), billing, duration],
            [contextCompact, modelFull, gitFull, tokenSegment(ctx, 2), billing],
            [contextCompact, modelCompact, gitCompact, tokensCompact],
            [contextSegment(ctx, 0), modelSegment(ctx, 0), gitSegment(ctx, 0)],
        ];
    }

    if (roomy) {
        return [
            [contextFull, modelFull, gitFull, tokensFull, billing, duration],
            [contextFull, modelFull, gitFull, tokenSegment(ctx, 1), billing, duration],
            [contextCompact, modelFull, gitCompact, tokenSegment(ctx, 1), billing],
            [contextCompact, modelCompact, gitCompact, tokensCompact],
            [contextSegment(ctx, 0), modelSegment(ctx, 0), gitSegment(ctx, 0)],
        ];
    }

    if (medium) {
        return [
            [contextFull, modelFull, gitFull, tokensFull, billing],
            [contextFull, modelFull, gitFull, tokenSegment(ctx, 1), billing],
            [contextCompact, modelCompact, gitCompact, tokensCompact],
            [contextSegment(ctx, 0), modelSegment(ctx, 0), gitSegment(ctx, 0)],
        ];
    }

    if (narrow) {
        return [
            [contextFull, gitFull, modelFull, tokensFull],
            [contextCompact, gitCompact, modelCompact, tokensCompact],
            [contextSegment(ctx, 0), gitSegment(ctx, 0), modelSegment(ctx, 0)],
        ];
    }

    return [
        [contextFull, gitFull, modelFull],
        [contextSegment(ctx, 0), gitSegment(ctx, 0)],
    ];
}

function contextSegment(ctx: SegmentContext, level: number): string {
    const pct = Number.isFinite(ctx.contextPercent) ? ctx.contextPercent : 0;
    const pctText = `${Math.round(pct)}%`;
    const windowText =
        level >= 3 && ctx.contextWindow > 0 ? `/${formatTokens(ctx.contextWindow)}` : "";
    const autoText = ctx.autoCompactEnabled && level >= 2 ? ` ${AUTO_COMPACT_ICON}` : "";
    const textPart = text(`${pctText}${windowText}${autoText}`);
    if (level <= 0) return textPart;

    const barWidth = contextBarWidth(level);
    const filled = Math.min(barWidth, Math.max(0, Math.floor((pct * barWidth) / 100)));
    const band = contextBand(ctx);
    const [barFg, barBg] = contextBandColors(band);
    const bar = `${fg(barFg, "█".repeat(filled))}${fg(barBg, "░".repeat(barWidth - filled))}`;
    return `${bar} ${textPart}`;
}

function contextBarWidth(level: number): number {
    if (level >= 3) return 14;
    if (level === 2) return 10;
    if (level === 1) return 8;
    return 0;
}

function contextBand(ctx: SegmentContext): ContextBand {
    if (!ctx.contextWindow || ctx.contextWindow <= 0) return "healthy";
    const reserveTokens =
        typeof (ctx as any).reserveTokens === "number" ? (ctx as any).reserveTokens : 16_384;
    const autoPct = ctx.autoCompactEnabled
        ? ((ctx.contextWindow - reserveTokens) / ctx.contextWindow) * 100
        : 100;
    const warnPct = Math.max(0, autoPct - 20);
    const errorPct = Math.max(0, autoPct - 10);
    if (ctx.contextPercent >= errorPct) return "error";
    if (ctx.contextPercent >= warnPct) return "warn";
    return "healthy";
}

function contextBandColors(band: ContextBand): [string, string] {
    if (band === "error") return [COLORS.contextErrorFg, COLORS.contextErrorBg];
    if (band === "warn") return [COLORS.contextWarnFg, COLORS.contextWarnBg];
    return [COLORS.contextHealthyFg, COLORS.contextHealthyBg];
}

function modelSegment(ctx: SegmentContext, level: number): string {
    const model = ctx.model as any;
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

function gitSegment(ctx: SegmentContext, level: number): string {
    const git = ctx.git as any;
    if (!git?.branch) return "";
    const icon = git.isWorktree || git.branch !== "main" ? "🔀" : "🌿";
    const maxBranchWidth = level >= 3 ? 38 : level >= 2 ? 28 : level >= 1 ? 18 : 12;
    const branch = truncateToWidth(git.branch, maxBranchWidth, "…");
    const parts = [text(`${icon} ${branch}`)];
    if (level >= 1 && git.staged > 0) parts.push(fg(COLORS.gitGood, `+${git.staged}`));
    if (level >= 1 && git.unstaged > 0) parts.push(fg(COLORS.gitModified, `~${git.unstaged}`));
    if (level >= 2 && git.untracked > 0) parts.push(fg(COLORS.gitUntracked, `?${git.untracked}`));
    if (level >= 3 && git.ahead > 0) parts.push(fg(COLORS.gitGood, `↑${git.ahead}`));
    if (level >= 3 && git.behind > 0) parts.push(fg(COLORS.red, `↓${git.behind}`));
    return parts.join(" ");
}

function tokenSegment(ctx: SegmentContext, level: number): string {
    const usage = ctx.usageStats as any;
    const cache = usage.cacheRead + usage.cacheWrite;
    const parts: string[] = [];
    if (level <= 0) {
        if (!usage.input && !usage.output) return "";
        return text(`${formatTokens(usage.input)}/${formatTokens(usage.output)}`);
    }
    if (usage.input > 0) parts.push(`↓${formatTokens(usage.input)}`);
    if (usage.output > 0) parts.push(`↑${formatTokens(usage.output)}`);
    if (level >= 2 && cache > 0) parts.push(`${CACHE_ICON}${formatTokens(cache)}`);
    return parts.length ? text(parts.join(" ")) : "";
}

function billingSegment(ctx: SegmentContext): string {
    const model = ctx.model as any;
    if (!model) return "";
    const provider = model.provider ?? model.providerId ?? "";
    const cost = ctx.usageStats.cost;

    // Codex and Copilot OAuth usage is subscription-backed even when pi's
    // provider metadata exposes estimated token cost. Show cost for API-key
    // billing and for metered OAuth providers such as Claude extra usage.
    if (ctx.usingSubscription && (provider === "openai-codex" || provider === "github-copilot"))
        return less("♢ sub");
    if (isLocalProvider(provider)) return less("local");
    if (cost > 0) return less(formatCost(cost));
    return less("api");
}

function infraSegment(status: InfraStatus, showInactive: boolean): string | null {
    if (status.kind === "inactive" && !showInactive) return null;
    const dot = status.kind === "healthy" ? "●" : status.kind === "partial" ? "◌" : "○";
    const dotColor =
        status.kind === "healthy"
            ? COLORS.gitGood
            : status.kind === "partial"
              ? COLORS.contextWarnFg
              : COLORS.less;
    const count = status.count ? ` ${status.count}` : "";
    return `${fg(dotColor, dot)} ${less(`${status.label}${count}`)}`;
}

function parseLspStatus(statuses: ReadonlyMap<string, string>): InfraStatus {
    const raw = stripAnsi(statuses.get("pi-lens-lsp") ?? "").trim();
    const activeCount = raw.match(/\bLSP\s+Active\s*\((\d+)\)/i)?.[1];
    if (activeCount) return { kind: "healthy", label: "LSP", count: activeCount };
    if (/\bactive\b/i.test(raw)) return { kind: "healthy", label: "LSP" };
    if (/inactive|disabled|off|unavailable/i.test(raw) || !raw)
        return { kind: "inactive", label: "LSP" };

    return { kind: "partial", label: "LSP" };
}

function parseMcpStatus(statuses: ReadonlyMap<string, string>): InfraStatus {
    const raw = stripAnsi(statuses.get("mcp") ?? "").trim();
    if (/\bconnecting\b/i.test(raw)) return { kind: "partial", label: "MCP" };

    const ratio =
        raw.match(/\bMCP:\s*(\d+)\s*\/\s*(\d+)\s+servers\b/i) ??
        raw.match(/\b(\d+)\s*\/\s*(\d+)\b/);
    if (ratio) {
        const connected = Number(ratio[1]);
        const total = Number(ratio[2]);
        if (connected <= 0) return { kind: "inactive", label: "MCP" };
        return {
            kind: connected === total ? "healthy" : "partial",
            label: "MCP",
            count: String(connected),
        };
    }

    if (/needs-auth|failed|error|degraded/i.test(raw)) return { kind: "partial", label: "MCP" };
    if (/connected|active|ready|enabled/i.test(raw)) return { kind: "healthy", label: "MCP" };
    return { kind: "inactive", label: "MCP" };
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
    return `${hexToAnsi(hex)}${value}\x1b[0m`;
}

function rainbow(value: string): string {
    let result = "";
    let colorIndex = 0;
    for (const char of value) {
        if (char === " ") {
            result += char;
            continue;
        }
        result += `${hexToAnsi(RAINBOW_COLORS[colorIndex % RAINBOW_COLORS.length])}${char}`;
        colorIndex++;
    }
    return `${result}\x1b[0m`;
}

function hexToAnsi(hex: string): string {
    const h = hex.replace("#", "");
    const r = parseInt(h.slice(0, 2), 16);
    const g = parseInt(h.slice(2, 4), 16);
    const b = parseInt(h.slice(4, 6), 16);
    return `\x1b[38;2;${r};${g};${b}m`;
}

function friendlyProvider(provider: string): string {
    const labels: Record<string, string> = {
        "openai-codex": "Codex",
        "github-copilot": "Copilot",
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
    if (isLocalProvider(provider)) return "Local";
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

function isLocalProvider(provider: string): boolean {
    return /ollama|lmstudio|lm-studio|vllm|local/i.test(provider);
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
