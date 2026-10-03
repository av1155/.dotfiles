"""Staged-change model shared by the refine commands and the pre-commit gate."""

import contextlib
import datetime as dt
import fnmatch
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
from typing import cast

if sys.version_info < (3, 11):
    sys.exit("refine needs Python 3.11 or later as python3 on PATH")

DOC_SUFFIXES = frozenset({".md", ".mdx", ".markdown", ".rst", ".adoc", ".txt"})
DOC_NAME = re.compile(r"(LICEN[CS]E|NOTICE|AUTHORS|COPYING|CHANGELOG)([-_.][\w.-]*)?")
NOT_DOCS = frozenset({"CMakeLists.txt"})
LOCKFILES = frozenset({
    "pnpm-lock.yaml", "package-lock.json", "npm-shrinkwrap.json", "yarn.lock",
    "bun.lock", "bun.lockb", "deno.lock", "Cargo.lock", "poetry.lock", "uv.lock",
    "Pipfile.lock", "pdm.lock", "composer.lock", "Gemfile.lock", "go.sum", "mix.lock",
    "pubspec.lock", "Podfile.lock", "flake.lock", "packages.lock.json",
    "gradle.lockfile", "Package.resolved",
})  # fmt: skip
GENERATED_GLOBS = (
    "*.min.js", "*.min.css", "*.map", "*.snap", "*.pb.go", "*_pb2.py", "*_pb2_grpc.py",
    "*.g.dart", "*.freezed.dart", "*.generated.*", "*__generated__/*", "generated/*",
    "*/generated/*", "node_modules/*", "*/node_modules/*", "vendor/*", "third_party/*",
    "*/third_party/*",
)  # fmt: skip
TEST_DIRS = frozenset({
    "test", "tests", "__tests__", "spec", "specs", "e2e", "__mocks__", "fixtures",
    "testdata",
})  # fmt: skip
TEST_GLOBS = (
    "*.test.*", "*.spec.*", "*_test.*", "test_*.py", "*_spec.rb", "*Test.java",
    "*Tests.java", "*Test.kt", "*Tests.cs", "conftest.py",
)  # fmt: skip
CONFIG_SUFFIXES = frozenset({
    ".json", ".jsonc", ".json5", ".yaml", ".yml", ".toml", ".ini", ".cfg", ".conf",
    ".properties",
})  # fmt: skip
CONFIG_NAMES = frozenset({
    "Dockerfile", ".gitignore", ".gitattributes", ".gitconfig", ".npmrc", ".nvmrc",
    ".editorconfig", ".dockerignore",
})  # fmt: skip
IN_PROGRESS = (
    ("MERGE_HEAD", "merge"),
    ("CHERRY_PICK_HEAD", "cherry-pick"),
    ("REVERT_HEAD", "revert"),
    ("rebase-merge", "rebase"),
    ("rebase-apply", "rebase"),
)


class RefineError(Exception):
    pass


@dataclass(frozen=True, slots=True)
class Repo:
    root: Path
    git_dir: Path
    head: str | None
    base: str
    branch: str

    @property
    def state_dir(self) -> Path:
        return self.git_dir / "refine"


@dataclass(frozen=True, slots=True)
class Entry:
    path: str
    status: str
    blob: str
    kind: str
    reason: str
    added: int
    deleted: int
    origin: str | None = None

    @property
    def changed(self) -> int:
        return self.added + self.deleted


def decode(data: bytes) -> str:
    return data.decode("utf-8", "surrogateescape")


GIT_TIMEOUT_SECONDS = 60


def run(*args: str, stdin: bytes | None = None) -> subprocess.CompletedProcess[bytes]:
    try:
        return subprocess.run(
            ["git", *args],
            input=stdin,
            capture_output=True,
            check=False,
            timeout=GIT_TIMEOUT_SECONDS,
        )
    except subprocess.TimeoutExpired as exc:
        message = f"git {' '.join(args)} timed out after {GIT_TIMEOUT_SECONDS}s"
        raise RefineError(message) from exc


def git(*args: str, stdin: bytes | None = None) -> bytes:
    proc = run(*args, stdin=stdin)
    if proc.returncode != 0:
        message = f"git {' '.join(args)} failed: {decode(proc.stderr).strip()}"
        raise RefineError(message)
    return proc.stdout


def config_all(key: str) -> list[str]:
    proc = run("config", "--get-all", key)
    if proc.returncode != 0:
        return []
    return [line.strip() for line in decode(proc.stdout).splitlines() if line.strip()]


def config(key: str, default: str) -> str:
    values = config_all(key)
    return values[-1] if values else default


def config_int(key: str, default: int) -> int:
    try:
        return int(config(key, str(default)))
    except ValueError:
        return default


def open_repo() -> Repo:
    paths = git("rev-parse", "--path-format=absolute", "--show-toplevel", "--git-dir")
    try:
        toplevel, git_dir = decode(paths).splitlines()
    except ValueError as exc:
        message = "run inside a git working tree"
        raise RefineError(message) from exc
    # git prints root-relative paths but resolves pathspecs from the cwd.
    os.chdir(toplevel)
    head = decode(run("rev-parse", "--verify", "--quiet", "HEAD").stdout).strip()
    base = head or decode(git("hash-object", "-t", "tree", "/dev/null")).strip()
    branch = decode(run("symbolic-ref", "--quiet", "--short", "HEAD").stdout).strip()
    return Repo(Path(toplevel), Path(git_dir), head or None, base, branch or "detached")


def in_progress(repo: Repo) -> str | None:
    for name, label in IN_PROGRESS:
        if (repo.git_dir / name).exists():
            return label
    return None


def _parse_raw(data: bytes) -> list[tuple[str, str, str, str]]:
    tokens = data.split(b"\0")
    records: list[tuple[str, str, str, str]] = []
    for meta, path in zip(tokens[0::2], tokens[1::2]):
        if not meta.startswith(b":"):
            break
        _, dst_mode, _, dst_blob, status = decode(meta[1:]).split(" ", 4)
        records.append((status[:1], dst_mode, dst_blob, decode(path)))
    return records


def _parse_numstat(
    data: bytes,
) -> tuple[dict[str, tuple[int, int] | None], dict[str, str]]:
    counts: dict[str, tuple[int, int] | None] = {}
    origins: dict[str, str] = {}
    tokens = iter(data.split(b"\0"))
    for token in tokens:
        if not token:
            continue
        added, deleted, path = decode(token).split("\t", 2)
        if not path:  # a rename: its source and destination paths follow
            origin, path = decode(next(tokens)), decode(next(tokens))
            origins[path] = origin
        counts[path] = None if added == "-" else (int(added), int(deleted))
    return counts, origins


def _linguist(paths: list[str]) -> dict[str, str]:
    if not paths:
        return {}
    payload = b"".join(p.encode("utf-8", "surrogateescape") + b"\0" for p in paths)
    attrs = ("linguist-generated", "linguist-vendored")
    data = git("check-attr", "--cached", "-z", "--stdin", *attrs, stdin=payload)
    tokens = data.split(b"\0")
    return {
        decode(path): decode(attr)
        for path, attr, value in zip(tokens[0::3], tokens[1::3], tokens[2::3])
        if decode(value) in {"set", "true"}
    }


def _matches(path: str, globs: tuple[str, ...] | list[str]) -> bool:
    return any(fnmatch.fnmatchcase(path, pattern) for pattern in globs)


def _exempt_reason(path: str, status: str, mode: str, binary: bool) -> str | None:
    pure = PurePosixPath(path)
    name = pure.name
    reasons = (
        (status == "D", "deleted"),
        (status == "U", "unmerged"),
        (mode in {"120000", "160000"}, "symlink or submodule"),
        (binary, "binary"),
        (name in LOCKFILES or name.endswith(".lock"), "lockfile"),
        (_matches(path, GENERATED_GLOBS), "generated or vendored"),
        (pure.suffix.lower() in DOC_SUFFIXES and name not in NOT_DOCS, "docs"),
        (DOC_NAME.fullmatch(name) is not None, "docs"),
    )
    return next((reason for hit, reason in reasons if hit), None)


def classify(
    path: str, status: str, mode: str, binary: bool, override: str | None = None
) -> tuple[str, str]:
    reason = _exempt_reason(path, status, mode, binary) or override
    if reason:
        return "exempt", reason
    pure = PurePosixPath(path)
    dirs = set(pure.parts[:-1])
    if dirs & TEST_DIRS or _matches(pure.name, TEST_GLOBS):
        return "test", "test"
    if "migrations" in dirs and status != "A":
        return "migration-existing", "existing migration"
    suffix = pure.suffix.lower()
    if (
        suffix in CONFIG_SUFFIXES
        or pure.name in CONFIG_NAMES
        or pure.parts[0] == ".github"
    ):
        return "config", "config"
    return "code", "code"


def staged(repo: Repo) -> list[Entry]:
    common = ("--cached", "-z", "--no-ext-diff")
    raw = git("diff", *common, "--no-renames", "--raw", "--no-abbrev", repo.base)
    records = _parse_raw(raw)
    counts, origins = _parse_numstat(git("diff", *common, "-M", "--numstat", repo.base))
    linguist = _linguist([path for status, _, _, path in records if status != "D"])
    exempt_globs = config_all("refine.exempt")
    entries: list[Entry] = []
    for status, mode, blob, path in records:
        count = counts.get(path)
        glob_hit = "refine.exempt" if _matches(path, exempt_globs) else None
        unchanged = "no line changes" if count == (0, 0) else None
        override = linguist.get(path) or glob_hit or unchanged
        kind, reason = classify(
            path, status, mode, binary=count is None, override=override
        )
        added, deleted = count or (0, 0)
        origin = origins.get(path)
        entries.append(Entry(path, status, blob, kind, reason, added, deleted, origin))
    return entries


def reviewable(entries: list[Entry]) -> list[Entry]:
    return [entry for entry in entries if entry.kind != "exempt"]


def index_blobs(paths: list[str]) -> dict[str, str]:
    if not paths:
        return {}
    specs = [f":(literal){path}" for path in paths]
    blobs: dict[str, str] = {}
    for record in git("ls-files", "-s", "-z", "--", *specs).split(b"\0"):
        if record:
            meta, path = decode(record).split("\t", 1)
            blobs[path] = meta.split()[1]
    return blobs


def unstaged() -> set[str]:
    data = git("diff", "--name-only", "-z", "--no-ext-diff")
    return {decode(token) for token in data.split(b"\0") if token}


def now() -> str:
    return dt.datetime.now(dt.UTC).isoformat(timespec="seconds")


def write_json(path: Path, payload: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix(".tmp")
    temp.write_text(json.dumps(payload, indent=2) + "\n")
    os.replace(temp, path)


def log(repo: Repo, event: dict[str, object]) -> None:
    record = {"ts": now(), "branch": repo.branch, **event}
    # Logging must never decide whether a commit lands.
    with contextlib.suppress(OSError):
        repo.state_dir.mkdir(parents=True, exist_ok=True)
        with (repo.state_dir / "log.jsonl").open("a") as handle:
            handle.write(json.dumps(record) + "\n")


def load_stamp(repo: Repo) -> tuple[str | None, dict[str, str]]:
    try:
        raw: object = json.loads((repo.state_dir / "stamp.json").read_text())
    except (OSError, ValueError):
        return None, {}
    if not isinstance(raw, dict):
        return None, {}
    stamp = cast("dict[str, object]", raw)
    head, entries = stamp.get("head"), stamp.get("entries")
    if not isinstance(entries, dict):
        return None, {}
    pairs = cast("dict[object, object]", entries).items()
    stamped = {str(path): str(blob) for path, blob in pairs}
    return (head if isinstance(head, str) else None), stamped


def stale(repo: Repo, entries: list[Entry]) -> list[str]:
    _head, stamped = load_stamp(repo)
    return [entry.path for entry in entries if stamped.get(entry.path) != entry.blob]
