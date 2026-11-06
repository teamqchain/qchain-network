#!/bin/bash
# PQC copy (new file, qchain-network-pqc 2026-10-31): stop (not remove) the qchainpqc containers.
# Containers, volumes, ledgers and crypto material are kept; start again with start-fabric-network.sh.
# Removal is scripts/teardown-pqc.sh (qchainpqc_* only).
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/pqc-env.sh"
pqc_need "$DOCKER"
pqc_dockerup || pqc_die "docker daemon unreachable; nothing stopped"
"$DOCKER" compose -p "$COMPOSE_PROJECT" -f "$COMPOSE_MAIN" --profile chaincode --profile couchdb --profile ipfs stop
"$DOCKER" compose -p "$COMPOSE_PROJECT" -f "$COMPOSE_CA" stop
echo "=== qchainpqc containers stopped ==="
