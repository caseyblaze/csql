# csql zsh Tab-Completion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add zsh tab-completion for `csql` covering subcommands, the `--env` flag, and dynamic environment names read from the config directory.

**Architecture:** The completion logic lives inside the `csql` script itself, exposed via a hidden `csql completion zsh` subcommand that prints a zsh completion function to stdout. `install.sh` sources it from `~/.zshrc` at shell startup (the `kubectl`/`gh` pattern), so completion never drifts from the CLI.

**Tech Stack:** Bash (the `csql` script + `install.sh`), zsh completion system (`_describe`, `compadd`, `compdef`, glob qualifiers).

## Global Constraints

- Target shell: **zsh only**. No bash/fish.
- Idempotency: any line added to `~/.zshrc` must be guarded by a `grep` check, matching the existing PATH-guard style in `install.sh`.
- The completion script must be emitted as a **single-quoted heredoc** so the shell that runs `csql completion zsh` does not expand `$` variables inside it.
- Env-name completion reads `~/.config/cloud-sql-proxy/*.yaml`; an empty or missing config dir must produce no completions and no error.
- Only `start` and `stop` offer `--env`; `status` and `help` do not.

---

### Task 1: Add `completion` subcommand to `csql`

**Files:**
- Modify: `/Users/casey/Documents/csql/csql` (add `cmd_completion()` function before the dispatch block at line ~229; add `completion` branch to the `case` at line ~234; add usage line at line ~13)

**Interfaces:**
- Consumes: nothing (self-contained).
- Produces: `csql completion zsh` prints a zsh completion script to stdout and exits 0; `csql completion <other>` and `csql completion` (no arg) print an error to stderr and exit 1.

- [ ] **Step 1: Add the `cmd_completion` function**

Insert this function into `csql`, just before the `mkdir -p "$STATE_DIR"` line near the bottom:

```bash
cmd_completion() {
  local shell="${1:-}"
  case "$shell" in
    zsh)
      cat <<'EOF'
#compdef csql
_csql() {
  local config_dir="${HOME}/.config/cloud-sql-proxy"

  if (( CURRENT == 2 )); then
    local -a cmds
    cmds=(
      'start:Start proxy instances'
      'stop:Stop proxy instances'
      'status:Show status of all proxy instances'
      'help:Show usage'
    )
    _describe 'command' cmds
    return
  fi

  case ${words[2]} in
    start|stop)
      if [[ ${words[CURRENT-1]} == --env ]]; then
        local -a envs
        envs=(${config_dir}/*.yaml(N:t:r))
        _describe 'environment' envs
      else
        compadd -- --env
      fi
      ;;
  esac
}
compdef _csql csql
EOF
      ;;
    *)
      echo "Usage: csql completion zsh" >&2
      echo "Only zsh is supported." >&2
      exit 1
      ;;
  esac
}
```

- [ ] **Step 2: Add the dispatch branch**

In the top-level `case "$SUBCOMMAND"` block, add a `completion` branch before the `-h|--help` line:

```bash
  start)      cmd_start "$@" ;;
  stop)       cmd_stop "$@" ;;
  status)     cmd_status "$@" ;;
  completion) cmd_completion "$@" ;;
  -h|--help|help|"") usage; exit 0 ;;
  *) echo "Unknown command: $SUBCOMMAND"; usage; exit 1 ;;
```

- [ ] **Step 3: Document it in `usage()`**

Add one line to the Commands section of `usage()` (after the `status` line):

```bash
  echo "  completion zsh      Print zsh tab-completion script"
```

- [ ] **Step 4: Verify the happy path**

Run: `./csql completion zsh`
Expected: prints the completion script starting with `#compdef csql`, ending with `compdef _csql csql`, exit code 0. Confirm with `./csql completion zsh | head -1` → `#compdef csql`.

- [ ] **Step 5: Verify the error path**

Run: `./csql completion bogus; echo "exit=$?"`
Expected: stderr shows `Only zsh is supported.`, `exit=1`.

Run: `./csql completion; echo "exit=$?"`
Expected: same error, `exit=1`.

- [ ] **Step 6: Verify variables are NOT expanded by the outer shell**

Run: `./csql completion zsh | grep -c '${HOME}/.config/cloud-sql-proxy'`
Expected: `1` (the literal `${HOME}` survived — proving the single-quoted heredoc did not expand it).

- [ ] **Step 7: Commit**

```bash
git add csql
git commit -m "feat: add 'csql completion zsh' subcommand

Prints a zsh completion function that completes subcommands, the --env
flag for start/stop, and dynamic env names from the config dir.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Verify completion behaves correctly in a real zsh

**Files:**
- None modified. This task is an end-to-end verification of Task 1's output in an actual zsh session with a temp config dir.

**Interfaces:**
- Consumes: `csql completion zsh` from Task 1.
- Produces: confidence that `_describe`/`compadd`/glob logic works; no artifacts.

- [ ] **Step 1: Create a throwaway config dir with two envs**

```bash
TMPCFG=$(mktemp -d)
mkdir -p "$TMPCFG/.config/cloud-sql-proxy"
printf 'instances:\n  - name: p:r:db\n    port: 5432\n' > "$TMPCFG/.config/cloud-sql-proxy/dev.yaml"
printf 'instances:\n  - name: p:r:db\n    port: 5433\n' > "$TMPCFG/.config/cloud-sql-proxy/prod.yaml"
```

- [ ] **Step 2: Confirm the glob expands to env names under this config dir**

Run:
```bash
zsh -c 'config_dir="'"$TMPCFG"'/.config/cloud-sql-proxy"; print -l ${config_dir}/*.yaml(N:t:r)'
```
Expected: two lines, `dev` and `prod` (order may vary).

- [ ] **Step 3: Confirm the glob is safe on an empty/missing dir**

Run:
```bash
zsh -c 'config_dir="/nonexistent/xyz"; envs=(${config_dir}/*.yaml(N:t:r)); echo "count=${#envs}"'
```
Expected: `count=0`, exit code 0, no error printed.

- [ ] **Step 4: Load the completion into a zsh and confirm it registers without error**

Run:
```bash
PATH="$PWD:$PATH" zsh -c 'autoload -Uz compinit && compinit -u; source <(csql completion zsh); echo "loaded=$?"; whence -w _csql'
```
Expected: `loaded=0` and a line showing `_csql: function`.

- [ ] **Step 5: Clean up**

```bash
rm -rf "$TMPCFG"
```

- [ ] **Step 6: Commit (no-op check)**

No files changed in this task. Run `git status --short` and confirm it is empty (aside from anything from Task 1 already committed). Nothing to commit.

---

### Task 3: Wire completion into `install.sh`

**Files:**
- Modify: `/Users/casey/Documents/csql/install.sh` (add `.zshrc` wiring after the PATH block ending at line ~32; update the post-install message)

**Interfaces:**
- Consumes: `csql completion zsh` (available on PATH after the install step at lines 20-22).
- Produces: `~/.zshrc` contains a `compinit` invocation and `source <(csql completion zsh)`, each added at most once.

- [ ] **Step 1: Add the completion wiring block**

Immediately after the existing PATH-guard `fi` (the block ending around line 32, before the `BOLD=...` color definitions), insert:

```bash
# Ensure zsh completion system is initialised
if ! grep -q 'compinit' "$SHELL_RC" 2>/dev/null; then
  echo 'autoload -Uz compinit && compinit' >> "$SHELL_RC"
  echo "Added compinit to $SHELL_RC"
fi

# Wire up csql tab-completion
if ! grep -q 'csql completion zsh' "$SHELL_RC" 2>/dev/null; then
  echo 'source <(csql completion zsh)' >> "$SHELL_RC"
  echo "Added csql tab-completion to $SHELL_RC"
fi
```

Note: this is appended *after* the PATH export line, guaranteeing `csql` is on `PATH` by the time the `source` line runs at shell startup.

- [ ] **Step 2: Mention completion in the post-install message**

After the existing `Usage:` block at the end of the file, add:

```bash
echo ""
echo "${DIM}Tab-completion (zsh) is enabled after you reload your shell:${RESET}"
echo "${DIM}  csql <TAB>            # start / stop / status / help${RESET}"
echo "${DIM}  csql start --env <TAB>  # your configured environments${RESET}"
```

- [ ] **Step 3: Verify idempotency against a fake rc file**

Run:
```bash
FAKE=$(mktemp)
SHELL_RC="$FAKE"
# simulate the two guarded appends twice
for run in 1 2; do
  grep -q 'compinit' "$FAKE" 2>/dev/null || echo 'autoload -Uz compinit && compinit' >> "$FAKE"
  grep -q 'csql completion zsh' "$FAKE" 2>/dev/null || echo 'source <(csql completion zsh)' >> "$FAKE"
done
echo "compinit lines: $(grep -c compinit "$FAKE")"
echo "source  lines: $(grep -c 'csql completion zsh' "$FAKE")"
rm -f "$FAKE"
```
Expected: `compinit lines: 1` and `source  lines: 1` (no duplication on the second run).

- [ ] **Step 4: Syntax-check the installer**

Run: `bash -n install.sh; echo "exit=$?"`
Expected: `exit=0` (no syntax errors).

- [ ] **Step 5: Commit**

```bash
git add install.sh
git commit -m "feat: wire zsh tab-completion into install.sh

Idempotently appends compinit + 'source <(csql completion zsh)' to
~/.zshrc after the PATH block, and mentions completion in the
post-install message.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Document tab-completion in `README.md`

**Files:**
- Modify: `/Users/casey/Documents/csql/README.md` (add a "Tab completion" section; add completion to the Features list)

**Interfaces:**
- Consumes: the `csql completion zsh` subcommand and installer wiring.
- Produces: user-facing docs. No code.

- [ ] **Step 1: Add a bullet to the Features list**

Under `## Features`, add:

```markdown
- zsh tab-completion for subcommands and environment names
```

- [ ] **Step 2: Add a Tab completion section**

Add a new section (place it after the Configuration section):

```markdown
## Tab completion

zsh completion is set up automatically by `install.sh`. Reload your shell
to activate it:

    source ~/.zshrc

Then:

    csql <TAB>              # start / stop / status / help
    csql start --env <TAB>  # completes your configured environments

If you installed manually, add this to your `~/.zshrc` (after `compinit`):

    source <(csql completion zsh)
```

- [ ] **Step 3: Verify the docs render sensibly**

Run: `grep -n "Tab completion" README.md`
Expected: one match for the new section heading.

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: document zsh tab-completion

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review

**Spec coverage:**
- Subcommand completion → Task 1 (`_describe cmds`). ✓
- `--env` after start/stop → Task 1 (`compadd -- --env`). ✓
- Dynamic env names after `--env` → Task 1 (glob) + Task 2 (verified). ✓
- status/help exclude `--env` → Task 1 (`case` only matches `start|stop`). ✓
- `completion` subcommand + error path → Task 1 (Steps 4-5). ✓
- Single-quoted heredoc no-expand → Task 1 Step 6. ✓
- Installer idempotent wiring → Task 3. ✓
- Empty/missing config dir no error → Task 2 Step 3. ✓
- README → Task 4. ✓
- Out of scope (bash/fish, instance names, status --env) → not implemented. ✓

**Placeholder scan:** No TBD/TODO; every code step shows complete code. ✓

**Type/name consistency:** Function `_csql`, `cmd_completion`, and the string `csql completion zsh` are used identically across Tasks 1, 2, 3, 4. ✓
