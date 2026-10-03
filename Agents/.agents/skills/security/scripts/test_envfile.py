"""Black-box tests for envfile, which must never print a value.

Run: python3 -m unittest discover -s <this directory> -p 'test_*.py'
"""

import contextlib
import importlib.machinery
import io
import stat
import subprocess
import tempfile
import types
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent / "envfile"
SECRET = "s3cr3t-VALUE-9f2b"
LOCAL = f"""# local settings
export DATABASE_URL=postgres://user:{SECRET}@host/db
EMPTY=
QUOTED_EMPTY=""
SINGLE='{SECRET}'
INLINE={SECRET} # a comment
COMMENTED= # nothing here
HASHED="a#{SECRET}"
MULTI="-----BEGIN KEY-----
LEAKED_NAME={SECRET}
-----END KEY-----"
not an assignment {SECRET}
AFTER={SECRET}
"""


class EnvfileTests(unittest.TestCase):
    def setUp(self) -> None:
        self.dir = Path(self.enterContext(tempfile.TemporaryDirectory()))
        self.local = self.dir / ".env.local"
        self.local.write_text(LOCAL)
        self.outputs: list[str] = []

    def tearDown(self) -> None:
        for output in self.outputs:
            self.assertNotIn(SECRET, output)

    def envfile(self, *args: str) -> subprocess.CompletedProcess[str]:
        result = subprocess.run(
            [str(SCRIPT), *args], capture_output=True, text=True, check=False
        )
        self.outputs += [result.stdout, result.stderr]
        return result

    def test_keys_lists_names_as_set_or_empty(self) -> None:
        result = self.envfile("keys", str(self.local))
        self.assertEqual(result.returncode, 0, result.stderr)
        rows = [line.split() for line in result.stdout.splitlines()]
        listed = {row[0]: row[1] for row in rows if len(row) == 2}
        self.assertEqual(
            listed,
            {
                "DATABASE_URL": "set",
                "EMPTY": "empty",
                "QUOTED_EMPTY": "empty",
                "SINGLE": "set",
                "INLINE": "set",
                "COMMENTED": "empty",
                "HASHED": "set",
                "MULTI": "set",
                "AFTER": "set",
            },
        )
        self.assertIn("line 12 of .env.local is not NAME=value", result.stdout)

    def test_keys_names_what_only_one_file_has(self) -> None:
        example = self.dir / ".env.example"
        example.write_text("DATABASE_URL=\nRESEND_API_KEY=\n")
        result = self.envfile("keys", str(self.local), "--against", str(example))
        self.assertIn("only in .env.example: RESEND_API_KEY", result.stdout)
        self.assertIn("only in .env.local: EMPTY, QUOTED_EMPTY, SINGLE", result.stdout)
        self.assertNotIn("DATABASE_URL", result.stdout.split("only in")[1])

    def test_copy_writes_a_private_copy_and_keeps_existing_files(self) -> None:
        worktree = self.dir / "worktree"
        worktree.mkdir()
        result = self.envfile("copy", str(self.local), str(worktree))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("(9 variables)", result.stdout)
        target = worktree / ".env.local"
        self.assertEqual(target.read_bytes(), self.local.read_bytes())
        self.assertEqual(stat.S_IMODE(target.stat().st_mode), 0o600)
        target.write_text("KEEP=1\n" * 500)
        again = self.envfile("copy", str(self.local), str(target))
        self.assertEqual(again.returncode, 1)
        self.assertIn("pass --force", again.stderr)
        self.assertEqual(target.read_text(), "KEEP=1\n" * 500)
        target.chmod(0o644)
        forced = self.envfile("copy", str(self.local), str(target), "--force")
        self.assertEqual(forced.returncode, 0, forced.stderr)
        self.assertEqual(target.read_bytes(), self.local.read_bytes())
        self.assertEqual(stat.S_IMODE(target.stat().st_mode), 0o600)
        same = self.envfile("copy", str(self.local), str(self.dir))
        self.assertIn("are the same file", same.stderr)

    def test_failures_name_the_path_only(self) -> None:
        missing = self.envfile("keys", str(self.dir / "absent"))
        self.assertEqual(missing.returncode, 1)
        self.assertIn("cannot read", missing.stderr)
        self.assertEqual(self.envfile("keys").returncode, 2)
        blocked = self.dir / "blocked"
        blocked.mkdir()
        blocked.chmod(0o500)
        self.addCleanup(blocked.chmod, 0o700)
        denied = self.envfile("copy", str(self.local), str(blocked / "x"))
        self.assertEqual(denied.returncode, 1)
        self.assertIn("cannot write", denied.stderr)

    def test_an_unexpected_error_shows_only_its_type(self) -> None:
        loader = importlib.machinery.SourceFileLoader("envfile", str(SCRIPT))
        module = types.ModuleType(loader.name)
        loader.exec_module(module)

        def explode(_data: bytes) -> tuple[dict[str, bool], list[int]]:
            raise ValueError(SECRET)

        module.__dict__["_names"] = explode
        stderr = io.StringIO()
        with contextlib.redirect_stderr(stderr):
            code = module.main(["keys", str(self.local)])
        self.outputs.append(stderr.getvalue())
        self.assertEqual(code, 1)
        self.assertEqual(stderr.getvalue(), "envfile: unexpected ValueError\n")


if __name__ == "__main__":
    unittest.main()
