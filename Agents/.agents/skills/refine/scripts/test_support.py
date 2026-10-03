"""Scratch-repository fixture shared by the refine CLI and gate tests."""

import json
import os
import shlex
import subprocess
import tempfile
import unittest
from pathlib import Path
from typing import cast

SCRIPT = Path(__file__).resolve().parent / "refine"
AGENT = "claude-code_test"
BLOCKED = "refine gate commit blocked"


class GateTestCase(unittest.TestCase):
    def setUp(self) -> None:
        self.repo = Path(self.enterContext(tempfile.TemporaryDirectory())) / "repo"
        self.init_repo(self.repo)
        self.write("seed.txt", "seed\n")
        self.git("add", "seed.txt")
        self.commit(agent=None)

    def init_repo(self, path: Path) -> None:
        path.mkdir()
        self.git("init", "-q", "-b", "main", cwd=path)
        for key, value in (
            ("user.email", "test@example.com"),
            ("user.name", "test"),
            ("hook.refine.event", "pre-commit"),
            ("hook.refine.command", f"{shlex.quote(str(SCRIPT))} gate"),
        ):
            self.git("config", key, value, cwd=path)

    def env(self, agent: str | None, **extra: str) -> dict[str, str]:
        env = {
            k: v
            for k, v in os.environ.items()
            if not k.startswith(("GIT_", "AI_AGENT", "CLAUDECODE", "REFINE_"))
        }
        env.update({"GIT_CONFIG_GLOBAL": os.devnull, "GIT_CONFIG_NOSYSTEM": "1"})
        if agent:
            env["AI_AGENT"] = agent
        env.update(extra)
        return env

    def _run(
        self, argv: list[str], cwd: Path | None, env: dict[str, str]
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            argv,
            cwd=cwd or self.repo,
            env=env,
            capture_output=True,
            text=True,
            check=False,
        )

    def git(
        self,
        *args: str,
        agent: str | None = AGENT,
        cwd: Path | None = None,
        extra: dict[str, str] | None = None,
    ) -> subprocess.CompletedProcess[str]:
        return self._run(["git", *args], cwd, self.env(agent, **(extra or {})))

    def refine(
        self, *args: str, cwd: Path | None = None
    ) -> subprocess.CompletedProcess[str]:
        return self._run([str(SCRIPT), *args], cwd, self.env(AGENT))

    def write(self, path: str, content: str) -> None:
        target = self.repo / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content)

    def stage(self, path: str, content: str) -> None:
        self.write(path, content)
        self.git("add", path)

    def commit(
        self, agent: str | None = AGENT, **extra: str
    ) -> subprocess.CompletedProcess[str]:
        return self.git("commit", "-q", "-m", "change", agent=agent, extra=extra)

    def assert_blocked(self, result: subprocess.CompletedProcess[str]) -> None:
        self.assertNotEqual(result.returncode, 0, result.stderr)
        self.assertIn(BLOCKED, result.stderr)

    def assert_committed(self, result: subprocess.CompletedProcess[str]) -> None:
        self.assertEqual(result.returncode, 0, result.stderr)

    def log_events(self) -> list[str]:
        log = self.repo / ".git" / "refine" / "log.jsonl"
        if not log.exists():
            return []
        return [json.loads(line)["event"] for line in log.read_text().splitlines()]

    def scope(self, cwd: Path | None = None) -> dict[str, object]:
        result = self.refine("scope", cwd=cwd)
        self.assertEqual(result.returncode, 0, result.stderr)
        payload: dict[str, object] = json.loads(result.stdout)
        return payload

    def files(self, report: dict[str, object]) -> list[dict[str, object]]:
        return cast("list[dict[str, object]]", report["files"])

    def kinds(self, report: dict[str, object]) -> dict[str, str]:
        return {str(f["path"]): str(f["kind"]) for f in self.files(report)}
