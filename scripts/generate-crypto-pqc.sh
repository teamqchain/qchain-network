#!/bin/bash
# PQC copy (new file, qchain-network-pqc 2026-10-31): generate all crypto material at run time (design b1).
#   1. PQC cryptogen (ML-DSA-44) -> crypto-material/ for orderer0, peer0 x2, the org admins and the
#      named control users issuer1@government.uae.com (role=issuer) and plain1@general.uae.com.
#   2. pqc-keystore/priv_sk copy next to every node/admin MSP (the BCCSP PQC key store; read-only use).
#   3. crypto-material/cli-config/<identity>/core.yaml for the host peer CLI (same core.yaml, own key store).
#   4. per-org PQC CA bootstrap (D7): the cryptogen org CA cert + key into fabric-ca/<org>/cafiles/.
#   5. per-org CA server TLS: ECDSA P-256 cert + key (openssl), SANs ca.<org>, localhost, 127.0.0.1
#      (a PQC CA refuses TLS without an external key file; classical by design, D4).
# Never overwrites existing material; never prints key contents. Remove with: teardown-pqc.sh purge-crypto
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/pqc-env.sh"
pqc_need "$PQC_CRYPTOGEN" "$OPENSSL"

[ -e "$CM" ] && pqc_die "$CM already exists (keys are never overwritten; purge first with scripts/teardown-pqc.sh purge-crypto)"
for o in government general; do
  for d in cafiles tls; do [ -e "$NETWORK_ROOT/fabric-ca/$o/$d" ] && pqc_die "fabric-ca/$o/$d already exists"; done
done

umask 077
echo "=== 1. cryptogen (ML-DSA-44) -> crypto-material/ ==="
"$PQC_CRYPTOGEN" generate --config="$NETWORK_ROOT/config/crypto-config.yaml" --output="$CM" > /dev/null

echo "=== 2. pqc-keystore copies ==="
ORD=$CM/ordererOrganizations/orderer.example.com
GOV=$CM/peerOrganizations/government.uae.com
GEN=$CM/peerOrganizations/general.uae.com
IDS="$ORD/orderers/orderer0.orderer.example.com $ORD/users/Admin@orderer.example.com
     $GOV/peers/peer0.government.uae.com $GOV/users/Admin@government.uae.com $GOV/users/issuer1@government.uae.com
     $GEN/peers/peer0.general.uae.com $GEN/users/Admin@general.uae.com $GEN/users/plain1@general.uae.com"
n=0
for d in $IDS; do
  [ -f "$d/msp/keystore/priv_sk" ] || pqc_die "no msp/keystore/priv_sk in ${d#$NETWORK_ROOT/}"
  mkdir -p "$d/pqc-keystore"
  cp -p "$d/msp/keystore/priv_sk" "$d/pqc-keystore/priv_sk"
  cmp -s "$d/msp/keystore/priv_sk" "$d/pqc-keystore/priv_sk" || pqc_die "key store copy differs: ${d#$NETWORK_ROOT/}"
  n=$((n + 1))
done
echo "  $n key store copies (identical to msp/keystore)"

echo "=== 3. host CLI configs ==="
mkcli() { # name identity-dir
  local c=$CM/cli-config/$1
  mkdir -p "$c/production"
  sed -e "s#^\(\s*KeyStorePath:\).*#\1 $2/pqc-keystore#" -e "s#^\(\s*fileSystemPath:\).*#\1 $c/production#" \
      "$NETWORK_ROOT/config/core.yaml" > "$c/core.yaml"
  [ "$(grep -c "KeyStorePath: $2/pqc-keystore" "$c/core.yaml")" = 1 ] || pqc_die "cli-config/$1: KeyStorePath not set exactly once"
}
mkcli admin-government "$GOV/users/Admin@government.uae.com"
mkcli admin-general    "$GEN/users/Admin@general.uae.com"
mkcli issuer1-government "$GOV/users/issuer1@government.uae.com"
mkcli plain1-general   "$GEN/users/plain1@general.uae.com"
echo "  cli-config: $(ls "$CM/cli-config" | tr '\n' ' ')"

echo "=== 4./5. PQC CA bootstrap (D7) and ECDSA CA server TLS ==="
for o in government general; do
  src=$CM/peerOrganizations/$o.uae.com/ca
  dst=$NETWORK_ROOT/fabric-ca/$o
  mkdir -p "$dst/cafiles" "$dst/tls"
  cp -p "$src/ca.$o.uae.com-cert.pem" "$dst/cafiles/ca.$o.uae.com-cert.pem"
  cp -p "$src/priv_sk" "$dst/cafiles/priv_sk"
  "$OPENSSL" req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 -sha256 -days 365 -noenc \
    -keyout "$dst/tls/tls-key.pem" -out "$dst/tls/tls-cert.pem" -subj "/CN=ca.$o.uae.com" \
    -addext "subjectAltName=DNS:ca.$o.uae.com,DNS:localhost,IP:127.0.0.1" \
    -addext "keyUsage=critical,digitalSignature" -addext "extendedKeyUsage=serverAuth" 2> /dev/null
  echo "  fabric-ca/$o: cafiles (cert + key from cryptogen), tls (ECDSA P-256, 365 days)"
done
echo "Done. Nothing was printed from any key file. Next: scripts/start-fabric-network.sh"
