#!/usr/bin/env bash
set -euo pipefail

echo "remote-browser.service"
systemctl is-active remote-browser.service
systemctl is-enabled remote-browser.service
systemctl show remote-browser.service -p Restart -p RestartUSec -p ActiveState -p SubState

echo

echo "tailscale route"
tailscale serve status | sed -n '1,80p'
