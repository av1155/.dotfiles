"""Black-box tests for envfile, which must never print a value.

Run: python3 -m unittest discover -s <this directory> -p 'test_*.py'
"""

import contextlib
import importlib.machinery
import io
import resource
import stat
import subprocess
import tempfile
import types
import unittest
from pathlib import Path
from unittest import mock

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
# The last line of a key pasted without quotes, which dotenv reads as a name
TAIL = "FAKEfakeNOTAKEYfake0123fakeFAKEfake0123"
# Each INNER_ line sits inside a value that dotenv reads whole
TRICKY = f"""GREETING="hello
KEY_BLOCK="-----BEGIN KEY-----
INNER_A={SECRET}
-----END KEY-----"
WIN_DIR='C:\\fake\\dir\\'
SINGLE_BLOCK='first
INNER_B={SECRET}
last'
COLON_BLOCK: "first
INNER_C={SECRET}
last"
SPLIT={SECRET}\u2028INNER_D={SECRET}\x0bINNER_E={SECRET}
TICK_BLOCK=`first
INNER_F={SECRET}
last`
ESCAPED="say \\"hi
INNER_G={SECRET}
bye\\""
PEM_RAW=-----BEGIN KEY-----
{TAIL}==
-----END KEY-----
"""


def _module() -> types.ModuleType:
    loader = importlib.machinery.SourceFileLoader("envfile", str(SCRIPT))
    module = types.ModuleType(loader.name)
    loader.exec_module(module)
    return module


class EnvfileTests(unittest.TestCase):
    def setUp(self) -> None:
        self.dir = Path(self.enterContext(tempfile.TemporaryDirectory()))
        self.local = self.dir / ".env.local"
        self.local.write_text(LOCAL)
        self.outputs: list[str] = []

    def tearDown(self) -> None:
        for output in self.outputs:
            self.assertNotIn(SECRET, output)
            self.assertNotIn(TAIL, output)

    def envfile(
        self, *args: str, limit: int | None = None
    ) -> subprocess.CompletedProcess[str]:
        def cap_file_size() -> None:
            if limit is not None:
                resource.setrlimit(resource.RLIMIT_FSIZE, (limit, limit))

        result = subprocess.run(
            [str(SCRIPT), *args],
            capture_output=True,
            text=True,
            check=False,
            preexec_fn=cap_file_size,
        )
        self.outputs += [result.stdout, result.stderr]
        return result

    def main(self, module: types.ModuleType, *args: str) -> tuple[int, str]:
        stderr = io.StringIO()
        with (
            contextlib.redirect_stderr(stderr),
            contextlib.redirect_stdout(io.StringIO()),
        ):
            code = int(module.main(list(args)))
        self.outputs.append(stderr.getvalue())
        return code, stderr.getvalue()

    def listed(self, stdout: str) -> dict[str, str]:
        rows = [line.split() for line in stdout.splitlines()]
        return {row[0]: row[1] for row in rows if len(row) == 2}

    def test_keys_lists_names_as_set_or_empty(self) -> None:
        result = self.envfile("keys", str(self.local))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            self.listed(result.stdout),
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
        self.assertIn(f"line 12 of {self.local} is not NAME=value", result.stdout)

    def test_keys_never_lists_a_line_from_inside_a_value(self) -> None:
        tricky = self.dir / "tricky.env"
        tricky.write_text(TRICKY, encoding="utf-8")
        result = self.envfile("keys", str(tricky))
        self.assertEqual(result.returncode, 0, result.stderr)
        names = "GREETING KEY_BLOCK WIN_DIR SINGLE_BLOCK COLON_BLOCK SPLIT TICK_BLOCK"
        expected = dict.fromkeys([*names.split(), "ESCAPED", "PEM_RAW"], "set")
        self.assertEqual(self.listed(result.stdout), expected)
        self.assertNotIn("INNER_", result.stdout)
        self.assertIn(f"line 20 of {tricky} is withheld", result.stdout)
        self.assertIn(f"line 21 of {tricky} is not NAME=value", result.stdout)

    def test_keys_names_what_only_one_file_has(self) -> None:
        example = self.dir / ".env.example"
        example.write_text(
            "\ufeffDATABASE_URL=\r\nRESEND_API_KEY=\r\nDECLARED_ONLY\r\n",
            encoding="utf-8",
        )
        result = self.envfile("keys", str(self.local), "--against", str(example))
        self.assertIn(f"only in {example}: RESEND_API_KEY", result.stdout)
        local_only = f"only in {self.local}: EMPTY, QUOTED_EMPTY, SINGLE"
        self.assertIn(local_only, result.stdout)
        self.assertNotIn("DATABASE_URL", result.stdout.split("only in")[1])
        self.assertIn(f"line 3 of {example} is not NAME=value", result.stdout)

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
        linked = self.dir / "linked"
        linked.hardlink_to(self.local)
        hard = self.envfile("copy", str(self.local), str(linked), "--force")
        self.assertIn("are the same file", hard.stderr)

    def test_copy_never_follows_a_link_or_leaves_a_partial_file(self) -> None:
        worktree = self.dir / "worktree"
        worktree.mkdir()
        target = worktree / ".env.local"
        target.symlink_to(self.dir / "elsewhere")
        refused = self.envfile("copy", str(self.local), str(worktree))
        self.assertIn("pass --force", refused.stderr)
        forced = self.envfile("copy", str(self.local), str(worktree), "--force")
        self.assertEqual(forced.returncode, 0, forced.stderr)
        self.assertFalse(target.is_symlink())
        self.assertFalse((self.dir / "elsewhere").exists())
        target.write_text("KEEP=1\n")
        args = ("copy", str(self.local), str(target), "--force")
        self.assertIn("cannot write", self.envfile(*args, limit=0).stderr)
        self.assertEqual(target.read_text(), "KEEP=1\n")
        fresh = self.envfile("copy", str(self.local), str(worktree / "new"), limit=0)
        self.assertEqual(fresh.returncode, 1)
        self.assertEqual([path.name for path in worktree.iterdir()], [".env.local"])

    def test_copy_never_replaces_a_file_that_appears_meanwhile(self) -> None:
        late = self.dir / "late.env"
        late.write_text("KEEP=1\n")
        with mock.patch("os.path.lexists", return_value=False):
            code, stderr = self.main(_module(), "copy", str(self.local), str(late))
        self.assertEqual((code, late.read_text()), (1, "KEEP=1\n"))
        self.assertIn("cannot write", stderr)

    def test_failures_name_the_path_only(self) -> None:
        missing = self.envfile("keys", str(self.dir / ".env.absent"))
        self.assertEqual(missing.returncode, 1)
        self.assertIn("cannot read", missing.stderr)
        key = self.dir / "id_rsa"
        key.write_text(f"KEY={SECRET}\n")
        other = self.envfile("copy", str(key), str(self.dir / "copied"))
        self.assertIn("is not an env file", other.stderr)
        self.assertFalse((self.dir / "copied").exists())
        alias = self.dir / ".env.alias"
        alias.symlink_to(key)
        self.assertIn("is not an env file", self.envfile("keys", str(alias)).stderr)
        self.assertEqual(self.envfile("keys").returncode, 2)
        blocked = self.dir / "blocked"
        blocked.mkdir()
        blocked.chmod(0o500)
        self.addCleanup(blocked.chmod, 0o700)
        denied = self.envfile("copy", str(self.local), str(blocked / "x"))
        self.assertEqual(denied.returncode, 1)
        self.assertIn("cannot write", denied.stderr)

    def test_a_reader_that_stops_early_ends_it_quietly(self) -> None:
        many = self.dir / "many.env"
        many.write_text("".join(f"NAME_{number}=1\n" for number in range(50_000)))
        with subprocess.Popen(
            [str(SCRIPT), "keys", str(many)],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        ) as process:
            if process.stdout is None or process.stderr is None:
                self.fail("envfile started without pipes")
            process.stdout.readline()
            process.stdout.close()
            errors = process.stderr.read()
        self.outputs.append(errors)
        self.assertEqual(errors, "")

    def test_an_unexpected_error_shows_only_its_type(self) -> None:
        module = _module()

        def explode(_data: bytes) -> tuple[dict[str, bool], list[int], list[int]]:
            raise ValueError(SECRET)

        module.__dict__["_parse"] = explode
        code, stderr = self.main(module, "keys", str(self.local))
        self.assertEqual((code, stderr), (1, "envfile: unexpected ValueError\n"))


if __name__ == "__main__":
    unittest.main()
