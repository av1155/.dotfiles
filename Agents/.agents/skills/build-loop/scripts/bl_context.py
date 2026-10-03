"""Context use of the running Claude Code session, read from its transcript."""

import json
import os
from pathlib import Path

from bl_state import LoopError, as_dict

TAIL_BYTES = 4_000_000
USAGE_KEYS = ("input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens")


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


def _request_tokens(line: str) -> int | None:
    try:
        entry: object = json.loads(line)
    except ValueError:
        return None
    record = as_dict(entry)
    if record.get("type") != "assistant" or record.get("isSidechain"):
        return None
    usage = as_dict(as_dict(record.get("message")).get("usage"))
    if not usage:
        return None
    counts = [usage.get(key) for key in USAGE_KEYS]
    return sum(count for count in counts if isinstance(count, int))


def tokens(path: Path) -> int:
    with path.open("rb") as handle:
        size = handle.seek(0, os.SEEK_END)
        handle.seek(max(0, size - TAIL_BYTES))
        tail = handle.read().decode("utf-8", "replace")
    for line in reversed(tail.splitlines()):
        found = _request_tokens(line)
        if found is not None:
            return found
    message = f"no main-thread request recorded near the end of {path.name}"
    raise LoopError(message)
