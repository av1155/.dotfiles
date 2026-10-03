"""Per-branch loop state for the bl CLI: tier, change base, rounds and endings."""

import datetime as dt
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import cast
from urllib.parse import quote

if sys.version_info < (3, 11):
    sys.exit("bl needs Python 3.11 or later as python3 on PATH")

TIERS = ("T0", "T1", "T2", "T3")
CAPS = {"T1": 2, "T2": 4, "T3": 8}
CAP_ENDINGS = {"T1": "cap of two", "T2": "cap of four", "T3": "cap of eight"}
TARGETS = {"T1": 1, "T2": 2, "T3": 2}
LOOPS = ("review", "audit")
OPEN_ENDINGS = (None, "in progress")
COUNTED_ENDINGS = ("one clean", "two clean", *CAP_ENDINGS.values())
MANUAL_ENDINGS = (
    "documentation wave",
    "stopped early (authorised)",
    "stopped early (unauthorised)",
    "in progress",
)
GIT_TIMEOUT_SECONDS = 30


class LoopError(Exception):
    pass


def git(*args: str) -> str:
    try:
        proc = subprocess.run(
            ["git", *args],
            capture_output=True,
            text=True,
            check=False,
            timeout=GIT_TIMEOUT_SECONDS,
        )
    except subprocess.TimeoutExpired as exc:
        message = f"git {' '.join(args)} timed out"
        raise LoopError(message) from exc
    if proc.returncode != 0:
        message = f"git {' '.join(args)} failed: {proc.stderr.strip()}"
        raise LoopError(message)
    return proc.stdout.strip()


def optional_git(*args: str) -> str:
    try:
        return git(*args)
    except LoopError:
        return ""


def current_branch() -> str:
    return optional_git("symbolic-ref", "--quiet", "--short", "HEAD") or "HEAD"


def head() -> str | None:
    return optional_git("rev-parse", "--verify", "--quiet", "HEAD") or None


def branch_dir(branch: str) -> Path:
    common = git("rev-parse", "--path-format=absolute", "--git-common-dir")
    return Path(common) / "build-loop" / quote(branch, safe="")


def now() -> str:
    return dt.datetime.now(dt.UTC).isoformat(timespec="seconds")


def _as_dict(value: object) -> dict[str, object]:
    return cast("dict[str, object]", value) if isinstance(value, dict) else {}


def load(branch: str) -> dict[str, object]:
    try:
        saved = _as_dict(json.loads((branch_dir(branch) / "state.json").read_text()))
    except (OSError, ValueError):
        saved = {}
    state: dict[str, object] = {
        "branch": branch,
        "tier": None,
        "reason": "",
        "base": None,
        "plan": None,
        "rounds": [],
    }
    state.update(saved)
    state["branch"] = branch
    if state["tier"] not in TIERS:
        state["tier"] = None
    if not isinstance(state["rounds"], list):
        state["rounds"] = []
    loops = _as_dict(saved.get("loops"))
    state["loops"] = {
        name: {"passes": 0, "clean": 0, "ending": None, "last": None}
        | _as_dict(loops.get(name))
        for name in LOOPS
    }
    return state


def save(state: dict[str, object]) -> None:
    path = branch_dir(str(state["branch"])) / "state.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    state["updated"] = now()
    temp = path.with_suffix(".tmp")
    temp.write_text(json.dumps(state, indent=2) + "\n")
    os.replace(temp, path)


def loop(state: dict[str, object], name: str) -> dict[str, object]:
    loops = cast("dict[str, dict[str, object]]", state["loops"])
    return loops[name]


def _int(value: object) -> int:
    return value if isinstance(value, int) else 0


def open_loops(state: dict[str, object]) -> list[str]:
    return [name for name in LOOPS if loop(state, name)["ending"] in OPEN_ENDINGS]


def finished(state: dict[str, object]) -> bool:
    return bool(state["rounds"]) and not open_loops(state)


def settle(state: dict[str, object], name: str) -> None:
    tier, entry = state["tier"], loop(state, name)
    if not isinstance(tier, str) or tier not in CAPS:
        return
    if entry["ending"] not in (*OPEN_ENDINGS, *COUNTED_ENDINGS):
        return
    last_clean = entry["last"] in (None, "clean")
    if _int(entry["clean"]) >= TARGETS[tier] and last_clean:
        entry["ending"] = "one clean" if TARGETS[tier] == 1 else "two clean"
    elif _int(entry["passes"]) >= CAPS[tier]:
        entry["ending"] = CAP_ENDINGS[tier]
    elif entry["ending"] in COUNTED_ENDINGS:
        entry["ending"] = None


def record(state: dict[str, object], name: str, result: str) -> None:
    entry = loop(state, name)
    if result == "done" or entry["ending"] not in OPEN_ENDINGS:
        return
    entry["passes"] = _int(entry["passes"]) + 1
    entry["last"] = result
    if result == "clean":
        entry["clean"] = _int(entry["clean"]) + 1
    settle(state, name)


def next_step(state: dict[str, object]) -> str:
    tier = state["tier"]
    if tier is None:
        return "pick and record a tier (bl tier)"
    if tier == "T0":
        return "gates, then commit, then bl reset; no rounds at T0"
    pending = open_loops(state)
    if pending:
        first = "" if state["rounds"] else "build through step 9, then "
        return f"{first}run a round for: {', '.join(pending)}"
    return (
        "both loops have an ending: dispositions (step 11), ledger (step 13), ship, "
        "then bl reset"
    )
