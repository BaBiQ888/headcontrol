#!/usr/bin/env bash
# One-command installer for HeadControl.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/BaBiQ888/headcontrol/main/Scripts/bootstrap.sh | bash
#
# Or, after cloning the repo:
#   ./Scripts/bootstrap.sh
#
# The script clones (or updates) the repository under ~/.headcontrol-src,
# builds the .app, installs it to /Applications, and launches it.

set -euo pipefail

REPO_URL="https://github.com/BaBiQ888/headcontrol.git"
SRC_DIR="$HOME/.headcontrol-src"

bold() { printf "\033[1m%s\033[0m\n" "$1"; }
warn() { printf "\033[33m%s\033[0m\n" "$1"; }
fail() { printf "\033[31m%s\033[0m\n" "$1" >&2; exit 1; }

bold "==> HeadControl installer"

# 1. macOS sanity check
if [[ "$(uname)" != "Darwin" ]]; then
    fail "HeadControl is macOS only."
fi

osmajor="$(sw_vers -productVersion | cut -d. -f1)"
if (( osmajor < 14 )); then
    fail "macOS 14 (Sonoma) or newer required. You have $(sw_vers -productVersion)."
fi

# 2. Toolchain check
if ! command -v swift >/dev/null 2>&1; then
    warn "Swift compiler not found."
    echo "Run this first to install Xcode Command Line Tools, then re-run the installer:"
    echo "  xcode-select --install"
    exit 1
fi

if ! command -v git >/dev/null 2>&1; then
    fail "git not found. Install Xcode Command Line Tools (xcode-select --install)."
fi

# 3. Get / update sources
if [[ -d "$SRC_DIR/.git" ]]; then
    bold "==> Updating sources in $SRC_DIR"
    git -C "$SRC_DIR" fetch --quiet origin
    git -C "$SRC_DIR" reset --hard --quiet origin/main
else
    bold "==> Cloning into $SRC_DIR"
    rm -rf "$SRC_DIR"
    git clone --quiet --depth=1 "$REPO_URL" "$SRC_DIR"
fi

# 4. Build + install
bold "==> Building and installing to /Applications"
cd "$SRC_DIR"
./Scripts/install.sh

# 5. Post-install guidance
cat <<EOF

$(bold "==> Done")

HeadControl is now installed at /Applications/HeadControl.app and running.
Look for the head-and-arrows icon in your menu bar (top-right).

First-launch checklist:

  1. Camera permission       — accept the system prompt when it appears.
  2. Accessibility permission — needed to inject keystrokes:
       Menu bar icon → Open Window → click "Open Accessibility Settings",
       then drag /Applications/HeadControl.app into the list and tick it.

To upgrade later, just re-run:
  curl -fsSL https://raw.githubusercontent.com/BaBiQ888/headcontrol/main/Scripts/bootstrap.sh | bash

To uninstall:
  rm -rf /Applications/HeadControl.app "$SRC_DIR"
  tccutil reset Camera local.headcontrol
  tccutil reset Accessibility local.headcontrol

EOF
