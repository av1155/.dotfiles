# Repeatable workflow for Git subtrees (first machine & others)

> Example used below:
>
> - Parent repo: `College_Code`
> - Course dir: `CSC_421`
> - Assignment repo: `git@github.com:csc421-261/project-1-av1155.git`
> - Matching remote name: `project-1-av1155`
> - Subtree path (prefix): `CSC_421/project-1-av1155`
> - Default branch: `main` (replace if your upstream uses something else)

---

## A) First machine — fresh setup (create dir, add subtree)

### 0) Clone or open your parent repo

```bash
# If not already cloned
git clone git@github.com:av1155/College_Code.git ~/College_Code
cd ~/College_Code

# Make sure the tree is clean
git status
```

### 1) Create and track the course directory (once per course)

```bash
mkdir -p CSC_421
touch CSC_421/.gitkeep
git add CSC_421/.gitkeep
git commit -m "chore(csc_421): scaffold coursework directory"
git push origin main
```

### 2) Add the assignment remote (remote name matches repo)

```bash
git remote add project-1-av1155 git@github.com:csc421-261/project-1-av1155.git
git fetch project-1-av1155
# Optional: confirm default branch
git remote show project-1-av1155 | sed -n 's/.*HEAD branch: //p'
```

### 3) Add the subtree

```bash
git subtree add \
  --prefix=CSC_421/project-1-av1155 \
  project-1-av1155 \
  main \
  --squash
```

### 4) Store helpful defaults (so helpers or scripts need no args)

```bash
git config subtree.CSC_421/project-1-av1155.remote project-1-av1155
git config subtree.CSC_421/project-1-av1155.branch main
```

### 5) Push parent repo so other machines receive the subtree content

```bash
git push origin main
```

> **If you previously had a nested clone** at `CSC_421/project-1-av1155`  
> (i.e., there’s a `.git/` inside that folder), convert it before step 3:
>
> ```bash
> rm -rf CSC_421/project-1-av1155/.git
> # then run the subtree add command in step 3
> ```

---

## B) Second machine (and _every_ other machine) — reuse existing subtree

> Subtrees are ordinary directories in the parent repo history, so after you
> clone/pull `College_Code`, you only need to wire up the assignment **remote**
> and (optionally) store the subtree defaults on that machine.

### 0) Clone or update the parent repo

```bash
# If first time on this machine
git clone git@github.com:av1155/College_Code.git ~/College_Code
cd ~/College_Code

# Otherwise
cd ~/College_Code
git pull --rebase origin main
```

### 1) Add the assignment remote (if missing) and fetch

```bash
# Add only if it doesn't exist
git remote get-url project-1-av1155 >/dev/null 2>&1 || \
  git remote add project-1-av1155 git@github.com:csc421-261/project-1-av1155.git

git fetch project-1-av1155
```

### 2) Store subtree defaults on this machine (once)

```bash
git config subtree.CSC_421/project-1-av1155.remote project-1-av1155
git config subtree.CSC_421/project-1-av1155.branch main
```

### 3) Verify it’s wired up

```bash
# Show what you'd push compared to upstream
git log --oneline project-1-av1155/main..HEAD -- CSC_421/project-1-av1155
```

---

## C) Daily usage (same on all machines)

### Make changes in the subtree and commit to your parent repo

```bash
# edit files under CSC_421/project-1-av1155/...
git add CSC_421/project-1-av1155
git commit -m "feat(csc_421): <your change here>"
git push origin main
```

### Push your subtree changes to the assignment repo (professor’s repo)

```bash
# run from anywhere
git subtree push --prefix=CSC_421/project-1-av1155 project-1-av1155 main
```

### Pull professor updates back into your subtree (squashed)

```bash
git subtree pull --prefix=CSC_421/project-1-av1155 project-1-av1155 main --squash
# then back up your parent repo
git push origin main
```

---

## D) Adding more assignments later (repeatable pattern)

```bash
# Example: project-2
git remote add project-2-av1155 git@github.com:csc421-261/project-2-av1155.git
git fetch project-2-av1155

git subtree add \
  --prefix=CSC_421/project-2-av1155 \
  project-2-av1155 \
  main \
  --squash

git config subtree.CSC_421/project-2-av1155.remote project-2-av1155
git config subtree.CSC_421/project-2-av1155.branch main

git push origin main
```

---

## E) Quick reference (raw commands vs helpers)

- **Preview what would be pushed**

    ```bash
    git log --oneline project-1-av1155/main..HEAD -- CSC_421/project-1-av1155
    git diff --stat  project-1-av1155/main..HEAD -- CSC_421/project-1-av1155
    ```

- **Push subtree → professor’s repo**

    ```bash
    git subtree push --prefix=CSC_421/project-1-av1155 project-1-av1155 main
    ```

- **Pull professor’s updates → subtree (squashed)**
    ```bash
    git subtree pull --prefix=CSC_421/project-1-av1155 project-1-av1155 main --squash
    ```

> If you installed the `gspush/gspull/gssub` helpers, you can run them from
> inside the subtree directory without arguments:
>
> - `gssub` → preview (commits, diffstat)
> - `gspush` → push to professor’s repo
> - `gspull` → pull professor’s updates (squashed)

---

## Functions to Place in .zshrc / .bashrc

```bash
# --- git subtree helpers (general purpose) ---

# Resolve subtree prefix (defaults to CWD relative to repo root)
_subtree_prefix() {
  if [[ -n "$1" ]]; then
    printf '%s\n' "$1"
    return
  fi
  local p
  p=$(git rev-parse --show-prefix 2>/dev/null) || { echo "Not in a git repo." >&2; return 1; }
  [[ -z "$p" ]] && { echo "You're at repo root; cd into the subtree folder or pass a prefix." >&2; return 1; }
  printf '%s\n' "${p%/}"  # strip trailing slash
}

# Detect default branch of a remote
_subtree_default_branch() {
  local remote="$1" head
  head=$(git symbolic-ref -q --short "refs/remotes/${remote}/HEAD" 2>/dev/null) \
    || head=$(git remote show "$remote" 2>/dev/null | sed -n 's/.*HEAD branch: //p')
  if [[ -n "$head" ]]; then
    printf '%s\n' "${head#"${remote}"/}"
  elif git rev-parse -q --verify "refs/remotes/${remote}/main" >/dev/null; then
    echo main
  elif git rev-parse -q --verify "refs/remotes/${remote}/master" >/dev/null; then
    echo master
  else
    echo main
  fi
}

# Read dir-local config: store per-subtree settings in .git at key "subtree.<prefix>.*"
# Set with: git config "subtree.<prefix>.remote" upstream ; git config "subtree.<prefix>.branch" main
_subtree_cfg() {
  local prefix="$1" key="$2"
  git config --get "subtree.${prefix}.${key}" 2>/dev/null
}

gspush() {
  if [[ $1 == "-h" || $1 == "--help" || $1 == "--usage" ]]; then
    echo "Usage: gspush [prefix] [remote] [branch]"; echo
    echo "Push a subtree to a remote branch."
    echo " - prefix: path to subtree (defaults to current dir relative to repo root)"
    echo " - remote: remote name (defaults to subtree.<prefix>.remote, else 'assignment' or 'upstream')"
    echo " - branch: branch name (defaults to subtree.<prefix>.branch, else remote’s default, else main)"
    return 0
  fi
  local prefix remote branch top
  prefix=$(_subtree_prefix "$1") || return 1
  remote="${2:-$(_subtree_cfg "$prefix" remote)}"
  [[ -z "$remote" ]] && { git remote get-url assignment >/dev/null 2>&1 && remote=assignment; }
  [[ -z "$remote" ]] && { git remote get-url upstream   >/dev/null 2>&1 && remote=upstream; }
  [[ -z "$remote" ]] && { echo "Remote not set. Run 'gspush --usage'." >&2; return 1; }
  branch="${3:-$(_subtree_cfg "$prefix" branch)}"
  [[ -z "$branch" ]] && branch=$(_subtree_default_branch "$remote")
  top=$(git rev-parse --show-toplevel) || { echo "Not in a git repo." >&2; return 1; }
  echo "Pushing subtree: prefix='$prefix' → ${remote}/${branch}"
  ( cd "$top" && git subtree push --prefix="$prefix" "$remote" "$branch" )
}

gspull() {
  if [[ $1 == "-h" || $1 == "--help" || $1 == "--usage" ]]; then
    echo "Usage: gspull [prefix] [remote] [branch]"; echo
    echo "Pull a subtree from a remote branch (with squash)."
    echo " - prefix: path to subtree (defaults to current dir relative to repo root)"
    echo " - remote: remote name (defaults to subtree.<prefix>.remote, else 'assignment' or 'upstream')"
    echo " - branch: branch name (defaults to subtree.<prefix>.branch, else remote’s default, else main)"
    return 0
  fi
  local prefix remote branch top
  prefix=$(_subtree_prefix "$1") || return 1
  remote="${2:-$(_subtree_cfg "$prefix" remote)}"
  [[ -z "$remote" ]] && { git remote get-url assignment >/dev/null 2>&1 && remote=assignment; }
  [[ -z "$remote" ]] && { git remote get-url upstream   >/dev/null 2>&1 && remote=upstream; }
  [[ -z "$remote" ]] && { echo "Remote not set. Run 'gspull --usage'." >&2; return 1; }
  branch="${3:-$(_subtree_cfg "$prefix" branch)}"
  [[ -z "$branch" ]] && branch=$(_subtree_default_branch "$remote")
  top=$(git rev-parse --show-toplevel) || { echo "Not in a git repo." >&2; return 1; }
  echo "Pulling subtree: ${remote}/${branch} → prefix='$prefix' (squash)"
  ( cd "$top" && git subtree pull --prefix="$prefix" "$remote" "$branch" --squash )
}

gssub() {
  if [[ $1 == "-h" || $1 == "--help" || $1 == "--usage" ]]; then
    echo "Usage: gssub [prefix] [remote] [branch]"
    echo
    echo "Preview commits and diffstat that would be pushed for a subtree."
    echo " - prefix: path to subtree (defaults to current dir relative to repo root)"
    echo " - remote: remote name (defaults to subtree.<prefix>.remote, else 'assignment' or 'upstream')"
    echo " - branch: branch name (defaults to subtree.<prefix>.branch, else remote’s default, else main)"
    return 0
  fi

  local prefix remote branch
  prefix=$(_subtree_prefix "$1") || return 1
  remote="${2:-$(_subtree_cfg "$prefix" remote)}"
  [[ -z "$remote" ]] && { git remote get-url assignment >/dev/null 2>&1 && remote=assignment; }
  [[ -z "$remote" ]] && { git remote get-url upstream   >/dev/null 2>&1 && remote=upstream; }
  [[ -z "$remote" ]] && { echo "Remote not set. Run 'gssub --usage'." >&2; return 1; }

  branch="${3:-$(_subtree_cfg "$prefix" branch)}"
  [[ -z "$branch" ]] && branch=$(_subtree_default_branch "$remote")

  echo "== Commits to push (HEAD not in ${remote}/${branch}) for $prefix =="
  git log --oneline --decorate --graph "${remote}/${branch}..HEAD" -- ":/$prefix"
  echo
  echo "== Diffstat vs ${remote}/${branch} =="
  git diff --stat "${remote}/${branch}..HEAD" -- ":/$prefix"
}
```
