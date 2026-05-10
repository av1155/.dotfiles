import { spawn } from "node:child_process";
import type { GitStatus } from "./types.js";

interface CachedGitStatus {
  staged: number;
  unstaged: number;
  untracked: number;
  ahead: number;
  behind: number;
  isWorktree: boolean;
  timestamp: number;
}

interface CachedBranch {
  branch: string | null;
  timestamp: number;
}

const CACHE_TTL_MS = 1000; // 1 second for file status
const BRANCH_TTL_MS = 500; // Shorter TTL so branch updates quickly after invalidation
let cachedStatus: CachedGitStatus | null = null;
let cachedBranch: CachedBranch | null = null;
let pendingFetch: Promise<void> | null = null;
let pendingBranchFetch: Promise<void> | null = null;
let invalidationCounter = 0; // Track invalidations to prevent stale updates
let branchInvalidationCounter = 0;

/**
 * Parse git status --porcelain output
 * 
 * Format: XY filename
 * X = index status, Y = working tree status
 * ?? = untracked
 * Other X values = staged
 * Other Y values = unstaged
 */
function parseGitStatusOutput(output: string): { staged: number; unstaged: number; untracked: number; ahead: number; behind: number } {
  let staged = 0;
  let unstaged = 0;
  let untracked = 0;
  let ahead = 0;
  let behind = 0;

  for (const line of output.split("\n")) {
    if (!line) continue;
    if (line.startsWith("## ")) {
      ahead = Number(line.match(/ahead (\d+)/)?.[1] ?? 0) || 0;
      behind = Number(line.match(/behind (\d+)/)?.[1] ?? 0) || 0;
      continue;
    }

    const x = line[0];
    const y = line[1];

    if (x === "?" && y === "?") {
      untracked++;
      continue;
    }

    // X position (index/staged)
    if (x && x !== " " && x !== "?") {
      staged++;
    }

    // Y position (working tree/unstaged)
    if (y && y !== " ") {
      unstaged++;
    }
  }

  return { staged, unstaged, untracked, ahead, behind };
}

function runGit(args: string[], timeoutMs = 200): Promise<string | null> {
  return new Promise((resolve) => {
    const proc = spawn("git", args, {
      stdio: ["ignore", "pipe", "pipe"],
    });

    let stdout = "";
    let resolved = false;

    const finish = (result: string | null) => {
      if (resolved) return;
      resolved = true;
      clearTimeout(timeoutId);
      resolve(result);
    };

    proc.stdout.on("data", (data) => {
      stdout += data.toString();
    });

    proc.on("close", (code) => {
      finish(code === 0 ? stdout.trim() : null);
    });

    proc.on("error", () => {
      finish(null);
    });

    const timeoutId = setTimeout(() => {
      proc.kill();
      finish(null);
    }, timeoutMs);
  });
}

/**
 * Fetch current git branch asynchronously.
 * For detached HEAD, returns the short commit SHA (matches provider's "detached" behavior).
 */
async function fetchGitBranch(): Promise<string | null> {
  const branch = await runGit(["branch", "--show-current"]);
  if (branch === null) return null;
  if (branch) return branch;

  const sha = await runGit(["rev-parse", "--short", "HEAD"]);
  return sha ? `${sha} (detached)` : "detached";
}

/**
 * Fetch git status asynchronously
 */
async function fetchGitStatus(): Promise<{ staged: number; unstaged: number; untracked: number; ahead: number; behind: number; isWorktree: boolean } | null> {
  const output = await runGit(["status", "--porcelain=v1", "--branch"], 500);
  if (output === null) return null;
  const parsed = parseGitStatusOutput(output);
  const [gitDir, commonDir] = await Promise.all([
    runGit(["rev-parse", "--path-format=absolute", "--git-dir"], 200),
    runGit(["rev-parse", "--path-format=absolute", "--git-common-dir"], 200),
  ]);
  return { ...parsed, isWorktree: Boolean(gitDir && commonDir && gitDir !== commonDir) };
}

/**
 * Get the current git branch with caching.
 * Falls back to provider branch if our cache is empty.
 */
export function getCurrentBranch(providerBranch: string | null): string | null {
  const now = Date.now();

  // Return cached if fresh
  if (cachedBranch && now - cachedBranch.timestamp < BRANCH_TTL_MS) {
    return cachedBranch.branch;
  }

  // Trigger background fetch if not already pending
  if (!pendingBranchFetch) {
    const fetchId = branchInvalidationCounter;
    pendingBranchFetch = fetchGitBranch().then((result) => {
      // Cache result if no invalidation happened (including null for non-git dirs)
      if (fetchId === branchInvalidationCounter) {
        cachedBranch = {
          branch: result,
          timestamp: Date.now(),
        };
      }
      pendingBranchFetch = null;
    });
  }

  // Return stale cache while refreshing; only use provider before first fetch
  return cachedBranch ? cachedBranch.branch : providerBranch;
}

/**
 * Get git status with caching.
 * Returns cached value if within TTL, otherwise triggers async fetch.
 * This is designed for synchronous render() calls - returns last known value
 * while refreshing in background.
 */
export function getGitStatus(providerBranch: string | null): GitStatus {
  const now = Date.now();
  const branch = getCurrentBranch(providerBranch);

  // Return cached if fresh
  if (cachedStatus && now - cachedStatus.timestamp < CACHE_TTL_MS) {
    return { 
      branch, 
      staged: cachedStatus.staged,
      unstaged: cachedStatus.unstaged,
      untracked: cachedStatus.untracked,
      ahead: cachedStatus.ahead,
      behind: cachedStatus.behind,
      isWorktree: cachedStatus.isWorktree,
    };
  }

  // Trigger background fetch if not already pending
  if (!pendingFetch) {
    const fetchId = invalidationCounter; // Capture current counter
    pendingFetch = fetchGitStatus().then((result) => {
      // Cache result if no invalidation happened (including null for non-git dirs)
      if (fetchId === invalidationCounter) {
        cachedStatus = result
          ? { staged: result.staged, unstaged: result.unstaged, untracked: result.untracked, ahead: result.ahead, behind: result.behind, isWorktree: result.isWorktree, timestamp: Date.now() }
          : { staged: 0, unstaged: 0, untracked: 0, ahead: 0, behind: 0, isWorktree: false, timestamp: Date.now() };
      }
      pendingFetch = null;
    });
  }

  // Return last cached or empty
  if (cachedStatus) {
    return { 
      branch, 
      staged: cachedStatus.staged,
      unstaged: cachedStatus.unstaged,
      untracked: cachedStatus.untracked,
      ahead: cachedStatus.ahead,
      behind: cachedStatus.behind,
      isWorktree: cachedStatus.isWorktree,
    };
  }

  return { branch, staged: 0, unstaged: 0, untracked: 0, ahead: 0, behind: 0, isWorktree: false };
}

/**
 * Force refresh git status (call when you know files changed)
 */
export function invalidateGitStatus(): void {
  cachedStatus = null;
  invalidationCounter++; // Increment to invalidate any pending fetches
}

/**
 * Force refresh git branch (call when you know branch might have changed)
 */
export function invalidateGitBranch(): void {
  cachedBranch = null;
  branchInvalidationCounter++;
}
