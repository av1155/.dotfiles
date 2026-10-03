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
# Stray lines of a value that dotenv reads as names, each caught by one guard
MIXED = "FakeMixedTail"
HEXTAIL = "deadbeefcafe0123fake"
PADDED = "abcd0123"
# Short enough to pass as a word, so only the rule for its place hides it
SHORT = "pw4short"
KEYLIKE = "AKIAFAKE0123456789XY"
COMMENTED = f"""# Supabase secret key
# which is used only for
# backend side
SUPABASE_SECRET_KEY={SECRET}

# SUPABASE_SECRET_KEY={SHORT}
# db: postgres://admin:{SHORT}@db.example.com/app
# token: {SHORT}
# pasted {KEYLIKE} here
# see OAUTH2_CLIENT_SECRET at https://example.com/project/{KEYLIKE}/settings
QUOTED="first
# {SHORT} inside a value
last"
INLINE=1 # {SHORT}
"""
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
NBSP_QUOTE=\u00a0"first
INNER_H={SECRET}
last"
\u00a0LEADING="first
INNER_I={SECRET}
last"
export\u3000WIDE="first
INNER_J={SECRET}
last"
\ufeffMIDBOM="first
INNER_K={SECRET}
last"
AFTER_LS="first
INNER_L={SECRET}
last"\u2028
COLON_NBSP:\u00a0"first
INNER_M={SECRET}
last"
FORMFEED={SECRET}\x0cINNER_N={SECRET}
# a note\u2028AFTER_NOTE=1
LS_THEN="first
INNER_O={SECRET}
last"\u2028LS_KEY=1
TRUNCATED=-----BEGIN KEY-----
REAL_AFTER=1
BLOB=MIIEvQIBADANBgkq
{MIXED}=1
{HEXTAIL}=1
{PADDED}==
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
            for secret in (SECRET, TAIL, MIXED, HEXTAIL, PADDED, SHORT, KEYLIKE):
                self.assertNotIn(secret, output)

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
        return {row[0]: row[1] for row in rows if row[1:] in (["set"], ["empty"])}

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
        names = """GREETING KEY_BLOCK WIN_DIR SINGLE_BLOCK COLON_BLOCK SPLIT TICK_BLOCK
            ESCAPED PEM_RAW NBSP_QUOTE LEADING WIDE MIDBOM AFTER_LS COLON_NBSP FORMFEED
            AFTER_NOTE LS_THEN LS_KEY TRUNCATED REAL_AFTER BLOB"""
        self.assertEqual(
            self.listed(result.stdout), dict.fromkeys(names.split(), "set")
        )
        self.assertNotIn("INNER_", result.stdout)
        lines = str(TRICKY).split("\n")
        stray = [f"{MIXED}=1", f"{HEXTAIL}=1", f"{PADDED}=="]
        notes = [line for line in result.stdout.splitlines() if line.startswith("line")]
        withheld = "is withheld: its name looks like a value"
        expected = [f"line {lines.index(x) + 1} of {tricky} {withheld}" for x in stray]
        self.assertEqual(notes, expected)

    def test_keys_trims_values_as_javascript_does(self) -> None:
        spaced = self.dir / ".env.spaced"
        spaced.write_text("BOM_ONLY=\ufeff\nSEPARATOR=\x1c\n", encoding="utf-8")
        listed = self.listed(self.envfile("keys", str(spaced)).stdout)
        self.assertEqual(listed, {"BOM_ONLY": "empty", "SEPARATOR": "set"})

    def test_keys_shows_comments_with_their_values_hidden(self) -> None:
        commented = self.dir / ".env.commented"
        commented.write_text(COMMENTED)
        result = self.envfile("keys", str(commented))
        expected = """# Supabase secret key
# which is used only for
# backend side
SUPABASE_SECRET_KEY  set

# SUPABASE_SECRET_KEY=<hidden>
# db: postgres://admin:<hidden>@db.example.com/app
# token: <hidden>
# pasted <hidden> here
# see OAUTH2_CLIENT_SECRET at https://example.com/project/<hidden>/settings
QUOTED               set
INLINE               set
"""
        self.assertEqual(result.stdout, expected)

    def test_keys_names_what_only_one_file_has(self) -> None:
        local = self.dir / ".env.paired"
        local.write_text(LOCAL + "bothFiles=1\nonlyLocal=1\n")
        example = self.dir / ".env.example"
        example.write_text(
            "\ufeffDATABASE_URL=\r\nRESEND_API_KEY=\r\nDECLARED_ONLY\r\nbothFiles=\r\n",
            encoding="utf-8",
        )
        result = self.envfile("keys", str(local), "--against", str(example))
        self.assertIn(f"only in {example}: RESEND_API_KEY", result.stdout)
        self.assertIn(f"only in {local}: EMPTY, QUOTED_EMPTY, SINGLE", result.stdout)
        self.assertNotIn("DATABASE_URL", result.stdout.split("only in")[1])
        self.assertIn(f"line 3 of {example} is not NAME=value", result.stdout)
        only_local = local.read_text().split("\n").index("onlyLocal=1") + 1
        absent = [line for line in result.stdout.splitlines() if "and not in" in line]
        self.assertEqual(
            absent, [f"line {only_local} of {local} is withheld and not in {example}"]
        )

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
        self.assertEqual([path.name for path in worktree.iterdir()], [".env.local"])
        same = self.envfile("copy", str(self.local), str(self.dir))
        self.assertIn("are the same file", same.stderr)
        linked = self.dir / ".env.linked"
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
        fresh = self.envfile(
            "copy", str(self.local), str(worktree / ".env.new"), limit=0
        )
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
        other = self.envfile("copy", str(key), str(self.dir / ".env.copied"))
        self.assertIn(f"{key} is not an env file", other.stderr)
        self.assertFalse((self.dir / ".env.copied").exists())
        notes = self.envfile("copy", str(self.local), str(self.dir / "notes.txt"))
        self.assertIn("is not an env file name", notes.stderr)
        missing_dir = self.dir / "missing"
        slash = self.envfile("copy", str(self.local), f"{missing_dir}/")
        self.assertIn("is not a directory", slash.stderr)
        self.assertFalse((self.dir / "notes.txt").exists() or missing_dir.exists())
        alias = self.dir / ".env.alias"
        alias.symlink_to(key)
        self.assertIn("is not an env file", self.envfile("keys", str(alias)).stderr)
        renamed = self.dir / "renamed.txt"
        renamed.symlink_to(self.local)
        self.assertIn("is not an env file", self.envfile("keys", str(renamed)).stderr)
        self.assertEqual(self.envfile("keys").returncode, 2)
        blocked = self.dir / "blocked"
        blocked.mkdir()
        blocked.chmod(0o500)
        self.addCleanup(blocked.chmod, 0o700)
        denied = self.envfile("copy", str(self.local), str(blocked / ".env.x"))
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
