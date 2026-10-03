"""Context use of the running Claude Code session, read from its transcript."""

import json
import os
import sys
from pathlib import Path
from typing import cast

from bl_state import LoopError, as_dict, optional_git

TAIL_BYTES = 4_000_000
USAGE_KEYS = ("input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens")
COMPACT_POINTS = {
    "plan": ("after planning", "buildloop.compactAfterPlan", 25),
    "round": ("before a round", "buildloop.compactBeforeRound", 60),
}


def transcript() -> Path:
    session = os.environ.get("CLAUDE_CODE_SESSION_ID")
    if not session:
        message = "CLAUDE_CODE_SESSION_ID is not set; check /context instead"
        raise LoopError(message)
    config_dir = os.environ.get("CLAUDE_CONFIG_DIR") or Path.home() / ".claude"
    projects = Path(config_dir) / "projects"
    matches = list(projects.glob(f"*/{session}.jsonl"))
    if not matches:
        message = f"no transcript for session {session}; check /context instead"
        raise LoopError(message)
    return max(matches, key=lambda path: path.stat().st_mtime)


def _context(line: str) -> tuple[int, bool] | None:
    record = _record(line)
    if record.get("isSidechain"):
        return None
    if record.get("type") == "system" and record.get("subtype") == "compact_boundary":
        # The running request may not be logged yet, so earlier usage is stale
        carried = as_dict(record.get("compactMetadata")).get("postTokens")
        if isinstance(carried, int):
            return carried, True
        message = (
            "compacted since the last logged request, with no size; check /context"
        )
        raise LoopError(message)
    if record.get("type") != "assistant":
        return None
    usage = as_dict(as_dict(record.get("message")).get("usage"))
    counts = [usage.get(key) for key in USAGE_KEYS]
    ints = [count for count in counts if isinstance(count, int)]
    if len(ints) < len(USAGE_KEYS):
        return None
    total = sum(ints)
    # API errors log synthetic assistant entries with all-zero usage
    return (total, False) if total else None


def _record(line: str) -> dict[str, object]:
    try:
        entry: object = json.loads(line)
    except ValueError:
        return {}
    return as_dict(entry)


def _is_reply(record: dict[str, object]) -> bool:
    model = as_dict(record.get("message")).get("model")
    return (
        record.get("type") == "assistant"
        and not record.get("isApiErrorMessage")
        and model != "<synthetic>"
    )


def _ran_a_tool(record: dict[str, object]) -> bool:
    content = as_dict(record.get("message")).get("content")
    blocks = cast("list[object]", content) if isinstance(content, list) else []
    return any(as_dict(block).get("type") == "tool_result" for block in blocks)


def _just_started(lines: list[str]) -> bool:
    # The last piece may still be in flight
    records = [_record(line) for line in lines[:-1] if line]
    if not records:
        return True
    main = [
        r
        for r in records
        if isinstance(r.get("type"), str) and not r.get("isSidechain")
    ]
    return bool(main) and not any(_is_reply(r) or _ran_a_tool(r) for r in main)


def tokens(path: Path) -> tuple[int, bool] | None:
    """Return the newest reading, or None if this session has logged no request."""
    with path.open("rb") as handle:
        size = handle.seek(0, os.SEEK_END)
        handle.seek(max(0, size - TAIL_BYTES))
        tail = handle.read().decode("utf-8", "replace")
    # splitlines() would also split on U+2028, which JSON leaves unescaped
    lines = tail.split("\n")
    for line in reversed(lines):
        found = _context(line)
        if found is not None:
            return found
    if size <= TAIL_BYTES and _just_started(lines):
        return None
    message = (
        f"no request bl can read in the last {TAIL_BYTES // 1_000_000} MB of "
        f"{path.name}; check /context"
    )
    raise LoopError(message)


def _config_int(key: str, default: int) -> int:
    value = optional_git("config", "--get", key)
    if value.isdecimal() and int(value) > 0:
        return int(value)
    if value:
        print(f"bl: ignoring {key}={value}; using {default}", file=sys.stderr)
    return default


def report(point: str | None) -> list[str]:
    reading = tokens(transcript())
    window = _config_int("buildloop.contextWindow", 1_000_000)
    share, detail = 0, "no request logged yet, so this session just started"
    if reading is not None:
        used, compacted = reading
        share = 100 * used // window
        carried = " carried over by a compaction" if compacted else ""
        detail = f"{used:,} tokens{carried}, {share}% of a {window:,}-token window"
    if point:
        _label, key, default = COMPACT_POINTS[point]
        limit = _config_int(key, default)
        return [f"compact: {detail} (limit {limit}%)" if share >= limit else "continue"]
    lines = [f"context: {detail}"]
    for label, key, default in COMPACT_POINTS.values():
        limit = _config_int(key, default)
        verdict = "compact" if share >= limit else "continue"
        lines.append(f"{label}: {verdict} (compacts at {limit}%)")
    return lines
