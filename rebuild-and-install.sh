#!/usr/bin/env bash
# Rebuild the patched AeroSpace (branch tree-placeholders) and install it
# over the brew bundle + CLI. Run after rebasing on an upstream update.
#
# NOTE: re-signing changes the binary's cdhash, so macOS will ask you to
# re-grant Accessibility once (System Settings > Privacy > Accessibility:
# remove AeroSpace with -, re-add /Applications/AeroSpace.app, toggle ON).
set -euo pipefail
cd "$(dirname "$0")"

APP=/Applications/AeroSpace.app
CLI=/opt/homebrew/Caskroom/aerospace/0.20.3-Beta/AeroSpace-v0.20.3-Beta/bin/aerospace

echo "==> Building (swift build; skipping the XCTest target CLT can't build)"
./generate.sh --ignore-xcodeproj --ignore-cmd-help
swift build

echo "==> Stopping running AeroSpace"
killall AeroSpace AeroSpaceApp 2>/dev/null || true
rm -f /tmp/bobko.aerospace*.sock

echo "==> Installing patched app executable + CLI"
cp -f .build/debug/AeroSpaceApp "$APP/Contents/MacOS/AeroSpace"
cp -f .build/debug/aerospace   "$CLI"
codesign --force --sign - "$APP" >/dev/null 2>&1
codesign --force --sign - "$CLI" >/dev/null 2>&1

echo "==> Relaunching"
open -a "$APP"
echo "Done. If windows aren't managed within ~10s, re-grant Accessibility (see note above)."
