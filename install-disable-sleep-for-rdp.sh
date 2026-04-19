#!/usr/bin/env bash
# Install systemd drop-ins + mask sleep targets so the RDP host never suspends.
# Revert: sudo rm /etc/systemd/{sleep.conf.d,logind.conf.d}/rdp-no-sleep.conf
#         sudo systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target
#         sudo systemctl restart systemd-logind

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

sudo install -d /etc/systemd/sleep.conf.d /etc/systemd/logind.conf.d
sudo install -m 0644 "$ROOT/systemd/sleep.conf.d/rdp-no-sleep.conf" /etc/systemd/sleep.conf.d/rdp-no-sleep.conf
sudo install -m 0644 "$ROOT/systemd/logind.conf.d/rdp-no-sleep.conf" /etc/systemd/logind.conf.d/rdp-no-sleep.conf

sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
sudo systemctl daemon-reload
sudo systemctl restart systemd-logind

echo "Sleep disabled for RDP host. Verify: systemd-analyze cat-config systemd/sleep.conf"
