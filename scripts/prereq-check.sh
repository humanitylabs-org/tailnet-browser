#!/usr/bin/env bash
set -euo pipefail

ok() { echo "✅ $1"; }
warn() { echo "⚠️  $1"; }
fail() { echo "❌ $1"; exit 1; }

need_cmd() {
  local c="$1"
  if command -v "$c" >/dev/null 2>&1; then
    ok "$c: $(command -v "$c")"
  else
    fail "Missing required command: $c"
  fi
}

echo "Tailnet Browser prereq check"

need_cmd tailscale
if tailscale status >/dev/null 2>&1; then
  ok "tailscale connected"
else
  fail "tailscale is not connected. Run: tailscale up"
fi

need_cmd Xvfb
need_cmd x11vnc
need_cmd websockify

if command -v chromium >/dev/null 2>&1; then
  ok "browser: chromium"
elif command -v chromium-browser >/dev/null 2>&1; then
  ok "browser: chromium-browser"
elif command -v google-chrome >/dev/null 2>&1; then
  ok "browser: google-chrome"
else
  fail "No Chromium/Chrome binary found"
fi

if [[ -x /usr/share/novnc/utils/launch.sh ]]; then
  ok "noVNC launch script: /usr/share/novnc/utils/launch.sh"
else
  fail "Missing noVNC launch script at /usr/share/novnc/utils/launch.sh"
fi

echo
ok "All required checks passed"
