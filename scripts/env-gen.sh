#!/bin/bash
# PQC copy (qchain-network-pqc, 2026-10-31). Changes vs qchain-network (see CHANGES-PQC.md):
#   - sources pqc-env.sh; the PQC peer CLI is $PQC_PEER (explicit path), exported as PEER for convenience.
#   - FABRIC_CFG_PATH = crypto-material/cli-config/admin-general (core.yaml with BCCSP PQC and this
#     admin's own pqc-keystore, written by generate-crypto-pqc.sh).
#   - peer address port 29051 (PQC port map); ORDERER_ADDRESS exported.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export NETWORK_ROOT="${NETWORK_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
. "$SCRIPT_DIR/pqc-env.sh"
export PEER="$PQC_PEER"
export ORDERER_CA="${ORDERER_CA:-$NETWORK_ROOT/crypto-material/ordererOrganizations/orderer.example.com/orderers/orderer0.orderer.example.com/tls/ca.crt}"
export FABRIC_LOGGING_SPEC=ERROR
export FABRIC_CFG_PATH="$NETWORK_ROOT/crypto-material/cli-config/admin-general"
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID=GeneralMSP
export CORE_PEER_ADDRESS=$GEN_PEER_ADDRESS
export CORE_PEER_MSPCONFIGPATH="$NETWORK_ROOT/crypto-material/peerOrganizations/general.uae.com/users/Admin@general.uae.com/msp"
export CORE_PEER_TLS_ROOTCERT_FILE="$NETWORK_ROOT/crypto-material/peerOrganizations/general.uae.com/peers/peer0.general.uae.com/tls/ca.crt"
echo "Switched to General context — $GEN_PEER_ADDRESS (PQC peer CLI: \$PEER)"
