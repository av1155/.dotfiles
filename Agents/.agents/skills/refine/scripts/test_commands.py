"""Black-box tests for the refine commands: scope, diff, snapshot, restore, stamp.

Run: python3 -m unittest discover -s <this directory> -p 'test_*.py'
"""

import json
import unittest
from pathlib import Path

from test_support import GateTestCase


class ScopeTests(GateTestCase):
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
        self.assertEqual(
            self.kinds(report),
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

    def test_exemptions_need_an_exact_match(self) -> None:
        expected = {
            "apps/web/src/lib/validation/vendor/aml.ts": "code",
            "src/components/NoticeBanner.tsx": "code",
            "src/notice.py": "code",
            "CMakeLists.txt": "code",
            "vendor/lib/x.go": "exempt",
            "web/node_modules/pkg/index.js": "exempt",
            "LICENSE-MIT": "exempt",
            "COPYING.LESSER": "exempt",
        }
        for path in expected:
            self.stage(path, "x\n")
        self.assertEqual(self.kinds(self.scope()), expected)

    def test_existing_migrations_are_report_only(self) -> None:
        self.stage("db/migrations/001.sql", "create table t ();\n")
        self.commit(agent=None)
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

    def test_moves_count_only_their_changed_lines(self) -> None:
        body = "".join(f"v{i} = {i}\n" for i in range(50))
        self.stage("big.py", body)
        self.commit(agent=None)
        self.git("mv", "big.py", "util.py")
        self.assertEqual(self.scope()["mode"], "none")
        self.stage("util.py", body.replace("v0 = 0", "v0 = 100"))
        report = self.scope()
        self.assertEqual((report["mode"], report["code_lines"]), ("light", 2))
        result = self.refine("diff")
        self.assertEqual(result.returncode, 0, result.stderr)
        patch = Path(json.loads(result.stdout)["shards"][0]["file"]).read_text()
        self.assertIn("rename from big.py", patch)
        self.assertNotIn("v49 = 49", patch)

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
        self.commit(agent=None)
        self.stage("src/app.py", "x = 1\n")
        self.stage("src/gen.py", "y = 1\n")
        subdir = self.repo / "src"
        result = self.refine("diff", cwd=subdir)
        self.assertEqual(result.returncode, 0, result.stderr)
        shards = json.loads(result.stdout)["shards"]
        self.assertEqual([list(s["paths"]) for s in shards], [["src/app.py"]])
        self.assertIn("+x = 1", Path(shards[0]["file"]).read_text())
        expected = {"src/app.py": "code", "src/gen.py": "exempt"}
        self.assertEqual(self.kinds(self.scope(subdir)), expected)


class SnapshotAndStampTests(GateTestCase):
    def test_stamp_and_snapshot_refuse_unstaged_edits(self) -> None:
        self.stage("app.py", "x = 1\n")
        self.write("app.py", "x = 2\n")
        self.assertEqual(self.refine("stamp", "--mode", "light").returncode, 2)
        self.assertEqual(self.refine("snapshot").returncode, 2)

    def test_stamp_mode_none_refuses_reviewable_files(self) -> None:
        self.stage("app.py", "x = 1\n")
        self.assertEqual(self.refine("stamp", "--mode", "none").returncode, 2)
        self.assert_blocked(self.commit())

    def test_snapshot_and_restore_round_trip(self) -> None:
        self.stage("pkg/app.py", "x = 1\n")
        self.assertEqual(self.refine("snapshot").returncode, 0)
        self.write("pkg/app.py", "x = 99\n")
        self.assertEqual(self.refine("restore").returncode, 0)
        self.assertEqual((self.repo / "pkg/app.py").read_text(), "x = 1\n")
        self.assertNotEqual(self.refine("restore", "other.py").returncode, 0)

    def test_restore_refuses_a_snapshot_from_another_commit(self) -> None:
        self.stage("app.py", "x = 1\n")
        self.refine("snapshot")
        self.stage("app.py", "x = 2\n")
        self.commit(agent=None)
        self.write("app.py", "x = 3\n")
        result = self.refine("restore")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("HEAD is now", result.stderr)
        self.assertEqual((self.repo / "app.py").read_text(), "x = 3\n")

    def test_restore_refuses_after_restaging(self) -> None:
        self.stage("app.py", "x = 1\n")
        self.assertEqual(self.refine("snapshot").returncode, 0)
        self.stage("app.py", "x = 2\n")
        result = self.refine("restore")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("staged content changed", result.stderr)
        self.assertEqual((self.repo / "app.py").read_text(), "x = 2\n")

    def test_snapshot_of_named_committed_files_for_a_tidy_pass(self) -> None:
        self.stage("app.py", "x = 1\n")
        self.commit(agent=None)
        self.assertEqual(self.refine("snapshot", "app.py").returncode, 0)
        self.write("app.py", "x = 2\n")
        self.assertEqual(self.refine("restore").returncode, 0)
        self.assertEqual((self.repo / "app.py").read_text(), "x = 1\n")
        self.assertNotEqual(self.refine("snapshot", "missing.py").returncode, 0)

    def test_stamp_merges_entries_until_head_moves(self) -> None:
        self.stage("a.py", "a = 1\n")
        self.refine("stamp", "--mode", "light")
        self.git("reset", "-q", "a.py", agent=None)
        self.stage("b.py", "b = 1\n")
        self.refine("stamp", "--mode", "light")
        self.git("add", "a.py")
        self.assert_committed(self.commit())
        self.stage("c.py", "c = 1\n")
        self.refine("stamp", "--mode", "light")
        stamp = json.loads((self.repo / ".git" / "refine" / "stamp.json").read_text())
        self.assertEqual(sorted(stamp["entries"]), ["c.py"])


if __name__ == "__main__":
    unittest.main()
