"""Black-box tests for bl context, which reads context use from the transcript.

Run: python3 -m unittest discover -s <this directory> -p 'test_*.py'
"""

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent / "bl"
SESSION = "11111111-2222-3333-4444-555555555555"


def _request(tokens: int, *, sidechain: bool = False) -> dict[str, object]:
    usage = {
        "input_tokens": 10,
        "cache_creation_input_tokens": 90,
        "cache_read_input_tokens": tokens - 100,
    }
    return {"type": "assistant", "isSidechain": sidechain, "message": {"usage": usage}}


class ContextTests(unittest.TestCase):
    def setUp(self) -> None:
        self.home = Path(self.enterContext(tempfile.TemporaryDirectory()))
        self.repo = self.home / "repo"
        self.repo.mkdir()
        self.git("init", "-q")
        project = self.home / ".claude" / "projects" / "-repo"
        project.mkdir(parents=True)
        self.transcript = project / f"{SESSION}.jsonl"

    def env(self, **extra: str) -> dict[str, str]:
        drop = ("GIT_", "AI_AGENT", "CLAUDE")
        env = {k: v for k, v in os.environ.items() if not k.startswith(drop)}
        env.update(HOME=str(self.home), GIT_CONFIG_GLOBAL=os.devnull)
        return env | {"GIT_CONFIG_NOSYSTEM": "1"} | extra

    def git(self, *args: str) -> None:
        subprocess.run(["git", *args], cwd=self.repo, env=self.env(), check=True)

    def write(self, *lines: object) -> None:
        text = "".join(f"{json.dumps(line)}\n" for line in lines)
        self.transcript.write_text(text + '{"type": "assistant", "message": {"usa')

    def context(self, **extra: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [str(SCRIPT), "context"],
            cwd=self.repo,
            env=self.env(**({"CLAUDE_CODE_SESSION_ID": SESSION} | extra)),
            capture_output=True,
            text=True,
            check=False,
        )

    def test_reads_the_latest_main_thread_request(self) -> None:
        user = {"type": "user", "message": {"content": "hi"}}
        self.write(
            _request(100_000),
            user,
            _request(300_000),
            _request(900_000, sidechain=True),
        )
        result = self.context()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(
            "context: 300,000 tokens, 30% of a 1,000,000-token window", result.stdout
        )
        self.assertIn("after planning: compact (compacts at 25%)", result.stdout)
        self.assertIn("before a round: continue (compacts at 60%)", result.stdout)

    def test_window_and_thresholds_come_from_git_config(self) -> None:
        self.write(_request(100_000))
        self.git("config", "buildloop.contextWindow", "200000")
        self.git("config", "buildloop.compactBeforeRound", "40")
        result = self.context()
        self.assertIn("50% of a 200,000-token window", result.stdout)
        self.assertIn("before a round: compact (compacts at 40%)", result.stdout)

    def test_ignores_unusable_config_and_honors_a_moved_config_dir(self) -> None:
        self.write(_request(100_000))
        self.git("config", "buildloop.contextWindow", "0")
        self.assertIn("10% of a 1,000,000-token window", self.context().stdout)
        moved = self.home / "moved"
        self.transcript.parent.rename(moved)
        result = self.context(CLAUDE_CONFIG_DIR=str(self.home))
        self.assertEqual(result.returncode, 1)
        (moved.parent / "projects").mkdir()
        moved.rename(moved.parent / "projects" / "-repo")
        result = self.context(CLAUDE_CONFIG_DIR=str(self.home))
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_fails_clearly_without_a_session_or_a_transcript(self) -> None:
        self.write(_request(100_000))
        missing = self.context(CLAUDE_CODE_SESSION_ID="")
        self.assertEqual(missing.returncode, 1)
        self.assertIn("check /context instead", missing.stderr)
        other = self.context(CLAUDE_CODE_SESSION_ID="not-this-session")
        self.assertEqual(other.returncode, 1)
        self.assertIn("no transcript for session", other.stderr)


if __name__ == "__main__":
    unittest.main()
