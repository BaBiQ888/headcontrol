#!/usr/bin/env bash
# Build (if needed), then install HeadControl.app into /Applications and launch it.
#
# Combined with the stable "HeadControl Dev" code-signing cert (see make-app.sh),
# this means you only need to grant Camera + Accessibility permissions ONCE.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/HeadControl.app"
DEST="/Applications/HeadControl.app"

# 1. Build / package if missing or older than any source file.
if [[ ! -d "$APP" ]] || [[ -n "$(find "$ROOT/Sources" -newer "$APP" -print -quit 2>/dev/null)" ]]; then
    echo "Building app…"
    "$ROOT/Scripts/make-app.sh"
fi

# 2. Quit running instance.
osascript -e 'tell application "HeadControl" to quit' >/dev/null 2>&1 || true
pkill -x HeadControl 2>/dev/null || true
# Wait briefly for the process to exit before overwriting.
for _ in 1 2 3 4 5; do
    pgrep -x HeadControl >/dev/null || break
    sleep 0.2
done

# 3. Replace bundle in /Applications.
if [[ -d "$DEST" ]]; then
    rm -rf "$DEST"
fi
cp -R "$APP" "$DEST"

echo "Installed: $DEST"

# 4. Launch.
open "$DEST"
echo "Launched. Look for the head-and-arrows icon in the menu bar."
