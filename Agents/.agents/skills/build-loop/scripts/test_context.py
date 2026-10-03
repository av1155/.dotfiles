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


def _boundary(**extra: object) -> dict[str, object]:
    return {"type": "system", "subtype": "compact_boundary", **extra}


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
        self.write(_request(597_000))
        result = self.context()
        self.assertIn("59% of a 1,000,000-token window", result.stdout)
        self.assertIn("before a round: continue", result.stdout)

    def test_skips_api_errors_and_splits_only_on_newlines(self) -> None:
        keys = (
            "input_tokens",
            "cache_creation_input_tokens",
            "cache_read_input_tokens",
        )
        usage = dict.fromkeys(keys, 0)
        message = {"model": "<synthetic>", "usage": usage}
        error = {"type": "assistant", "isApiErrorMessage": True, "message": message}
        self.write(_request(786_168), error, {"type": "user"})
        self.assertIn("context: 786,168 tokens, 78% of", self.context().stdout)
        line = json.dumps(_request(640_000) | {"note": "\u2028"}, ensure_ascii=False)
        self.transcript.write_text(f"{json.dumps(_request(300_000))}\n{line}\n")
        self.assertIn("context: 640,000 tokens", self.context().stdout)

    def test_a_newer_compaction_replaces_the_stale_request(self) -> None:
        carried = _boundary(
            compactMetadata={"preTokens": 850_000, "postTokens": 23_460}
        )
        summary = {"type": "user", "isCompactSummary": True}
        self.write(_request(850_000), carried, summary)
        result = self.context()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(
            "23,460 tokens carried over by a compaction, 2% of", result.stdout
        )
        self.assertIn("before a round: continue", result.stdout)
        self.write(_request(850_000), carried, summary, _request(72_112))
        self.assertIn("context: 72,112 tokens, 7% of", self.context().stdout)
        self.write(_request(300_000), carried | {"isSidechain": True})
        self.assertIn("context: 300,000 tokens, 30% of", self.context().stdout)
        self.write(_request(850_000), _boundary())
        unmeasured = self.context()
        self.assertEqual(unmeasured.returncode, 1)
        self.assertIn("compacted since the last logged request", unmeasured.stderr)

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
        result = self.context()
        self.assertIn("10% of a 1,000,000-token window", result.stdout)
        self.assertIn("ignoring buildloop.contextWindow=0", result.stderr)
        config = self.home / "config"
        (self.home / ".claude").rename(config)
        result = self.context(CLAUDE_CONFIG_DIR=str(config))
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
