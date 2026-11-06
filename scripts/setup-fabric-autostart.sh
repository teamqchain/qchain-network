#!/usr/bin/env bash
# PQC copy (qchain-network-pqc, 2026-10-31). Changes vs qchain-network (see CHANGES-PQC.md):
#   - unit qchainpqc-fabric.service (the source's qchain-fabric.service is left alone);
#   - paths point at this directory (the copy is a sibling of qchain-network, not inside the QChain repo).
#
# One-time setup: installs a systemd service that brings the QChain PQC Fabric
# network (CA servers + orderer + peers) back up automatically whenever this
# machine boots. Run this ONCE per machine, with sudo.
#
# It wraps start-fabric-network.sh (which does the actual, correctly-ordered
# `docker compose up -d` calls) in a systemd unit, so we get the same
# ordering guarantees as running it by hand — unlike a bare
# `restart: unless-stopped` on each container, which restarts them
# independently with no ordering guarantee.
#
# Usage:
#   sudo bash qchain-network-pqc/scripts/setup-fabric-autostart.sh

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: run this with sudo (it installs a systemd unit)." >&2
    echo "  sudo bash qchain-network-pqc/scripts/setup-fabric-autostart.sh" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NETWORK_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RUN_AS_USER="${SUDO_USER:-$(logname)}"
UNIT_PATH="/etc/systemd/system/qchainpqc-fabric.service"

echo "=== Installing $UNIT_PATH ==="
echo "    Runs as user : $RUN_AS_USER"
echo "    Network dir  : $NETWORK_DIR"

cat > "$UNIT_PATH" <<EOF
[Unit]
Description=QChain PQC Hyperledger Fabric network (CA servers + orderer + peers)
After=docker.service network-online.target
Requires=docker.service
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
User=$RUN_AS_USER
WorkingDirectory=$NETWORK_DIR/docker
ExecStart=/usr/bin/bash $NETWORK_DIR/scripts/start-fabric-network.sh

[Install]
WantedBy=multi-user.target
EOF

echo "=== Reloading systemd + enabling the service ==="
systemctl daemon-reload
systemctl enable qchainpqc-fabric.service

echo ""
echo "=== Done ==="
echo "The PQC Fabric network will now start automatically on every future boot, as user '$RUN_AS_USER'."
echo ""
echo "Test it right now WITHOUT rebooting:"
echo "    sudo systemctl start qchainpqc-fabric.service"
echo "    systemctl status qchainpqc-fabric.service --no-pager"
echo ""
echo "View its boot-time logs any time with:"
echo "    journalctl -u qchainpqc-fabric.service --no-pager"
