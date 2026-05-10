#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ok() { echo "✅ $1"; }
fail() { echo "❌ $1"; exit 1; }

as_root() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    fail "Root privileges are required and sudo is not installed."
  fi
}

"$APP_DIR/scripts/prereq-check.sh"

cat <<'EOF' >/tmp/remote-browser.sh
#!/bin/bash
set -euo pipefail
export DISPLAY=:99

if command -v chromium >/dev/null 2>&1; then
  BROWSER_BIN="chromium"
elif command -v chromium-browser >/dev/null 2>&1; then
  BROWSER_BIN="chromium-browser"
elif command -v google-chrome >/dev/null 2>&1; then
  BROWSER_BIN="google-chrome"
else
  echo "No Chromium/Chrome binary found" >&2
  exit 1
fi

NOVNC_LAUNCH="/usr/share/novnc/utils/launch.sh"
if [[ ! -x "$NOVNC_LAUNCH" ]]; then
  echo "noVNC launcher not found: $NOVNC_LAUNCH" >&2
  exit 1
fi

NOVNC_WEB_ROOT="/usr/local/share/remote-browser/novnc"
mkdir -p "$NOVNC_WEB_ROOT"
for item in /usr/share/novnc/*; do
  name="$(basename "$item")"
  [[ "$name" == "index.html" ]] && continue
  ln -sfn "$item" "$NOVNC_WEB_ROOT/$name"
done

cat >"$NOVNC_WEB_ROOT/index.html" <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <meta name="theme-color" content="#0B0B0D" />
  <title>Tailnet Browser</title>
</head>
<body style="margin:0;background:#0B0B0D;color:#F2F2F2;font:16px system-ui,-apple-system,sans-serif;display:grid;place-items:center;min-height:100vh;">
  <p>Launching Tailnet Browser…</p>
  <script>
    (function () {
      const fromPathRoute = (window.location.pathname || '').startsWith('/browser');
      const wsPath = fromPathRoute ? 'browser/websockify' : 'websockify';
      const page = fromPathRoute ? '/browser/vnc_auto.html' : 'vnc_auto.html';
      const target = `${page}?path=${encodeURIComponent(wsPath)}&title=${encodeURIComponent('Tailnet Browser')}`;
      window.location.replace(target);
    })();
  </script>
</body>
</html>
HTML

PROFILE_DIR="/tmp/tailnet-browser-profile"
mkdir -p "$PROFILE_DIR"

pkill -f "Xvfb :99" 2>/dev/null || true
pkill -f "x11vnc.*:99" 2>/dev/null || true
pkill -f "websockify.*6080" 2>/dev/null || true
pkill -f "novnc.*6080" 2>/dev/null || true
pkill -f "tailnet-browser-profile" 2>/dev/null || true
sleep 1

Xvfb :99 -screen 0 1280x720x24 -ac &
XVFB_PID=$!
sleep 1

"$BROWSER_BIN" --no-sandbox --disable-gpu --no-first-run --disable-default-apps \
  --user-data-dir="$PROFILE_DIR" \
  --window-size=1280,720 --window-position=0,0 --display=:99 &
sleep 2

x11vnc -display :99 -nopw -forever -shared -localhost -bg
sleep 1

"$NOVNC_LAUNCH" --listen 127.0.0.1:6080 --vnc localhost:5900 --web "$NOVNC_WEB_ROOT"

kill "$XVFB_PID" 2>/dev/null || true
pkill -f "x11vnc.*:99" 2>/dev/null || true
pkill -f "websockify.*6080" 2>/dev/null || true
pkill -f "tailnet-browser-profile" 2>/dev/null || true
EOF

as_root install -m 0755 /tmp/remote-browser.sh /usr/local/bin/remote-browser.sh
rm -f /tmp/remote-browser.sh

cat <<'EOF' >/tmp/remote-browser.service
[Unit]
Description=Remote Browser (Chromium via noVNC)
After=network-online.target

[Service]
Type=simple
User=root
Environment=HOME=/root
ExecStart=/usr/local/bin/remote-browser.sh
ExecStop=/bin/bash -c 'pkill -f "Xvfb :99"; pkill -f "x11vnc.*:99"; pkill -f "websockify.*6080"; pkill -f "tailnet-browser-profile"'
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

as_root cp /tmp/remote-browser.service /etc/systemd/system/remote-browser.service
rm -f /tmp/remote-browser.service

as_root systemctl daemon-reload
as_root systemctl enable --now remote-browser.service
systemctl is-active --quiet remote-browser.service || fail "remote-browser.service failed to start"

tailscale serve --bg --https=443 --set-path=/browser http://127.0.0.1:6080 >/dev/null

DNS_NAME="$(tailscale status --self --json 2>/dev/null | python3 -c 'import json,sys; print((json.load(sys.stdin).get("Self") or {}).get("DNSName", "").rstrip("."))' 2>/dev/null || true)"
if [[ -n "$DNS_NAME" ]]; then
  echo
  ok "Tailnet Browser ready"
  echo "Launch URL: https://${DNS_NAME}/browser/vnc_auto.html?path=browser/websockify&title=Tailnet%20Browser"
else
  ok "Tailnet Browser ready"
  echo "Launch URL: https://<this-device>.ts.net/browser/vnc_auto.html?path=browser/websockify&title=Tailnet%20Browser"
fi
