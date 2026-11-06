#!/bin/bash
# PQC copy (new file, qchain-network-pqc 2026-10-31): PQC replacement for scripts/registerUser.js.
# Usage: scripts/registerUser-pqc.sh <firstName> <lastName> <Government|General> <issuer|verifier>
# Same result as registerUser.js: user <firstName><lastName>, type client, affiliation <org>.<role>,
# ecert attributes firstName/lastName/role, wallet/<org>/<user>.id; but with the PQC fabric-ca-client
# (ML-DSA-44 key; the Node SDK can only make ECDSA keys) and mkwallet-g1 for the wallet.
# Needs the org's CA admin enrolled by scripts/registerEnroll.sh. The enrollment secret is random and
# never printed or stored.
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/pqc-env.sh"
pqc_need "$PQC_FCC" "$MKWALLET" "$OPENSSL"
[ $# = 4 ] || pqc_die "usage: $0 <firstName> <lastName> <Government|General> <issuer|verifier>"
F=$1; L=$2; ORG=$3; ROLE=$4; U="$F$L"
case $ORG in
  Government) o=government; URL=$GOV_CA_URL; CAN=$GOV_CA_NAME; TLS=$GOV_CA_TLS;;
  General)    o=general;    URL=$GEN_CA_URL; CAN=$GEN_CA_NAME; TLS=$GEN_CA_TLS;;
  *) pqc_die "org must be Government or General";;
esac
case $ROLE in issuer|verifier) ;; *) pqc_die "role must be issuer or verifier";; esac
MSPID=${ORG}MSP
ADMIN_HOME=$CM/peerOrganizations/$o.uae.com/ca-admin
WALLET=$NETWORK_ROOT/wallet/$o/$U.id
[ -f "$ADMIN_HOME/msp/signcerts/cert.pem" ] || pqc_die "CA admin of $ORG not enrolled (run scripts/registerEnroll.sh)"
[ -e "$WALLET" ] && { echo "An identity for the user \"$U\" already exists in the wallet"; exit 0; }

umask 077
HOME_U=$CM/peerOrganizations/$o.uae.com/users/$U@$o.uae.com
mkdir -p "$HOME_U"
. "$NETWORK_ROOT/scripts/registerEnroll.sh" --functions-only   # client_cfg, nodeous
client_cfg "$HOME_U" "$URL" "$TLS"
SEC=$("$OPENSSL" rand -hex 16)
"$PQC_FCC" register -H "$ADMIN_HOME" -u "$URL" --caname "$CAN" --tls.certfiles "$TLS" \
  --id.name "$U" --id.secret "$SEC" --id.type client --id.affiliation "$o.$ROLE" \
  --id.attrs "firstName=$F:ecert,lastName=$L:ecert,role=$ROLE:ecert" > /dev/null
"$PQC_FCC" enroll -H "$HOME_U" -u "https://$U:$SEC@${URL#https://}" --caname "$CAN" --tls.certfiles "$TLS" > /dev/null
unset SEC
nodeous "$HOME_U/msp"
mkdir -p "$(dirname "$WALLET")"
"$MKWALLET" "$HOME_U/msp" "$MSPID" "$WALLET"
echo "Successfully registered and enrolled user \"$U\" and imported it into the wallet"
