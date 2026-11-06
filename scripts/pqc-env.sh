#!/bin/bash
# PQC network (new file, 2026-10-31): shared settings for every PQC script.
# Source it:  . "$(dirname "$0")/pqc-env.sh"
# Every Fabric/CA/PQC tool is called by the explicit path below, never from PATH. Override any of them
# with the environment variable of the same name before sourcing.
#
# PREREQUISITE (once per machine): install the tool wrappers, which run each CLI from the
# qchain-pqc/tools image, so the host needs no Fabric binaries:
#   bash qchain-network/scripts/qchain-pqc-cli.sh install ~/pqc-tools/bin

_PQC_SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export NETWORK_ROOT="${NETWORK_ROOT:-$(cd "$_PQC_SCRIPTS/.." && pwd)}"

# --- binaries (explicit paths) ---
export PQC_BIN="${PQC_BIN:-$HOME/pqc-tools/bin}"
export PQC_PEER="${PQC_PEER:-$PQC_BIN/peer}"
export PQC_OSNADMIN="${PQC_OSNADMIN:-$PQC_BIN/osnadmin}"
export PQC_FCC="${PQC_FCC:-$PQC_BIN/fabric-ca-client}"
export PQC_CRYPTOGEN="${PQC_CRYPTOGEN:-$PQC_BIN/cryptogen}"
export PQC_CONFIGTXGEN="${PQC_CONFIGTXGEN:-$PQC_BIN/configtxgen}"
export MKWALLET="${MKWALLET:-$PQC_BIN/mkwallet-g1}"   # offchain/cmd/mkwallet
export OPENSSL="${OPENSSL:-/usr/bin/openssl}"       # ECDSA CA server TLS certs, random user secrets
export DOCKER="${DOCKER:-/usr/bin/docker}"

# --- compose: project qchainpqc, every object prefixed qchainpqc_ ---
export COMPOSE_PROJECT="qchainpqc"
export COMPOSE_IGNORE_ORPHANS=True   # the CA and node services live in two files of the same project
export COMPOSE_MAIN="$NETWORK_ROOT/docker/docker-compose.yaml"
export COMPOSE_CA="$NETWORK_ROOT/docker/docker-compose-ca.yaml"

# --- channel / chaincode ---
export CHANNEL_NAME="${CHANNEL_NAME:-mychannel}"
export CC_NAME="qchaincode" CC_VERSION="2.0" CC_LABEL="qchaincode_2.0"

# --- endpoints (container port = host port; host names resolve to 127.0.0.1 via /etc/hosts) ---
export ORDERER_ADDRESS="orderer0.orderer.example.com:27050"
export ORDERER_ADMIN_ADDRESS="orderer0.orderer.example.com:27053"
export GOV_PEER_ADDRESS="peer0.government.uae.com:27051"
export GEN_PEER_ADDRESS="peer0.general.uae.com:29051"
# The CA server TLS certs carry SANs ca.<org>, localhost, 127.0.0.1; the host reaches them via localhost.
export GOV_CA_URL="https://localhost:27054" GOV_CA_NAME="GovernmentCA"
export GEN_CA_URL="https://localhost:28054" GEN_CA_NAME="GeneralCA"

# --- crypto-material layout (written at run time by generate-crypto-pqc.sh; never copied) ---
export CM="$NETWORK_ROOT/crypto-material"
export ORDERER_TLSCA="$CM/ordererOrganizations/orderer.example.com/tlsca/tlsca.orderer.example.com-cert.pem"
export GOV_PEER_TLSROOT="$CM/peerOrganizations/government.uae.com/peers/peer0.government.uae.com/tls/ca.crt"
export GEN_PEER_TLSROOT="$CM/peerOrganizations/general.uae.com/peers/peer0.general.uae.com/tls/ca.crt"
export GOV_CA_TLS="$NETWORK_ROOT/fabric-ca/government/tls/tls-cert.pem"   # ECDSA CA server TLS cert
export GEN_CA_TLS="$NETWORK_ROOT/fabric-ca/general/tls/tls-cert.pem"

pqc_die() { echo "ERROR: $*" >&2; exit 1; }
# pqc_need <binary>...: every binary must exist and be executable
pqc_need() {
  local b
  for b in "$@"; do
    [ -x "$b" ] || pqc_die "missing binary $b (see the PREREQUISITE note in scripts/pqc-env.sh)"
  done
}
# pqc_dockerup: the daemon answers within ~10 s (3 attempts)
pqc_dockerup() { local i; for i in 1 2 3; do timeout 20 "$DOCKER" info > /dev/null 2>&1 && return 0; [ $i -lt 3 ] && sleep 5; done; return 1; }
