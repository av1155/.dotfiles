---
name: python
description: Python code conventions for this user. Loads only when reading or editing .py files. Reflects Python 3.13/3.14 standards (PEP 695 generics, PEP 749 deferred annotations, PEP 750 t-strings) and modern tooling (Ruff, uv, pytest).
paths:
  - "**/*.py"
  - "**/*.pyi"
---

# Python conventions

Apply when working with Python files. For backend scalability concerns (queries, caching, queues, observability) defer to the `scalability` skill. For comment authority defer to the `commenting` skill. For auth/secrets/input validation/LLM safety defer to the `security` skill.

## Versioning baseline

- Target Python 3.13+; greenfield code targets 3.14.
- Older 3.x compatibility only when the project says so. Do not back-port modern syntax to legacy projects without checking the project's `pyproject.toml` `requires-python`.

## Type hints

- Type hints on every public function and method, on module-level constants where the type is non-obvious, and on dataclass / TypedDict fields.
- Use lowercase built-in generics: `list[int]`, `dict[str, int]`, `tuple[int, ...]`. The `typing.List` / `typing.Dict` aliases are legacy.
- Use `|` for unions and optionals: `int | None`, not `Optional[int]`, not `Union[int, str]`.
- **PEP 695 generic syntax** for new code:
  - `def first[T](items: list[T]) -> T: ...`
  - `class Box[T]: ...`
  - `type IntMap[V] = dict[int, V]`
  Reserve old-style `TypeVar` / `Generic` only for libraries that still support 3.11.
- `from __future__ import annotations` is unnecessary on 3.14+ (PEP 749 makes annotations lazy by default). Drop it from new files.
- Code that introspects annotations should use `annotationlib.get_annotations(...)` rather than reading `__annotations__` directly; the dunder no longer evaluates eagerly.
- Use `unknown`-equivalent (`object`, narrowed with `isinstance`) over `Any`. Reserve `Any` for genuine escape hatches at boundaries with a one-line comment explaining why.

## Docstrings

- PEP 257 plus Google-style sections (parsed by Sphinx Napoleon, the FastAPI ecosystem default).
- Required on every public module, class, function, and FastAPI / Flask / Django route.
- Summary line in imperative mood ("Return the queue depth", not "Returns..."), one line, blank line, then details.
- Sections: `Args:`, `Returns:`, `Raises:`, `Yields:`, `Example:`. Don't repeat the type hints inside the docstring; the signature owns types.
- For FastAPI routes the docstring becomes the OpenAPI `description`; keep the first line user-facing.

## Modules and files

- One concept per file. Split before a file grows past 400 lines.
- Public API at the top, helpers below; underscore-prefix private functions.
- Avoid mutable module-level state. Use a class, a closure, or pass state explicitly.
- `__all__` only when you actively want to control `from foo import *`; otherwise it just rots.

## Errors and validation

- Validate at boundaries (HTTP handlers, queue consumers, file readers) with `pydantic` v2 or `dataclasses` plus an explicit validator.
- Internal functions trust their inputs.
- Define a base exception per package and have callers `except` the base. Never `except Exception:` or bare `except:`.
- New in 3.14: bracketless multi-class `except` (`except (TimeoutError, ConnectionError):` is still preferred for readability; the new form is mostly a parser convenience).
- Avoid `return` / `break` / `continue` from `finally` blocks; 3.14 raises `SyntaxWarning` for this and the behavior is surprising.

## String building and templating

- Prefer f-strings (`f"..."`) for runtime composition. They are the fastest and clearest option.
- For SQL, shell, or HTML composition with untrusted input, use t-strings (Python 3.14, `t"..."` returns a `Template`) plus the appropriate sanitizer / parameterizer. Never inline user input into SQL with f-strings.

## Async

- Use `asyncio` (not `trio`) unless the project specifies otherwise.
- `async def` everywhere on the IO path; do not call sync IO from async functions without `asyncio.to_thread(...)`.
- For long-running async programs use `python -m asyncio ps <PID>` and `python -m asyncio pstree <PID>` to debug stuck tasks (3.14 introspection tools).
- Set timeouts on every external call (`asyncio.timeout`, `httpx.Timeout`, etc.). Crossreference the `scalability` skill for the timing budget.

## Tooling (canonical, 2026)

- **Ruff** for linting and formatting. Replaces black, isort, flake8, pylint, autoflake. Configure in `pyproject.toml`.
- **uv** for package management and virtualenvs. Replaces pip, pip-tools, virtualenv, pyenv. Run `uv sync`, `uv run pytest`, `uv add ...`.
- **mypy** or **pyright** for type checking; pyright in strict mode catches more.
- **pytest** with `pytest-asyncio` for async tests; `pytest-cov` for coverage. Test files match source: `foo.py` -> `test_foo.py`. `describe`-style with `Class TestFoo` is allowed; flat `def test_*` is the default.
- **ruff check --fix && ruff format** before declaring a Python task done. Pyright / mypy in CI.

## Anti-patterns to flag

- `Any` in source without a comment explaining the boundary.
- Bare `except:` or `except Exception:`.
- `from __future__ import annotations` in 3.14+ projects (now a no-op and signals out-of-date code).
- `Optional[X]` or `Union[A, B]` syntax in new code; use `X | None` and `A | B`.
- `typing.List`, `typing.Dict`, `typing.Tuple`, `typing.Type`; use lowercase built-ins.
- Mutable default arguments (`def f(items: list = []):` is a classic bug).
- f-strings with untrusted SQL or shell input.
- `time.sleep` in async functions.
- Test files that import production code via `sys.path` hacks; use a package layout instead.

## Self-audit before declaring done

- [ ] `ruff check` clean.
- [ ] `pyright` (strict) or `mypy --strict` clean for changed files.
- [ ] All public functions have type hints and a docstring.
- [ ] All external calls have a timeout.
- [ ] No bare `except`.
- [ ] No mutable default args.
- [ ] If touching backend code: cross-check the `scalability` skill checklist.
