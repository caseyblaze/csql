# csql zsh tab-completion — design

Date: 2026-07-23

## Goal

Add zsh tab-completion for the `csql` CLI so users can complete
subcommands and environment names without memorising them.

Completion behaviour (agreed scope):

- Complete subcommands: `start`, `stop`, `status`, `help`.
- After `start` / `stop`, complete the `--env` flag.
- After `--env`, dynamically complete environment names read from
  `~/.config/cloud-sql-proxy/*.yaml` (e.g. `dev`, `staging`, `prod`).
- `status` and `help` do NOT offer `--env` (the script does not accept it there).

Target shell: **zsh only**.

## Approach: completion logic lives inside `csql`

Single source of truth. `csql` gains a hidden subcommand that prints the
zsh completion script; `.zshrc` sources it at shell startup. When
subcommands change, completion follows automatically. This is the
`kubectl` / `gh` pattern.

Trade-off accepted: sourcing runs `csql` once per shell startup. The
work is a single `cat`-style heredoc print, negligible cost.

## Changes

### 1. `csql` — new `completion` subcommand

Add a `cmd_completion()` function and a `completion` branch to the
top-level `case`.

- `csql completion zsh` prints the zsh completion script to stdout.
- Any other/absent argument to `completion` prints an error naming the
  supported shells (`zsh`) to stderr and exits non-zero.
- `usage()` gains one line documenting `completion zsh`.

### 2. The zsh completion script (printed by the subcommand)

Emitted as a single-quoted heredoc so the shell running `csql` does not
expand it. Structure:

```zsh
_csql() {
  local config_dir="${HOME}/.config/cloud-sql-proxy"

  if (( CURRENT == 2 )); then
    local -a cmds
    cmds=(
      'start:Start proxy instances'
      'stop:Stop proxy instances'
      'status:Show status of all instances'
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
```

Notes:

- `CURRENT == 2` → completing the subcommand word.
- Env names use the zsh glob qualifier `(N:t:r)`: `N` = nullglob (no
  error when the config dir is empty/missing), `:t` = tail (basename),
  `:r` = strip `.yaml`.
- `compdef _csql csql` at the end registers the function — this is why
  `compinit` must have run before the script is sourced.

### 3. `install.sh` — wire completion into `.zshrc`

After the existing PATH block, ensure the following are present in
`~/.zshrc`, each guarded by a `grep` idempotency check (same style as the
existing PATH guard):

```zsh
autoload -Uz compinit && compinit
source <(csql completion zsh)
```

- Only append the `compinit` line if no `compinit` invocation already
  exists in `.zshrc` (avoid double-init, which is slow/noisy).
- Only append the `source <(csql completion zsh)` line if not already present.
- The post-install message mentions that tab-completion is now available
  after reloading the shell.

### 4. `README.md`

Add a short "Tab completion" section: what it completes, and that it is
set up automatically by the installer (reload shell to activate). Include
the manual one-liner for users who installed by hand.

## Testing / verification

Manual, since this is shell-integration behaviour:

1. `csql completion zsh` prints a script and exits 0.
2. `csql completion bogus` errors to stderr, exits non-zero.
3. In a fresh zsh with the script sourced:
   - `csql <TAB>` → offers start/stop/status/help.
   - `csql start --env <TAB>` → offers real env names from config dir.
   - `csql status <TAB>` → offers nothing (no `--env`).
   - Empty/missing config dir → `--env` completion offers nothing, no error.
4. Re-running `install.sh` does not duplicate lines in `.zshrc`.

## Out of scope

- bash / fish completion.
- Completing instance names, ports, or PSC flags.
- Completing `--env` for `status`.
