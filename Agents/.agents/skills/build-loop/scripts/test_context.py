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

    def bl(self, *args: str, **extra: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [str(SCRIPT), *args],
            cwd=self.repo,
            env=self.env(**({"CLAUDE_CODE_SESSION_ID": SESSION} | extra)),
            capture_output=True,
            text=True,
            check=False,
        )

    def context(self, *point: str, **extra: str) -> subprocess.CompletedProcess[str]:
        return self.bl("context", *point, **extra)

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
        self.write(_request(600_000))
        self.assertIn(
            "before a round: compact (compacts at 60%)", self.context().stdout
        )

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
        self.transcript.write_text(
            f"{json.dumps(_request(300_000))}\n{line}\n", encoding="utf-8"
        )
        self.assertIn("context: 640,000 tokens", self.context().stdout)

    def test_reads_only_the_last_four_megabytes(self) -> None:
        old = f"{json.dumps(_request(500_000))}\n"
        run = json.dumps({"type": "user", "pad": "é" * 2_000_001}, ensure_ascii=False)
        recent = (
            f"{json.dumps(_request(300_000))}\n{json.dumps({'pad': 'x' * 2_000})}\n"
        )
        # An even length puts the 4 MB cut inside a two-byte character
        recent += "\n" * (len(recent) % 2)
        self.transcript.write_text(f"{old}{run}\n{recent}", encoding="utf-8")
        self.assertIn("context: 300,000 tokens", self.context().stdout)
        user = json.dumps({"type": "user"})
        self.transcript.write_text(f"{old}{run}\n{user}\n", encoding="utf-8")
        self.assertIn("no request bl can read", self.context().stderr)

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

    def test_a_session_with_no_logged_request_just_started(self) -> None:
        self.write(
            {"type": "user", "message": {"content": "hi"}}, {"type": "attachment"}
        )
        result = self.context()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(
            "no request logged yet, so this session just started", result.stdout
        )
        self.assertIn("after planning: continue", result.stdout)
        self.assertIn("before a round: continue", result.stdout)
        for text in ("", '{"type": "user", "mess'):
            self.transcript.write_text(text)
            self.assertIn("just started", self.context().stdout)

    def test_checkpoints_show_numbers_only_from_their_limit(self) -> None:
        self.write(_request(240_000))
        self.assertEqual(self.context("plan").stdout, "continue\n")
        self.assertEqual(self.context("round").stdout, "continue\n")
        self.write(_request(300_000))
        self.assertEqual(
            self.context("plan").stdout,
            "compact: 300,000 tokens, 30% of a 1,000,000-token window (limit 25%)\n",
        )
        self.assertEqual(self.context("round").stdout, "continue\n")
        self.write({"type": "user"})
        self.assertEqual(self.context("round").stdout, "continue\n")
        self.git("config", "buildloop.compactBeforeRound", "40")
        self.write(_request(400_000))
        self.assertIn("compact: 400,000 tokens, 40% of", self.context("round").stdout)
        self.write(_request(399_999))
        self.assertEqual(self.context("round").stdout, "continue\n")

    def test_an_unattended_session_always_continues(self) -> None:
        self.write(_request(900_000))
        unattended = {"CLAUDE_CODE_SESSION_ATTENDED": "0"}
        self.assertEqual(self.context("round", **unattended).stdout, "continue\n")
        lost = self.context("plan", CLAUDE_CODE_SESSION_ID="", **unattended)
        self.assertEqual((lost.returncode, lost.stdout), (0, "continue\n"))
        attended = self.context("round", CLAUDE_CODE_SESSION_ATTENDED="1")
        self.assertIn("compact: 900,000 tokens", attended.stdout)
        self.assertIn("90% of a", self.context(**unattended).stdout)

    def test_an_unattended_change_continues_until_turned_off(self) -> None:
        self.write(_request(900_000))
        self.assertIn("unattended off", self.bl("unattended", "--off").stdout)
        self.assertEqual(self.bl("unattended").returncode, 2)
        self.bl("tier", "T1", "--reason", "test")
        self.assertIn("unattended on", self.bl("unattended").stdout)
        self.assertIn("unattended: on", self.bl("state").stdout)
        self.assertEqual(self.context("round").stdout, "continue\n")
        self.assertEqual(self.context("plan").stdout, "continue\n")
        self.assertIn("90% of a", self.context().stdout)
        self.bl("unattended", "--off")
        self.assertIn("compact: 900,000 tokens", self.context("round").stdout)
        self.bl("unattended")
        self.bl("round", "--round", "1", "--review", "clean", "--audit", "clean")
        self.assertEqual(self.bl("unattended", "--off").returncode, 0)
        self.assertIn("compact: 900,000 tokens", self.context("round").stdout)
        self.assertEqual(self.bl("unattended").returncode, 0)
        self.assertEqual(self.context("round").stdout, "continue\n")
        self.assertIn(
            "ship, then the final report, then bl reset", self.bl("state").stdout
        )
        self.bl("reset", "--force")
        self.assertNotIn("unattended", self.bl("state").stdout)
        self.assertIn("compact: 900,000 tokens", self.context("round").stdout)
        self.bl("tier", "T0", "--reason", "test")
        self.bl("unattended")
        self.assertIn("then the final report, then bl reset", self.bl("state").stdout)

    def test_an_unreadable_transcript_fails_loudly(self) -> None:
        reply = {"type": "assistant", "message": {"model": "claude-opus-5-5"}}
        renamed = _request(700_000) | {"type": "model_response"}
        ran = {"type": "user", "message": {"content": [{"type": "tool_result"}]}}
        usage = {"input_tokens": 10, "cache_creation_input_tokens": 90}
        moved = {"type": "assistant", "message": {"usage": usage}}
        shapes = ([reply], [{"entry": _request(700_000)}], [renamed, ran], [moved])
        for lines in shapes:
            self.write(*lines)
            result = self.context("round")
            self.assertEqual(result.returncode, 1, lines)
            self.assertIn("no request bl can read", result.stderr)
        self.transcript.write_text("not json\n" * 3)
        self.assertEqual(self.context("round").returncode, 1)
        error: dict[str, object] = {"type": "assistant", "isApiErrorMessage": True}
        synthetic = {"type": "assistant", "message": {"model": "<synthetic>"}}
        self.write(error, synthetic, {"type": "user", "message": {"content": "hi"}})
        self.assertIn("just started", self.context().stdout)

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
