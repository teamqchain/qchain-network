#!/bin/bash
# PQC network (2026-10-31): scripts/registerEnroll.sh, same name, PQC flow (design b1).
# Changes from the classical network, tag classical-network-final (see CHANGES-PQC.md):
#   - PQC fabric-ca-client by explicit path ($PQC_FCC from scripts/pqc-env.sh); the source's
#     `export PATH=$PATH:~/fabric/build/bin` (stale pre-fix binaries) is gone.
#   - Clients trust the CA's ECDSA server TLS cert (fabric-ca/<org>/tls/tls-cert.pem) via --tls.certfiles,
#     not ca-cert.pem; every client home gets a fabric-ca-client-config.yaml with bccsp.default PQC and
#     csr.keyrequest.algo mldsa44 (ML-DSA-44 keys).
#   - Node, admin and orderer material is NOT enrolled here any more: it comes from the PQC cryptogen
#     (scripts/generate-crypto-pqc.sh, design b1). The orderer CA is dropped.
#   - The CA admin homes are crypto-material/peerOrganizations/<org>/ca-admin (the org msp/ is the
#     channel MSP written by cryptogen and must not be touched).
#   - issuer1 / verifier1 at GeneralCA: same registration (role=issuer:ecert / role=verifier:ecert,
#     --enrollment.attrs role) and enrollment as the source.
#   - Wallets built with mkwallet-g1 (offchain/cmd/mkwallet: picks the key that matches the cert), not with sed.
# Run after scripts/generate-crypto-pqc.sh and scripts/start-fabric-network.sh (CAs up).
set -e

NETWORK_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
. "$NETWORK_ROOT/scripts/pqc-env.sh"

# client_cfg <home> <url> <ca tls cert>: PQC client config (doc: docs/source/pqc-mldsa.md in the Fabric CA fork)
client_cfg() {
  mkdir -p "$1"
  cat > "$1/fabric-ca-client-config.yaml" <<EOF
url: $2

tls:
  certfiles:
    - $3

csr:
  keyrequest:
    algo: mldsa44

bccsp:
  default: PQC
EOF
}

# nodeous <msp dir>: NodeOUs config.yaml pointing at the CA cert the client stored in cacerts/
nodeous() {
  local c; c=$(cd "$1/cacerts" && ls *.pem | head -1)
  cat > "$1/config.yaml" <<EOF
NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/$c
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/$c
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/$c
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/$c
    OrganizationalUnitIdentifier: orderer
EOF
}

# registerUser-pqc.sh sources this file for the two helpers only
[ "${1:-}" = --functions-only ] && return 0

pqc_need "$PQC_FCC" "$MKWALLET"
[ -d "$CM" ] || pqc_die "no crypto-material/ (run scripts/generate-crypto-pqc.sh first)"
umask 077

echo "========== Government =========="

echo "========== Enrolling Government CA Admin =========="
export FABRIC_CA_CLIENT_HOME=$CM/peerOrganizations/government.uae.com/ca-admin
client_cfg "$FABRIC_CA_CLIENT_HOME" "$GOV_CA_URL" "$GOV_CA_TLS"

"$PQC_FCC" enroll \
  -u https://admin:adminpw@${GOV_CA_URL#https://} \
  --caname GovernmentCA \
  --tls.certfiles "$GOV_CA_TLS"

nodeous "$FABRIC_CA_CLIENT_HOME/msp"

echo "========== General =========="

echo "========== Enrolling General CA Admin =========="
export FABRIC_CA_CLIENT_HOME=$CM/peerOrganizations/general.uae.com/ca-admin
client_cfg "$FABRIC_CA_CLIENT_HOME" "$GEN_CA_URL" "$GEN_CA_TLS"

"$PQC_FCC" enroll \
  -u https://admin:adminpw@${GEN_CA_URL#https://} \
  --caname GeneralCA \
  --tls.certfiles "$GEN_CA_TLS"

nodeous "$FABRIC_CA_CLIENT_HOME/msp"

echo "========== Registering and Enrolling General Issuer1 User =========="
export FABRIC_CA_CLIENT_HOME=$CM/peerOrganizations/general.uae.com/ca-admin

"$PQC_FCC" register \
  --caname GeneralCA \
  --id.name issuer1 \
  --id.secret issuer1pw \
  --id.type client \
  --id.attrs 'role=issuer:ecert' \
  --tls.certfiles "$GEN_CA_TLS" || true

export FABRIC_CA_CLIENT_HOME=$CM/peerOrganizations/general.uae.com/users/issuer1@general.uae.com
client_cfg "$FABRIC_CA_CLIENT_HOME" "$GEN_CA_URL" "$GEN_CA_TLS"

"$PQC_FCC" enroll \
  -u https://issuer1:issuer1pw@${GEN_CA_URL#https://} \
  --caname GeneralCA \
  --enrollment.attrs "role" \
  --tls.certfiles "$GEN_CA_TLS"

nodeous "$FABRIC_CA_CLIENT_HOME/msp"

echo "========== Registering and Enrolling General Verifier1 User =========="
export FABRIC_CA_CLIENT_HOME=$CM/peerOrganizations/general.uae.com/ca-admin

"$PQC_FCC" register \
  --caname GeneralCA \
  --id.name verifier1 \
  --id.secret verifier1pw \
  --id.type client \
  --id.attrs 'role=verifier:ecert' \
  --tls.certfiles "$GEN_CA_TLS" || true

export FABRIC_CA_CLIENT_HOME=$CM/peerOrganizations/general.uae.com/users/verifier1@general.uae.com
client_cfg "$FABRIC_CA_CLIENT_HOME" "$GEN_CA_URL" "$GEN_CA_TLS"

"$PQC_FCC" enroll \
  -u https://verifier1:verifier1pw@${GEN_CA_URL#https://} \
  --caname GeneralCA \
  --enrollment.attrs "role" \
  --tls.certfiles "$GEN_CA_TLS"

nodeous "$FABRIC_CA_CLIENT_HOME/msp"

echo "========== Generating Fabric Gateway Wallet Identities (mkwallet-g1) =========="
mkdir -p "$NETWORK_ROOT/wallet/general" "$NETWORK_ROOT/wallet/government"

"$MKWALLET" "$CM/peerOrganizations/general.uae.com/users/issuer1@general.uae.com/msp" GeneralMSP "$NETWORK_ROOT/wallet/general/issuer1.id"
"$MKWALLET" "$CM/peerOrganizations/general.uae.com/users/verifier1@general.uae.com/msp" GeneralMSP "$NETWORK_ROOT/wallet/general/verifier1.id"
"$MKWALLET" "$CM/peerOrganizations/government.uae.com/users/Admin@government.uae.com/msp" GovernmentMSP "$NETWORK_ROOT/wallet/government/admin.id"

echo "Enrollment complete. crypto-material/ and wallet/ are ready."
