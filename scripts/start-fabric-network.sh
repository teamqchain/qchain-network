#!/usr/bin/env bash
# PQC copy (qchain-network-pqc, 2026-10-31). Changes vs qchain-network (see CHANGES-PQC.md):
#   - compose project qchainpqc (-p), docker by explicit path; COMPOSE_IGNORE_ORPHANS because the CA and
#     node services live in two files of the same project (never use --remove-orphans here).
#   - 2 PQC CA servers (ca.orderer dropped), orderer, 2 peers; state DB goleveldb (CouchDB only with the
#     optional "couchdb" profile, see README-PQC.md); the chaincode service is started by deployCC-pqc.sh.
#   - refuses to start before scripts/generate-crypto-pqc.sh has written the crypto material (otherwise
#     Docker would create empty root-owned bind-mount directories).
#
# Brings up the QChain PQC Fabric network (2 CA servers, orderer, 2 peers) in the correct order. Safe to
# re-run — docker compose just (re)starts already-existing containers if nothing changed.
#
# Deliberately does NOT touch the optional `ipfs` service (compose profile "ipfs"): the systemd IPFS
# daemon is the one actually in use. The source's stale `qchain-server` service is not in the PQC copy.
#
# Can be called at boot by the qchainpqc-fabric.service systemd unit (setup-fabric-autostart.sh).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/pqc-env.sh"
pqc_need "$DOCKER"
[ -d "$CM" ] && [ -f "$NETWORK_ROOT/fabric-ca/government/cafiles/priv_sk" ] && [ -f "$NETWORK_ROOT/fabric-ca/general/cafiles/priv_sk" ] \
  || pqc_die "crypto material missing: run scripts/generate-crypto-pqc.sh first"

echo "=== Starting QChain PQC Fabric CA servers ==="
"$DOCKER" compose -p "$COMPOSE_PROJECT" -f "$COMPOSE_CA" up -d

echo "=== Starting QChain PQC Fabric network (orderer, peers) ==="
"$DOCKER" compose -p "$COMPOSE_PROJECT" -f "$COMPOSE_MAIN" up -d \
    orderer0.orderer.example.com \
    peer0.government.uae.com \
    peer0.general.uae.com

echo "=== QChain PQC Fabric network started ==="
