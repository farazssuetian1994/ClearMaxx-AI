#!/usr/bin/env bash
#
# reload.sh — fast feedback loop for the ClearMaxx SwiftUI app on the iOS Simulator.
#
# Does an incremental build, reinstalls, and relaunches on the booted simulator.
# This is the practical stand-in for "hot reload" on Xcode 26 (the classic
# injectors no longer work because Xcode stopped logging Swift compile commands).
#
# Usage:
#   ./reload.sh              build + reinstall + relaunch once
#   ./reload.sh --shot       …and save a screenshot to /tmp/clearmaxx-shot.png
#   ./reload.sh --shot out.png   …screenshot to a custom path
#   ./reload.sh --watch      stay running; auto-reload whenever a .swift file is saved
#
set -euo pipefail
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$ROOT/ClearMaxxApp/ClearMaxx.xcodeproj"
SRC_DIR="$ROOT/ClearMaxxApp/ClearMaxx"
SCHEME="ClearMaxx"
BUNDLE_ID="com.clearmaxx.app"
PREFERRED_DEVICE="iPhone 17"
BUILD_LOG="/tmp/clearmaxx-build.log"

uuid_re='[0-9A-Fa-f]{8}-([0-9A-Fa-f]{4}-){3}[0-9A-Fa-f]{12}'

pick_sim() {
  # Prefer an already-booted simulator; otherwise boot the preferred device.
  local id
  id="$(xcrun simctl list devices booted | grep -oE "$uuid_re" | head -1 || true)"
  if [ -z "$id" ]; then
    id="$(xcrun simctl list devices available | grep "$PREFERRED_DEVICE (" | grep -oE "$uuid_re" | head -1 || true)"
    [ -n "$id" ] && xcrun simctl boot "$id" >/dev/null 2>&1 || true
  fi
  echo "$id"
}

reload() {
  local sim="$1"
  echo "▶︎ Building (incremental)…"
  if ! xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Debug \
        -destination "platform=iOS Simulator,id=$sim" build > "$BUILD_LOG" 2>&1; then
    echo "✗ Build failed — last lines:"
    grep -E "error:|warning: .*error" "$BUILD_LOG" | head -20 || tail -25 "$BUILD_LOG"
    return 1
  fi
  local app
  app="$(ls -dt "$HOME"/Library/Developer/Xcode/DerivedData/ClearMaxx-*/Build/Products/Debug-iphonesimulator/ClearMaxx.app 2>/dev/null | head -1)"
  echo "▶︎ Installing & relaunching…"
  xcrun simctl install "$sim" "$app"
  xcrun simctl terminate "$sim" "$BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl launch "$sim" "$BUNDLE_ID" >/dev/null
  echo "✓ Reloaded."
}

SIM="$(pick_sim)"
if [ -z "$SIM" ]; then
  echo "✗ No simulator found. Open Simulator or create an '$PREFERRED_DEVICE' device." >&2
  exit 1
fi
open -a Simulator || true

case "${1:-}" in
  --watch)
    echo "👀 Watching $SRC_DIR for .swift changes (Ctrl-C to stop)…"
    reload "$SIM" || true
    MARK="$(mktemp)"
    while true; do
      if find "$SRC_DIR" -name '*.swift' -newer "$MARK" -print -quit 2>/dev/null | grep -q .; then
        touch "$MARK"
        echo "—— change detected $(date '+%H:%M:%S') ——"
        reload "$SIM" || true
      fi
      sleep 1
    done
    ;;
  --shot)
    reload "$SIM"
    OUT="${2:-/tmp/clearmaxx-shot.png}"
    sleep 1.5
    xcrun simctl io "$SIM" screenshot "$OUT" >/dev/null 2>&1 && echo "▶︎ Screenshot: $OUT"
    ;;
  *)
    reload "$SIM"
    ;;
esac
