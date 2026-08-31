#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="$HOME/bin"
SCRIPT_URL="https://raw.githubusercontent.com/caseyblaze/csql/main/csql"

# Check yq
if ! command -v yq &>/dev/null; then
  echo "yq is required. Installing via Homebrew..."
  brew install yq
fi

# Check cloud-sql-proxy
if ! command -v cloud-sql-proxy &>/dev/null; then
  echo "cloud-sql-proxy is required. Installing via Homebrew..."
  brew install cloud-sql-proxy
fi

# Install script
mkdir -p "$INSTALL_DIR"
curl -fsSL "$SCRIPT_URL" -o "$INSTALL_DIR/csql"
chmod +x "$INSTALL_DIR/csql"

# Create config directory so first-run commands don't error on missing dir
mkdir -p "$HOME/.config/cloud-sql-proxy"

SHELL_RC="$HOME/.zshrc"

# Appending to a file whose last line has no newline glues our first line onto
# it, which silently corrupts whatever was there and can break the whole rc file.
if [ -s "$SHELL_RC" ] && [ "$(tail -c1 "$SHELL_RC" | wc -l)" -eq 0 ]; then
  printf '\n' >> "$SHELL_RC"
fi

# Ensure ~/bin is in PATH
if ! grep -q 'PATH.*HOME/bin\|PATH.*~/bin' "$SHELL_RC" 2>/dev/null; then
  echo 'export PATH="$HOME/bin:$PATH"' >> "$SHELL_RC"
  echo "Added ~/bin to PATH in $SHELL_RC"
fi

# Wire up csql tab-completion.
#
# Never append an unconditional `compinit` here. compinit resets $_comps, so a
# second run late in .zshrc silently wipes every completion registered before it
# — gcloud/bq/gsutil, nvm and bun all register at source time via `complete -F`
# rather than from fpath, so they vanish. Bootstrap the completion system only
# when it is not up yet, the same way gcloud's completion.zsh.inc does.
if ! grep -q 'csql completion zsh' "$SHELL_RC" 2>/dev/null; then
  cat >> "$SHELL_RC" <<'COMPLETION_BLOCK'

# csql tab-completion
if command -v csql >/dev/null; then
  whence compdef >/dev/null 2>&1 || { autoload -Uz compinit && compinit }
  source <(csql completion zsh)
fi
COMPLETION_BLOCK
  echo "Added csql tab-completion to $SHELL_RC"
fi

# Earlier versions of this installer appended a bare compinit directly above their
# completion line. Match that exact pair so a hand-written compinit elsewhere in
# the file is never mistaken for it, and report rather than edit — which of the
# two lines is the redundant one depends on the rest of the file.
OLD_COMPINIT_LINE='autoload -Uz compinit && compinit'
OLD_CSQL_LINE='command -v csql >/dev/null && source <(csql completion zsh)'
if grep -B1 -Fx "$OLD_CSQL_LINE" "$SHELL_RC" 2>/dev/null | grep -Fxq "$OLD_COMPINIT_LINE"; then
  echo ""
  echo "WARNING: an earlier csql installer added these two lines to $SHELL_RC:"
  echo "    $OLD_COMPINIT_LINE"
  echo "    $OLD_CSQL_LINE"
  echo "  That compinit re-runs at the end of your rc file and resets zsh's"
  echo "  completion table, so completions registered earlier stop working"
  echo "  (gcloud, bq, gsutil, nvm and bun all register that way)."
  echo "  Delete both lines, keep a single compinit above them all, and re-run"
  echo "  this installer to get the guarded block instead."
fi

BOLD=$'\033[1m'
YELLOW=$'\033[33m'
GREEN=$'\033[32m'
DIM=$'\033[2m'
RESET=$'\033[0m'

echo ""
echo "${GREEN}✓ csql installed to $INSTALL_DIR/csql${RESET}"
echo ""
echo "${BOLD}${YELLOW}┌──────────────────────────────────────────────────────────┐${RESET}"
echo "${BOLD}${YELLOW}│  REQUIRED: reload your shell before csql will be found   │${RESET}"
echo "${BOLD}${YELLOW}│                                                          │${RESET}"
echo "${BOLD}${YELLOW}│    ${RESET}${BOLD}source $SHELL_RC${RESET}$(printf '%*s' $((47 - ${#SHELL_RC})) '')${BOLD}${YELLOW}│${RESET}"
echo "${BOLD}${YELLOW}│                                                          │${RESET}"
echo "${BOLD}${YELLOW}│  (or open a new terminal window)                         │${RESET}"
echo "${BOLD}${YELLOW}└──────────────────────────────────────────────────────────┘${RESET}"
echo ""
echo "${BOLD}Then create a config:${RESET}"
echo "  cp config.example.yaml ~/.config/cloud-sql-proxy/dev.yaml"
echo "  \$EDITOR ~/.config/cloud-sql-proxy/dev.yaml"
echo ""
echo "${DIM}Config format:${RESET}"
echo "${DIM}  instances:${RESET}"
echo "${DIM}    - name: project:region:instance${RESET}"
echo "${DIM}      port: 5432${RESET}"
echo "${DIM}    - name: project:region:psc-instance${RESET}"
echo "${DIM}      port: 5433${RESET}"
echo "${DIM}      psc: true${RESET}"
echo ""
echo "${DIM}Usage:${RESET}"
echo "${DIM}  csql start            # start all envs${RESET}"
echo "${DIM}  csql start --env dev  # start only dev${RESET}"
echo "${DIM}  csql stop${RESET}"
echo "${DIM}  csql restart${RESET}"
echo "${DIM}  csql status           # instances, plus credential state${RESET}"
echo ""
echo "${BOLD}Google credentials:${RESET}"
echo "${DIM}  cloud-sql-proxy reads your credentials once at startup, so re-running${RESET}"
echo "${DIM}  'gcloud auth application-default login' does nothing for a proxy that is${RESET}"
echo "${DIM}  already up. These two handle the restart for you:${RESET}"
echo ""
echo "  ${BOLD}csql login${RESET}          re-authenticate, then restart what was running"
echo "  ${BOLD}csql watch enable${RESET}   let proxies restart themselves when credentials change"
echo ""
echo "${DIM}Tab-completion (zsh) is enabled after you reload your shell:${RESET}"
echo "${DIM}  csql <TAB>              # start / stop / restart / status / login / watch${RESET}"
echo "${DIM}  csql start --env <TAB>  # your configured environments${RESET}"
echo "${DIM}  csql watch <TAB>        # enable / disable / status${RESET}"
