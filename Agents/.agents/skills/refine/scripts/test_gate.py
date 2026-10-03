"""Black-box tests for the refine pre-commit gate.

Run: python3 -m unittest discover -s <this directory> -p 'test_*.py'
"""

import subprocess
import sys
import time
import unittest

from test_support import SCRIPT, GateTestCase


class GateTests(GateTestCase):
    def test_human_commit_is_never_gated(self) -> None:
        self.stage("app.py", "x = 1\n")
        self.assert_committed(self.commit(agent=None))

    def test_human_gate_runs_no_git(self) -> None:
        result = subprocess.run(
            [sys.executable, str(SCRIPT), "gate"],
            cwd=self.repo,
            env={**self.env(None), "PATH": str(self.repo)},
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_agent_commit_without_stamp_is_blocked(self) -> None:
        self.stage("app.py", "x = 1\n")
        result = self.commit()
        self.assert_blocked(result)
        self.assertIn("app.py", result.stderr)
        self.assertIn("gate-block", self.log_events())

    def test_claudecode_fallback_counts_as_agent(self) -> None:
        self.stage("app.py", "x = 1\n")
        self.assert_blocked(self.commit(agent=None, CLAUDECODE="1"))

    def test_other_agents_are_not_gated_by_default(self) -> None:
        self.stage("app.py", "x = 1\n")
        self.assert_committed(self.commit(agent="pi"))

    def test_every_configured_agent_prefix_is_gated(self) -> None:
        self.git("config", "refine.agents", "claude-code")
        self.git("config", "--add", "refine.agents", "pi")
        self.stage("app.py", "x = 1\n")
        self.assert_blocked(self.commit())
        self.assert_blocked(self.commit(agent="pi_1"))

    def test_stamped_commit_passes(self) -> None:
        self.stage("app.py", "x = 1\n")
        self.assertEqual(self.refine("stamp", "--mode", "light").returncode, 0)
        self.assert_committed(self.commit())
        self.assertIn("gate-pass", self.log_events())

    def test_restaged_change_after_stamp_is_blocked(self) -> None:
        self.stage("app.py", "x = 1\n")
        self.assertEqual(self.refine("stamp", "--mode", "light").returncode, 0)
        self.stage("app.py", "x = 2\n")
        self.assert_blocked(self.commit())

    def test_exempt_only_commits_pass(self) -> None:
        self.git("config", "refine.exempt", "data/*")
        self.stage(".gitattributes", "gen.ts linguist-generated\n")
        self.commit(agent=None)
        for path in (
            "README.md",
            "package-lock.json",
            "gen.ts",
            "data/dump.ts",
            "lib/x.min.js",
        ):
            with self.subTest(path=path):
                self.stage(path, "content\n")
                self.assert_committed(self.commit())

    def test_test_files_need_a_pass(self) -> None:
        self.stage("tests/test_app.py", "def test_x() -> None: ...\n")
        self.assert_blocked(self.commit())

    def test_warn_and_off_modes_let_commits_through(self) -> None:
        self.git("config", "refine.mode", "warn")
        self.stage("a.py", "a = 1\n")
        result = self.commit()
        self.assert_committed(result)
        self.assertIn("refine gate (warn)", result.stderr)
        self.git("config", "refine.mode", "off")
        self.stage("b.py", "b = 1\n")
        result = self.commit()
        self.assert_committed(result)
        self.assertEqual(result.stderr, "")

    def test_unknown_mode_blocks(self) -> None:
        self.git("config", "refine.mode", "blok")
        self.stage("app.py", "x = 1\n")
        self.assert_blocked(self.commit())

    def test_refine_skip_lets_one_commit_through(self) -> None:
        self.stage("app.py", "x = 1\n")
        self.assert_committed(self.commit(REFINE_SKIP="1"))
        self.assertIn("skip", self.log_events())

    def test_commit_all_checks_the_content_being_committed(self) -> None:
        self.stage("app.py", "x = 1\n")
        self.refine("stamp", "--mode", "light")
        self.write("app.py", "x = 3\n")
        self.assert_blocked(self.git("commit", "-q", "-a", "-m", "all"))
        self.write("app.py", "x = 1\n")
        self.assert_committed(self.git("commit", "-q", "-a", "-m", "all"))

    def test_pathspec_commit_uses_the_temporary_index(self) -> None:
        self.stage("a.py", "a = 1\n")
        self.stage("b.py", "b = 1\n")
        self.refine("stamp", "--mode", "light")
        self.write("b.py", "b = 2\n")
        self.assert_committed(self.git("commit", "-q", "-m", "only a", "--", "a.py"))
        self.assert_blocked(self.git("commit", "-q", "-m", "b", "--", "b.py"))

    def test_git_dash_c_from_another_directory(self) -> None:
        self.stage("app.py", "x = 1\n")
        commit = ("-C", str(self.repo), "commit", "-q", "-m", "c")
        self.assert_blocked(self.git(*commit, cwd=self.repo.parent))

    def test_amend_checks_only_new_content(self) -> None:
        self.stage("app.py", "x = 1\n")
        self.commit(agent=None)
        self.assert_committed(self.git("commit", "-q", "--amend", "-m", "reworded"))

    def test_merge_resolution_is_skipped_and_logged(self) -> None:
        self.stage("m.py", "base = 0\n")
        self.commit(agent=None)
        self.git("checkout", "-q", "-b", "side", agent=None)
        self.stage("m.py", "side = 1\n")
        self.commit(agent=None)
        self.git("checkout", "-q", "main", agent=None)
        self.stage("m.py", "main = 2\n")
        self.commit(agent=None)
        self.git("merge", "-q", "side", agent=None)
        self.stage("m.py", "resolved = 3\n")
        self.assert_committed(self.git("commit", "-q", "--no-edit"))
        self.assertIn("gate-skip", self.log_events())

    def test_moves_without_line_changes_pass(self) -> None:
        self.stage("big.py", "".join(f"v{i} = {i}\n" for i in range(50)))
        self.commit(agent=None)
        self.git("mv", "big.py", "util.py")
        self.assert_committed(self.commit())

    def test_first_commit_in_an_empty_repository(self) -> None:
        empty = self.repo.parent / "empty"
        self.init_repo(empty)
        (empty / "main.go").write_text("package main\n")
        self.git("add", "main.go", cwd=empty)
        self.assert_blocked(self.git("commit", "-q", "-m", "first", cwd=empty))
        stamped = self.refine("stamp", "--mode", "light", cwd=empty)
        self.assertEqual(stamped.returncode, 0, stamped.stderr)
        self.assert_committed(self.git("commit", "-q", "-m", "first", cwd=empty))

    def test_gate_is_fast(self) -> None:
        self.stage("app.py", "x = 1\n")
        self.refine("stamp", "--mode", "light")
        started = time.monotonic()
        self.assert_committed(self.commit())
        self.assertLess(time.monotonic() - started, 2.0)


if __name__ == "__main__":
    unittest.main()
