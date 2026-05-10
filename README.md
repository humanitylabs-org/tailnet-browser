# Tailnet Browser

Dedicated noVNC browser app exposed at `/browser` on your Tailscale HTTPS host.

## What it sets up

- `remote-browser.service` (systemd)
- noVNC + Xvfb + Chromium bound to `127.0.0.1:6080`
- Tailscale path route:
  - `/browser` -> `http://127.0.0.1:6080`

## Usage

```bash
./scripts/prereq-check.sh
./scripts/setup.sh
./scripts/status.sh
```

Launch URL format:

```text
https://<this-device>.ts.net/browser/vnc_auto.html?path=browser/websockify&title=Tailnet%20Browser
```
