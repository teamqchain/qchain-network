#!/bin/bash
# PQC copy (qchain-network-pqc, 2026-10-31). Changes vs qchain-network (see CHANGES-PQC.md):
#   - sources pqc-env.sh; the PQC peer CLI is $PQC_PEER (explicit path), exported as PEER for convenience.
#   - FABRIC_CFG_PATH = crypto-material/cli-config/admin-government (core.yaml with BCCSP PQC and this
#     admin's own pqc-keystore, written by generate-crypto-pqc.sh).
#   - peer address port 27051 (PQC port map); ORDERER_ADDRESS exported.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export NETWORK_ROOT="${NETWORK_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
. "$SCRIPT_DIR/pqc-env.sh"
export PEER="$PQC_PEER"
export ORDERER_CA="${ORDERER_CA:-$NETWORK_ROOT/crypto-material/ordererOrganizations/orderer.example.com/orderers/orderer0.orderer.example.com/tls/ca.crt}"
export FABRIC_LOGGING_SPEC=ERROR
export FABRIC_CFG_PATH="$NETWORK_ROOT/crypto-material/cli-config/admin-government"
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID=GovernmentMSP
export CORE_PEER_ADDRESS=$GOV_PEER_ADDRESS
export CORE_PEER_MSPCONFIGPATH="$NETWORK_ROOT/crypto-material/peerOrganizations/government.uae.com/users/Admin@government.uae.com/msp"
export CORE_PEER_TLS_ROOTCERT_FILE="$NETWORK_ROOT/crypto-material/peerOrganizations/government.uae.com/peers/peer0.government.uae.com/tls/ca.crt"
echo "Switched to Government context — $GOV_PEER_ADDRESS (PQC peer CLI: \$PEER)"
