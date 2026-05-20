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

# Ensure ~/bin is in PATH
SHELL_RC="$HOME/.zshrc"
if ! grep -q 'PATH.*HOME/bin\|PATH.*~/bin' "$SHELL_RC" 2>/dev/null; then
  echo 'export PATH="$HOME/bin:$PATH"' >> "$SHELL_RC"
  echo "Added ~/bin to PATH in $SHELL_RC"
fi

echo ""
echo "✓ csql installed to $INSTALL_DIR/csql"
echo ""
echo "Next steps:"
echo "  1. Reload your shell: source $SHELL_RC"
echo "  2. Create a config:   mkdir -p ~/.config/cloud-sql-proxy"
echo "  3. Add your instances to ~/.config/cloud-sql-proxy/dev.yaml"
echo ""
echo "Config format:"
echo "  instances:"
echo "    - name: project:region:instance"
echo "      port: 5432"
echo ""
echo "Usage:"
echo "  csql start            # start all envs"
echo "  csql start --env dev  # start only dev"
echo "  csql stop"
echo "  csql status"
