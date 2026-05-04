---
name: python
description: Python conventions for this user. Loads only when reading or editing .py / .pyi files. Reflects Python 3.14 (PEP 749 lazy annotations, PEP 750 t-strings, PEP 779 free-threading), 3.13 floor, modern tooling (uv, ruff, pyright/mypy, pytest 9 + pytest-asyncio 1.3), Pydantic v2, FastAPI Annotated dependency style.
paths:
  - "**/*.py"
  - "**/*.pyi"
---

# Python conventions

Apply when working with Python files. For backend scalability concerns (queries, caching, queues, observability) defer to the `scalability` skill. For comment authority defer to the `commenting` skill. For auth/secrets/input validation/LLM safety defer to the `security` skill.

## Versioning baseline

- Floor: `requires-python = ">=3.13"` for new code; `>=3.14` for greenfield. Don't back-port modern syntax to legacy projects without checking the project's `pyproject.toml`.
- Python 3.14 shipped 2025-10-07; 3.13 has support through 2029-10. Older 3.x is legacy.
- Run on the project's pinned interpreter via `uv run` (or `uv sync && .venv/bin/python`). Never assume the system Python.

## Strictness (type system, 2026)

- **Pyright in strict mode in the editor** (live feedback). **Mypy `--strict` in CI** as the unforgiving arbiter. They disagree on edge cases; pyright catches more in practice but mypy strict is the gate.
- Full type annotations on every public function: parameters and return type. Mypy skips unannotated functions; pyright checks them — annotate everything anyway.
- `unknown`-equivalent (`object` narrowed with `isinstance`, or a parser like Pydantic / `TypeAdapter`) over `Any`. Reserve `Any` for genuine boundary escape hatches with a one-line comment explaining why.
- Mypy strict equivalents to set in `[tool.mypy]`: `strict = true`, `warn_return_any = true`, `warn_unused_ignores = true`, `disallow_untyped_defs = true`. Pyright strict is automatic when `typeCheckingMode = "strict"`.

## Type system (Python 3.14)

- **PEP 604 unions everywhere**: `int | None`, `A | B`. Not `Optional[int]`, not `Union[A, B]`.
- **Lowercase built-in generics**: `list[int]`, `dict[str, int]`, `tuple[int, ...]`. `typing.List` / `typing.Dict` / `typing.Tuple` / `typing.Type` are legacy.
- **PEP 695 generic syntax** for new code:
  - `def first[T](items: list[T]) -> T: ...`
  - `class Box[T]: ...`
  - `type IntMap[V] = dict[int, V]`
  Reserve old-style `TypeVar` / `Generic[T]` for libraries still supporting 3.11.
- **PEP 749 deferred annotations.** On 3.14+ annotations are lazy by default. `from __future__ import annotations` is a no-op and signals out-of-date code. Drop it from new files.
- Annotation introspection: use `annotationlib.get_annotations(obj, format=Format.VALUE)` (3.14+) or `inspect.get_annotations(...)` (older). Reading `__annotations__` directly returns un-evaluated stubs and is brittle.
- **Modern typing primitives**: `Self` (return-self methods), `Never` (unreachable), `LiteralString` (safer SQL/shell sinks), `TypeIs` (PEP 742, narrowing predicates), `NotRequired` / `Required` for `TypedDict` keys.
- **Frozen dataclasses with `slots=True`** for value objects. Unfrozen only when mutation is the design.

## Modules and files

- One concept per file. Split before a file grows past 400 lines.
- Public API at the top, private helpers below; underscore-prefix private functions and module-level state.
- Avoid mutable module-level state. Use a class, a closure, or pass state explicitly. The one common exception is a singleton settings object built lazily in `get_settings()`.
- `__all__` for two reasons only: controlling `from foo import *`, and silencing pyright's hint-level "is not accessed" greying on `_`-prefixed module-level names that sibling modules or tests consume. List those exports in `__all__` so the editor stops flagging them.
- Source under `src/<package>/` (src layout). Tests under `tests/`, mirroring the source tree.

## Errors and validation

- Validate at boundaries (HTTP handlers, queue consumers, file readers, CLI args) with **Pydantic v2** or `dataclasses` plus an explicit validator.
- Internal functions trust their inputs.
- Define a **base exception per package** (e.g., `class HoundarrError(Exception):`) and have callers `except` the base. Never `except Exception:` or bare `except:` for control flow.
- 3.14: bracketless multi-class except (`except TimeoutError, ConnectionError:`) is parsed but `except (TimeoutError, ConnectionError):` is preferred for readability.
- Avoid `return` / `break` / `continue` inside `finally` blocks; 3.14 raises `SyntaxWarning` for this pattern.
- For background tasks: catch `asyncio.CancelledError` first and re-raise, then a broad `except Exception` with `# noqa: BLE001` plus logging.

## String composition (PEP 750 t-strings)

- **F-strings (`f"..."`)** for ordinary runtime composition. Fastest and clearest.
- **T-strings (`t"..."`, Python 3.14)** return a `string.templatelib.Template` capturing static and interpolated parts separately. Use them whenever the sink has injection risk: SQL, shell, HTML, LDAP, JSON-as-string.
  ```python
  from string.templatelib import Template
  query: Template = t"SELECT * FROM users WHERE id = {user_id}"
  # pass `query` to a parameterized executor; the user_id stays separated
  ```
  Never f-string user input into SQL, shell, or HTML. Use t-strings + a sanitizer / parameterizer, or use a real templating engine (Jinja2 with autoescape) for HTML.

## Async / structured concurrency

- Use `asyncio` (not `trio` / `curio`) unless the project says otherwise.
- `async def` everywhere on the IO path. Calling sync IO from an async function blocks the event loop; wrap with `asyncio.to_thread(...)`.
- Prefer `asyncio.TaskGroup()` (3.11+) over loose `asyncio.gather(...)` for fan-out: it cancels siblings on first failure and propagates exceptions cleanly.
- **Set timeouts on every external call.** `async with asyncio.timeout(5.0):` for the local scope; `httpx.Timeout(...)` on the client. No timeouts means a hung peer hangs your worker.
- 3.14 introspection: `python -m asyncio ps <PID>` and `python -m asyncio pstree <PID>` to find stuck tasks in production.
- Never `time.sleep(...)` inside `async def`. Use `await asyncio.sleep(...)`.

## Free-threaded Python (PEP 779, 3.14)

- Free-threaded (no-GIL) builds are officially supported in 3.14 (`python3.14t`). Phase II of the rollout: stable but opt-in.
- Library compatibility is uneven. Run pure-Python tests under both GIL and free-threaded interpreters in CI before promising free-threading support to consumers.
- `threading.Lock` / `threading.RLock` work, but data-structure invariants under true parallelism need explicit locking that the GIL used to mask. Audit shared mutable state.
- Don't migrate to free-threaded as a default for asyncio-heavy code — async + free-threaded interact subtly. Default to asyncio under the GIL build until a workload genuinely benefits from threads.

## FastAPI conventions

- **Annotated dependency style**, not default-arg: `def route(user: Annotated[User, Depends(current_user)]) -> ...:`. Type aliases for repeating shapes:
  ```python
  CurrentUser = Annotated[User, Depends(current_user)]
  DbConn     = Annotated[Connection, Depends(get_conn)]
  ```
- **`lifespan` async context manager** for startup/shutdown. The legacy `@app.on_event(...)` is removed in current FastAPI.
- Separate **Pydantic schemas** (request / response) from ORM models. Schemas live in `schemas/` (or alongside the route as `_schema.py`). One `BaseModel` per concept.
- `response_model=...` only when it differs from the function's return type, otherwise let the type annotation be the source of truth.
- Settings: `pydantic-settings` `BaseSettings` with env loading. `get_settings()` lazy singleton.

## Pydantic v2 patterns

- `model_config = ConfigDict(...)` (TypedDict). The V1 `class Config:` is deprecated.
- `model.model_validate(data)` / `Model.model_validate_json(raw)` / `model.model_dump()` / `model.model_dump_json()`. The V1 names (`parse_obj`, `dict()`, `json()`) are deprecated.
- Prefer **`model_validate_json`** over `json.loads` + `model_validate` — the JSON parse runs in Rust and is meaningfully faster.
- `TypeAdapter[list[User]]` for ad-hoc validation without a wrapping model. Replaces `parse_obj_as`.
- **Discriminated unions** with a `Field(discriminator="type")` literal: jumps directly to the right variant on parse, gives clean error paths. If you can't discriminate, keep the union narrow and put the most-likely variant first.
- `Field(default=..., description=..., examples=[...])` — descriptions feed FastAPI's OpenAPI.
- `RootModel[list[Item]]` when the model root isn't a dict.

## Packaging (uv, PEP 735)

- **Build backend: `hatchling`** for new projects. `[build-system] requires = ["hatchling"]`, `build-backend = "hatchling.build"`. `setuptools` only when a project needs its specific extension hooks. `setup.py` / `setup.cfg` are legacy. (`uv_build` is on the way as the eventual `uv init` default; not yet ready to mandate.)
- **PEP 735 `[dependency-groups]`** for developer-only deps (pytest, mypy, ruff, etc.). uv special-cases the `dev` group and installs it by default on `uv sync`. `[project.optional-dependencies]` is for *published* extras consumers install with `pip install pkg[extra]`.
- **No checked-in `requirements.txt` / `requirements-dev.txt`.** Generate on demand via `uv export --frozen --no-hashes --no-emit-project [--no-dev | --only-group dev]` when a tool that consumes pip-style files (e.g. `pip-audit`) needs them.
- **uv.lock is the source of truth and is checked into git.** Application projects always commit it; libraries commit only when they want to lock dev environments.
- **`uv tool install <pkg>`** for global CLI tools (aider, ruff if you want it standalone, etc.). Do not `pip install --user` or `npx`-equivalent for Python.
- For monorepos: `[tool.uv.workspace] members = ["packages/*"]`. `uv sync --package <name>` and `uv run --package <name>` operate on a member.

## Project initialization (the cross-tool baseline)

The single non-negotiable block for AI-tool parity is `[tool.pyright]` with the venv pinned. Without it, pyright in opencode / Claude / codex reports "import unresolved" on every project dep, because none of those tools auto-discover the venv the way nvim's `venv-selector.nvim` does.

```toml
# Add to every Python project's pyproject.toml. Path values assume src layout +
# .venv at the repo root; adjust if the project differs.
[tool.pyright]
include          = ["src", "tests"]
extraPaths       = ["."]
pythonVersion    = "3.13"          # match [project.requires-python]
venvPath         = "."
venv             = ".venv"
typeCheckingMode = "standard"      # pin explicitly: basedpyright (LazyVim, opencode) defaults to "all" and surfaces diagnostics mypy --strict does not enforce
```

Everything else below is an **example baseline**, not a fixed template. Adapt rule selection, strictness levels, and dep pins to the project's age, audience, and risk profile. Library projects, CLIs, FastAPI services, and data-science notebooks all want different cuts. Replace `<package_name>` with the importable package name; drop sections that don't apply.

```toml
[project]
name = "<package_name>"
requires-python = ">=3.13"          # bump to ">=3.14" for greenfield
dynamic = ["version"]               # or pin a version directly

[build-system]
requires = ["hatchling>=1.27"]
build-backend = "hatchling.build"

[tool.hatch.build.targets.wheel]
packages = ["src/<package_name>"]

# PEP 735 dev group; uv installs on `uv sync` by default
[dependency-groups]
dev = [
    "ruff>=0.15",
    "mypy>=1.20",
    "pytest>=9",
    "pytest-asyncio>=1.3",       # drop if no async code
    "pytest-cov>=7",
    "bandit[toml]>=1.9",         # drop for personal/throwaway projects
]

[tool.ruff]
src            = ["src"]
line-length    = 100
target-version = "py313"

[tool.ruff.lint]
select = ["E", "W", "F", "I", "B", "C4", "UP", "SIM", "ANN", "S", "N"]
ignore = ["ANN401"]                 # add project-specific ignores here

[tool.ruff.lint.per-file-ignores]
"tests/**/*.py" = ["S", "ANN"]

[tool.ruff.lint.isort]
known-first-party = ["<package_name>"]

[tool.mypy]
python_version       = "3.13"
mypy_path            = "src"
strict               = true
warn_return_any      = true
warn_unused_ignores  = true
disallow_untyped_defs = true

[tool.pytest.ini_options]
testpaths    = ["tests"]
asyncio_mode = "auto"
asyncio_default_fixture_loop_scope = "function"
addopts      = "-q --tb=short"

[tool.bandit]
exclude_dirs = ["tests", ".venv"]
skips        = ["B101"]             # assert_used: needed in tests
```

After writing `pyproject.toml`:

```bash
uv sync                             # creates .venv + uv.lock and installs dev group
git add pyproject.toml uv.lock      # commit lockfile for application projects (libraries: optional)
```

Editor parity then follows automatically: the user's shell auto-activates `.venv` (zsh `_venv_auto_activate` hook), so any agent launched in the project gets the venv-pinned `python`, `ruff`, etc. on PATH. Pyright reads `[tool.pyright]` and resolves third-party imports via `.venv`. For a real-world reference when adapting, see <https://raw.githubusercontent.com/av1155/houndarr/refs/heads/main/pyproject.toml> (FastAPI + aiosqlite + uv app, the full battery); minimal CLI or library projects can drop bandit, pytest-asyncio, and the `ANN` ruff rules.

## Testing (pytest 9 + pytest-asyncio 1.3)

- `pyproject.toml` config: `asyncio_mode = "auto"` (every `async def test_*` runs without the marker), `asyncio_default_fixture_loop_scope = "function"` for max isolation, `addopts = "-q --tb=short"`.
- Test files match source: `foo.py` → `tests/test_foo.py`. Flat `def test_*` is the default; `class TestFoo:` grouping is allowed for related cases.
- **Async tests under auto mode** don't need `@pytest.mark.asyncio`. Explicit marker is only for opting *out* of the loop scope or selecting a custom loop factory (`pytest.mark.asyncio(loop_factories=[uvloop_factory])`).
- **Fixtures**: `@pytest.fixture` for sync, `@pytest_asyncio.fixture` for async. Both are recognized in auto mode.
- HTTP mocking with `respx` for httpx; FastAPI app testing with `TestClient` (sync) or `httpx.AsyncClient(transport=ASGITransport(app=app))` (async).
- **Time-sensitive tests must use relative time** (`datetime.now(UTC) - timedelta(...)` or SQLite's `datetime('now', '-N hours')`). Never hardcode an ISO timestamp; the test will silently rot.
- Parametrize over inputs (`@pytest.mark.parametrize`), not over implementation details.

## Tooling (canonical, 2026)

- **Ruff** for linting and formatting. Replaces black, isort, flake8, pylint, autoflake. Configure in `pyproject.toml`. Recommended baseline rule set: `["E", "W", "F", "I", "B", "C4", "UP", "SIM", "ANN", "S", "N"]` with per-file-ignores `{ "tests/**/*.py" = ["S", "ANN"] }`.
- **uv** for package management and virtualenvs. Replaces pip, pip-tools, virtualenv, pyenv. Run `uv sync`, `uv run pytest`, `uv add ...`, `uv tool install ...`, `uv lock --upgrade`.
- **Pyright** in editor (strict mode), **mypy** in CI (strict). Both configured from `pyproject.toml`.
- **Pytest** with `pytest-asyncio` for async; `pytest-cov` for coverage; `pytest-xdist` for parallel runs.
- **Bandit** (`bandit -r src/ -c pyproject.toml`) for SAST in CI. **pip-audit** for dependency CVE scanning (consume the uv-exported requirements files).
- `ruff check --fix && ruff format` before declaring a Python task done. Pyright/mypy + pytest in CI.

## Anti-patterns to flag

- `Any` in source without a one-line comment explaining the boundary.
- Bare `except:` or `except Exception:` for control flow.
- `from __future__ import annotations` in 3.14+ projects (now a no-op; signals out-of-date code).
- `Optional[X]` or `Union[A, B]` syntax in new code; use `X | None` and `A | B`.
- `typing.List` / `typing.Dict` / `typing.Tuple` / `typing.Type`; use lowercase built-ins.
- Mutable default arguments (`def f(items: list = []):` is the classic bug).
- f-strings with untrusted SQL or shell input (use t-strings + a parameterizer).
- `time.sleep(...)` inside `async def`.
- `parse_obj` / `.dict()` / `.json()` (Pydantic v1 names) in new code.
- `@app.on_event("startup")` (deprecated; use `lifespan`).
- Hardcoded ISO timestamps in tests that depend on "now".
- `pip install -r requirements.txt` workflow when the project has `pyproject.toml` + `uv.lock`.
- Test files importing production code via `sys.path` hacks instead of a real package layout.
- `__init__.py` files with re-export logic that duplicates `__all__`.

## Self-audit before declaring done

- [ ] `ruff check` clean.
- [ ] `ruff format --check` clean.
- [ ] `pyright` (strict) and `mypy --strict` clean for changed files.
- [ ] All public functions have type hints and a docstring.
- [ ] All external calls have a timeout.
- [ ] No bare `except`, no `except Exception:` outside background-task loops.
- [ ] No mutable default args.
- [ ] Tests added/updated; `pytest` clean.
- [ ] If touching backend code: cross-check the `scalability` skill checklist.
- [ ] If touching auth / secrets / external calls / LLM prompts: cross-check the `security` skill.
