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

# Ensure ~/bin is in PATH
SHELL_RC="$HOME/.zshrc"
if ! grep -q 'PATH.*HOME/bin\|PATH.*~/bin' "$SHELL_RC" 2>/dev/null; then
  echo 'export PATH="$HOME/bin:$PATH"' >> "$SHELL_RC"
  echo "Added ~/bin to PATH in $SHELL_RC"
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
echo "  \$EDITOR ~/.config/cloud-sql-proxy/dev.yaml"
echo ""
echo "${DIM}Config format:${RESET}"
echo "${DIM}  instances:${RESET}"
echo "${DIM}    - name: project:region:instance${RESET}"
echo "${DIM}      port: 5432${RESET}"
echo ""
echo "${DIM}Usage:${RESET}"
echo "${DIM}  csql start            # start all envs${RESET}"
echo "${DIM}  csql start --env dev  # start only dev${RESET}"
echo "${DIM}  csql stop${RESET}"
echo "${DIM}  csql status${RESET}"
