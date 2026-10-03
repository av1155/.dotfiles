"""Black-box tests for the bl state helper and its warn-only git hooks.

Run: python3 -m unittest discover -s <this directory> -p 'test_*.py'
"""

import json
import os
import shlex
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from typing import cast

SCRIPT = Path(__file__).resolve().parent / "bl"
AGENT = "claude-code_test"


class BlTestCase(unittest.TestCase):
    def setUp(self) -> None:
        root = Path(self.enterContext(tempfile.TemporaryDirectory()))
        self.remote = root / "remote.git"
        self.repo = root / "repo"
        subprocess.run(
            ["git", "init", "-q", "--bare", str(self.remote)],
            check=True,
            env=self.env(None),
        )
        self.repo.mkdir()
        self.git("init", "-q", "-b", "main")
        for key, value in (("user.email", "t@example.com"), ("user.name", "t")):
            self.git("config", key, value)
        script = shlex.quote(str(SCRIPT))
        self.git("config", "hook.bltier.event", "pre-commit")
        self.git("config", "hook.bltier.command", f"{script} check-tier")
        self.git("config", "hook.blledger.event", "pre-push")
        self.git("config", "hook.blledger.command", f"{script} check-ledger")
        self.git("remote", "add", "origin", str(self.remote))
        (self.repo / "seed.txt").write_text("seed\n")
        self.git("add", "seed.txt")
        self.git("commit", "-q", "-m", "seed", agent=None)

    def env(self, agent: str | None) -> dict[str, str]:
        drop = ("GIT_", "AI_AGENT", "CLAUDECODE")
        env = {k: v for k, v in os.environ.items() if not k.startswith(drop)}
        env.update({"GIT_CONFIG_GLOBAL": os.devnull, "GIT_CONFIG_NOSYSTEM": "1"})
        if agent:
            env["AI_AGENT"] = agent
        return env

    def _run(
        self, argv: list[str], agent: str | None
    ) -> subprocess.CompletedProcess[str]:
        env = self.env(agent)
        return subprocess.run(
            argv, cwd=self.repo, env=env, capture_output=True, text=True, check=False
        )

    def git(
        self, *args: str, agent: str | None = AGENT
    ) -> subprocess.CompletedProcess[str]:
        return self._run(["git", *args], agent)

    def bl(self, *args: str) -> subprocess.CompletedProcess[str]:
        return self._run([str(SCRIPT), *args], AGENT)

    def state(self) -> dict[str, object]:
        result = self.bl("state", "--json")
        self.assertEqual(result.returncode, 0, result.stderr)
        payload: dict[str, object] = json.loads(result.stdout)
        return payload

    def loop(self, name: str) -> dict[str, object]:
        return cast("dict[str, dict[str, object]]", self.state()["loops"])[name]

    def rounds(self, *results: tuple[str, str]) -> None:
        for review, audit in results:
            result = self.bl("round", "--review", review, "--audit", audit)
            self.assertEqual(result.returncode, 0, result.stderr)


class TierAndPlanTests(BlTestCase):
    def test_fresh_branch_reports_no_tier(self) -> None:
        result = self.bl("state")
        self.assertIn("tier: not set", result.stdout)
        self.assertIn("updated: never", result.stdout)
        self.assertIn("next: pick and record a tier", result.stdout)
        self.bl("tier", "T1", "--reason", "fix")
        state = self.bl("state").stdout
        self.assertRegex(state, r"updated: \d{4}-\d\d-\d\dT")
        self.assertIn("next: build through step 9, then run a round for", state)

    def test_tier_records_the_change_base_once(self) -> None:
        head = self.git("rev-parse", "HEAD").stdout.strip()
        self.bl("tier", "T1", "--reason", "fix")
        (self.repo / "app.py").write_text("x = 1\n")
        self.git("add", "app.py")
        self.git("commit", "-q", "-m", "work", agent=None)
        self.bl("tier", "T2", "--reason", "grew")
        self.assertEqual(self.state()["base"], head)
        self.assertIn(f"base: {head}", self.bl("state").stdout)

    def test_tier_can_rise_but_lowers_only_with_force(self) -> None:
        self.assertEqual(self.bl("tier", "T2", "--reason", "feature").returncode, 0)
        self.assertEqual(self.bl("tier", "T1", "--reason", "smaller").returncode, 2)
        self.assertEqual(self.state()["tier"], "T2")
        self.assertEqual(
            self.bl("tier", "T3", "--reason", "touches auth").returncode, 0
        )
        self.assertEqual(
            self.bl("tier", "T1", "--reason", "user said", "--force").returncode, 0
        )
        self.assertEqual(self.state()["tier"], "T1")

    def test_plan_path_is_reboot_safe_and_recorded(self) -> None:
        self.git("checkout", "-q", "-b", "feat/x-y", agent=None)
        path = Path(self.bl("plan", "--path").stdout.strip())
        self.assertEqual(path.name, "plan.md")
        self.assertEqual(path.parent.name, "feat%2Fx-y")
        self.assertTrue(path.parent.is_dir())
        self.assertIn(str(self.repo / ".git" / "build-loop"), str(path.resolve()))
        path.write_text("plan\n")
        self.assertEqual(self.bl("plan", str(path)).returncode, 0)
        self.assertEqual(self.state()["plan"], str(path.resolve()))

    def test_reset_archives_the_state_and_plan(self) -> None:
        self.bl("tier", "T1", "--reason", "fix")
        self.rounds(("clean", "clean"))
        plan = Path(self.bl("plan", "--path").stdout.strip())
        plan.write_text("old plan\n")
        self.assertIn("ship, then bl reset", self.bl("state").stdout)
        self.assertEqual(self.bl("reset").returncode, 0)
        archive_root = self.repo / ".git" / "build-loop" / ".archive"
        [archive] = list(archive_root.iterdir())
        self.assertTrue((archive / "state.json").is_file())
        self.assertEqual((archive / "plan.md").read_text(), "old plan\n")
        self.assertFalse(plan.exists())
        self.assertIsNone(self.state()["tier"])
        fresh = {"passes": 0, "clean": 0, "ending": None, "last": None}
        self.assertEqual(self.loop("review"), fresh)
        self.assertIn("no build-loop state for main", self.bl("reset").stdout)

    def test_reset_leaves_other_branches_alone(self) -> None:
        self.git("checkout", "-q", "-b", "x", agent=None)
        self.bl("tier", "T2", "--reason", "feature")
        self.git("checkout", "-q", "-b", "x.json", agent=None)
        self.bl("plan", "--path")
        self.bl("reset")
        self.git("checkout", "-q", "x", agent=None)
        self.assertEqual(self.state()["tier"], "T2")

    def test_similar_branch_names_keep_separate_state(self) -> None:
        self.git("checkout", "-q", "-b", "a/b", agent=None)
        self.bl("tier", "T2", "--reason", "feature")
        self.git("checkout", "-q", "-b", "a__b", agent=None)
        self.assertIsNone(self.state()["tier"])

    def test_rounds_need_a_tier(self) -> None:
        self.assertEqual(
            self.bl("round", "--review", "clean", "--audit", "clean").returncode, 1
        )
        self.bl("tier", "T0", "--reason", "docs")
        self.assertEqual(
            self.bl("round", "--review", "clean", "--audit", "clean").returncode, 1
        )


class RoundTests(BlTestCase):
    def test_t2_counts_clean_passes_cumulatively(self) -> None:
        self.bl("tier", "T2", "--reason", "feature")
        self.rounds(("clean", "dirty"), ("dirty", "clean"), ("clean", "dirty"))
        self.assertEqual(
            self.loop("review"),
            {"passes": 3, "clean": 2, "ending": "two clean", "last": "clean"},
        )
        self.assertEqual(
            self.loop("audit"),
            {"passes": 3, "clean": 1, "ending": None, "last": "dirty"},
        )
        self.rounds(("done", "clean"))
        self.assertEqual(self.loop("review")["passes"], 3)
        self.assertEqual(self.loop("audit")["ending"], "two clean")
        self.assertIn("both loops have an ending", self.bl("state").stdout)

    def test_t1_ends_on_one_clean_or_a_cap_of_two(self) -> None:
        self.bl("tier", "T1", "--reason", "small fix")
        self.rounds(("clean", "dirty"), ("done", "dirty"))
        self.assertEqual(self.loop("review")["ending"], "one clean")
        self.assertEqual(self.loop("audit")["ending"], "cap of two")

    def test_t3_caps_at_eight(self) -> None:
        self.bl("tier", "T3", "--reason", "money")
        self.rounds(*[("dirty", "dirty")] * 8)
        self.assertEqual(self.loop("review")["ending"], "cap of eight")
        self.rounds(("dirty", "dirty"))
        self.assertEqual(self.loop("review")["passes"], 8)

    def test_tier_change_rechecks_counted_endings(self) -> None:
        self.bl("tier", "T1", "--reason", "small fix")
        self.rounds(("clean", "dirty"), ("done", "dirty"))
        self.assertEqual(self.bl("tier", "T3", "--reason", "new change").returncode, 2)
        self.bl("tier", "T3", "--reason", "touches auth", "--reopen")
        review = {"passes": 1, "clean": 1, "ending": None, "last": "clean"}
        self.assertEqual(self.loop("review"), review)
        audit = {"passes": 2, "clean": 0, "ending": None, "last": "dirty"}
        self.assertEqual(self.loop("audit"), audit)
        self.bl("ending", "--loop", "audit", "--token", "stopped early (authorised)")
        self.bl("tier", "T1", "--reason", "user said", "--force")
        self.assertEqual(self.loop("review")["ending"], "one clean")
        self.assertEqual(self.loop("audit")["ending"], "stopped early (authorised)")

    def test_a_reopened_loop_needs_a_clean_last_pass(self) -> None:
        self.bl("tier", "T2", "--reason", "feature")
        self.rounds(("clean", "clean"), ("clean", "clean"))
        self.bl("ending", "--loop", "review", "--token", "in progress")
        self.rounds(("dirty", "done"))
        review = {"passes": 3, "clean": 2, "ending": "in progress", "last": "dirty"}
        self.assertEqual(self.loop("review"), review)
        self.rounds(("clean", "done"))
        self.assertEqual(self.loop("review")["ending"], "two clean")

    def test_retiering_ignores_passes_an_ended_loop_never_counted(self) -> None:
        self.bl("tier", "T1", "--reason", "fix")
        self.rounds(("clean", "dirty"), ("dirty", "dirty"))
        self.bl("tier", "T1", "--reason", "same change", "--reopen")
        self.assertEqual(self.loop("review")["ending"], "one clean")

    def test_manual_ending(self) -> None:
        self.bl("tier", "T2", "--reason", "feature")
        result = self.bl(
            "ending", "--loop", "audit", "--token", "stopped early (authorised)"
        )
        self.assertEqual(result.returncode, 0)
        self.assertEqual(self.loop("audit")["ending"], "stopped early (authorised)")
        self.assertEqual(
            self.bl("ending", "--loop", "audit", "--token", "").returncode, 2
        )


class HookTests(BlTestCase):
    def commit(
        self, agent: str | None, path: str = "app.py"
    ) -> subprocess.CompletedProcess[str]:
        (self.repo / path).write_text(
            f"x = {len(self.git('log', '--oneline').stdout)}\n"
        )
        self.git("add", path)
        return self.git("commit", "-q", "-m", "change", agent=agent)

    def test_check_tier_warns_agents_without_blocking(self) -> None:
        result = self.commit(AGENT)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("no tier recorded", result.stderr)
        self.assertNotIn("no tier recorded", self.commit(None).stderr)
        self.bl("tier", "T1", "--reason", "fix")
        self.assertNotIn("no tier recorded", self.commit(AGENT).stderr)

    def test_check_tier_is_quiet_on_docs_only_commits(self) -> None:
        for path in ("NOTES.md", "LICENSE", "LICENSE-2.0.txt", "CHANGELOG.md"):
            self.assertNotIn("no tier recorded", self.commit(AGENT, path).stderr)
        for path in ("CMakeLists.txt", "requirements.txt", "LICENSE_KEY.ts"):
            self.assertIn("no tier recorded", self.commit(AGENT, path).stderr)

    def test_late_tier_takes_the_base_the_warning_names(self) -> None:
        head = self.git("rev-parse", "HEAD").stdout.strip()
        self.assertIn(f"--base {head}", self.commit(AGENT).stderr)
        self.bl("tier", "T1", "--reason", "fix", "--base", head)
        self.assertEqual(self.state()["base"], head)
        self.assertEqual(
            self.bl("tier", "T1", "--reason", "x", "--base", "nope").returncode, 1
        )

    def test_check_ledger_checks_the_branches_being_pushed(self) -> None:
        self.git("checkout", "-q", "-b", "open-y", agent=None)
        self.bl("tier", "T2", "--reason", "feature")
        self.git("checkout", "-q", "main", agent=None)
        pushed = self.git("push", "-q", "origin", "open-y").stderr
        self.assertIn("pushing open-y before these loops have an ending", pushed)
        self.git("tag", "v1", agent=None)
        self.assertNotIn("build-loop", self.git("push", "-q", "origin", "v1").stderr)

    def test_hooks_honor_every_configured_agent_prefix(self) -> None:
        self.assertNotIn("no tier recorded", self.commit("codex_1").stderr)
        self.git("config", "buildloop.agents", "claude-code")
        self.git("config", "--add", "buildloop.agents", "codex")
        self.assertIn("no tier recorded", self.commit("codex_1").stderr)
        self.assertIn("no tier recorded", self.commit(AGENT).stderr)

    def test_check_ledger_warns_on_early_agent_push(self) -> None:
        self.bl("tier", "T2", "--reason", "feature")
        result = self.git("push", "-q", "origin", "main")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("before these loops have an ending: review, audit", result.stderr)
        self.rounds(("clean", "clean"), ("clean", "clean"))
        self.commit(AGENT)
        self.assertNotIn("build-loop", self.git("push", "-q", "origin", "main").stderr)

    def test_malformed_state_never_breaks_the_hooks(self) -> None:
        state_file = self.repo / ".git" / "build-loop" / "main" / "state.json"
        state_file.parent.mkdir(parents=True)
        partial = {"tier": "T2", "rounds": "x", "loops": {"review": {"clean": 1}}}
        state_file.write_text(json.dumps(partial))
        result = self.git("push", "-q", "origin", "main")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("before these loops have an ending: review, audit", result.stderr)
        partial_loop = {"passes": 0, "clean": 1, "ending": None, "last": None}
        self.assertEqual(self.loop("review"), partial_loop)
        state_file.write_text('{"tier": "T9"}')
        self.assertIn("tier: not set", self.bl("state").stdout)

    def test_human_hooks_run_no_git(self) -> None:
        for command in ("check-tier", "check-ledger"):
            result = subprocess.run(
                [sys.executable, str(SCRIPT), command],
                cwd=self.repo,
                env={**self.env(None), "PATH": str(self.repo)},
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_checks_off_and_humans_stay_silent(self) -> None:
        self.bl("tier", "T2", "--reason", "feature")
        self.assertNotIn(
            "build-loop", self.git("push", "-q", "origin", "main", agent=None).stderr
        )
        self.git("config", "buildloop.checks", "off")
        self.bl("tier", "T3", "--reason", "x")
        self.commit(AGENT)
        self.assertNotIn("build-loop", self.git("push", "-q", "origin", "main").stderr)


if __name__ == "__main__":
    unittest.main()
