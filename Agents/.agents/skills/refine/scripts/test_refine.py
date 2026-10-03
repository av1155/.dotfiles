"""Black-box tests for the refine CLI and its pre-commit gate.

Run: python3 -m unittest discover -s <this directory> -p 'test_*.py'
"""

import json
import os
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path
from typing import cast

SCRIPT = Path(__file__).resolve().parent / "refine"
AGENT = "claude-code_test"
BLOCKED = "refine gate commit blocked"


class GateTestCase(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.repo = Path(self._tmp.name) / "repo"
        self.init_repo(self.repo)
        self.write("seed.txt", "seed\n")
        self.git("add", "seed.txt")
        self.git("commit", "-q", "-m", "seed", agent=None)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def init_repo(self, path: Path) -> None:
        path.mkdir()
        self.git("init", "-q", "-b", "main", cwd=path)
        for key, value in (
            ("user.email", "test@example.com"),
            ("user.name", "test"),
            ("hook.refine.event", "pre-commit"),
            ("hook.refine.command", f"{SCRIPT} gate"),
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

    def git(
        self,
        *args: str,
        agent: str | None = AGENT,
        cwd: Path | None = None,
        extra: dict[str, str] | None = None,
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["git", *args],
            cwd=cwd or self.repo,
            env=self.env(agent, **(extra or {})),
            capture_output=True,
            text=True,
            check=False,
        )

    def refine(
        self, *args: str, cwd: Path | None = None
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [str(SCRIPT), *args],
            cwd=cwd or self.repo,
            env=self.env(AGENT),
            capture_output=True,
            text=True,
            check=False,
        )

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

    def test_stamped_commit_passes(self) -> None:
        self.stage("app.py", "x = 1\n")
        self.assertEqual(self.refine("stamp", "--mode", "light").returncode, 0)
        self.assert_committed(self.commit())
        self.assertIn("gate-pass", self.log_events())

    def test_restaged_change_after_stamp_is_blocked(self) -> None:
        self.stage("app.py", "x = 1\n")
        self.refine("stamp", "--mode", "light")
        self.stage("app.py", "x = 2\n")
        self.assert_blocked(self.commit())

    def test_exempt_only_commits_pass(self) -> None:
        self.git("config", "refine.exempt", "data/*")
        self.write(".gitattributes", "gen.ts linguist-generated\n")
        self.git("add", ".gitattributes")
        self.git("commit", "-q", "-m", "attrs", agent=None)
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

    def test_amend_without_new_content_passes(self) -> None:
        self.assert_committed(self.git("commit", "-q", "--amend", "-m", "reworded"))

    def test_merge_resolution_is_not_gated(self) -> None:
        self.git("checkout", "-q", "-b", "side", agent=None)
        self.stage("seed.txt", "side\n")
        self.git("commit", "-q", "-m", "side", agent=None)
        self.git("checkout", "-q", "main", agent=None)
        self.stage("seed.txt", "main\n")
        self.git("commit", "-q", "-m", "main", agent=None)
        self.git("merge", "-q", "side", agent=None)
        self.stage("seed.txt", "resolved\n")
        self.assert_committed(self.git("commit", "-q", "--no-edit"))

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


class CommandTests(GateTestCase):
    def scope(self, cwd: Path | None = None) -> dict[str, object]:
        result = self.refine("scope", cwd=cwd)
        self.assertEqual(result.returncode, 0, result.stderr)
        payload: dict[str, object] = json.loads(result.stdout)
        return payload

    def files(self, report: dict[str, object]) -> list[dict[str, object]]:
        return cast("list[dict[str, object]]", report["files"])

    def test_scope_classifies_and_picks_a_depth(self) -> None:
        self.stage(
            "src/app.ts", "".join(f"export const v{i} = {i};\n" for i in range(45))
        )
        self.stage("src/app.test.ts", "it('x', () => {});\n")
        self.stage("config/app.yaml", "a: 1\n")
        self.stage("git/.gitconfig", "[core]\n")
        self.stage("docs/guide.md", "guide\n")
        self.stage("db/migrations/001.sql", "create table t ();\n")
        report = self.scope()
        kinds = {str(f["path"]): str(f["kind"]) for f in self.files(report)}
        self.assertEqual(
            kinds,
            {
                "src/app.ts": "code",
                "src/app.test.ts": "test",
                "config/app.yaml": "config",
                "git/.gitconfig": "config",
                "docs/guide.md": "exempt",
                "db/migrations/001.sql": "code",
            },
        )
        self.assertEqual(report["mode"], "full")
        self.assertFalse(report["deep_altitude"])
        self.assertFalse(report["stamp_fresh"])

    def test_existing_migrations_are_report_only(self) -> None:
        self.stage("db/migrations/001.sql", "create table t ();\n")
        self.git("commit", "-q", "-m", "m", agent=None)
        self.stage("db/migrations/001.sql", "create table t (id int);\n")
        files = self.files(self.scope())
        self.assertEqual(files, [{"path": "db/migrations/001.sql", "status": "M", "kind": "migration-existing",
                                  "reason": "existing migration", "added": 1, "deleted": 1}])  # fmt: skip

    def test_small_change_is_light_and_partial_staging_is_reported(self) -> None:
        self.stage("app.py", "x = 1\n")
        self.write("app.py", "x = 2\n")
        report = self.scope()
        self.assertEqual(report["mode"], "light")
        self.assertEqual(report["partially_staged"], ["app.py"])

    def test_stamp_and_snapshot_refuse_unstaged_edits(self) -> None:
        self.stage("app.py", "x = 1\n")
        self.write("app.py", "x = 2\n")
        self.assertEqual(self.refine("stamp", "--mode", "light").returncode, 2)
        self.assertEqual(self.refine("snapshot").returncode, 2)

    def test_snapshot_and_restore_round_trip(self) -> None:
        self.stage("pkg/app.py", "x = 1\n")
        self.assertEqual(self.refine("snapshot").returncode, 0)
        self.write("pkg/app.py", "x = 99\n")
        self.assertEqual(self.refine("restore").returncode, 0)
        self.assertEqual((self.repo / "pkg/app.py").read_text(), "x = 1\n")
        self.assertNotEqual(self.refine("restore", "other.py").returncode, 0)

    def test_diff_shards_by_changed_lines(self) -> None:
        for name in ("a.py", "b.py", "c.py"):
            self.stage(name, "".join(f"v{i} = {i}\n" for i in range(10)))
        self.stage("README.md", "readme\n")
        result = self.refine("diff", "--shard-lines", "15")
        self.assertEqual(result.returncode, 0, result.stderr)
        shards = json.loads(result.stdout)["shards"]
        self.assertEqual(
            [list(s["paths"]) for s in shards], [["a.py"], ["b.py"], ["c.py"]]
        )
        self.assertIn("+v9 = 9", Path(shards[0]["file"]).read_text())

    def test_diff_and_scope_resolve_paths_from_a_subdirectory(self) -> None:
        self.stage(".gitattributes", "/src/gen.py linguist-generated\n")
        self.git("commit", "-q", "-m", "attrs", agent=None)
        self.stage("src/app.py", "x = 1\n")
        self.stage("src/gen.py", "y = 1\n")
        subdir = self.repo / "src"
        result = self.refine("diff", cwd=subdir)
        self.assertEqual(result.returncode, 0, result.stderr)
        shards = json.loads(result.stdout)["shards"]
        self.assertEqual([list(s["paths"]) for s in shards], [["src/app.py"]])
        self.assertIn("+x = 1", Path(shards[0]["file"]).read_text())
        kinds = {str(f["path"]): str(f["kind"]) for f in self.files(self.scope(subdir))}
        self.assertEqual(kinds, {"src/app.py": "code", "src/gen.py": "exempt"})

    def test_stamp_merges_entries_until_head_moves(self) -> None:
        self.stage("a.py", "a = 1\n")
        self.refine("stamp", "--mode", "light")
        self.git("reset", "-q", "a.py", agent=None)
        self.stage("b.py", "b = 1\n")
        self.refine("stamp", "--mode", "light")
        self.git("add", "a.py")
        self.assert_committed(self.commit())


if __name__ == "__main__":
    unittest.main()
