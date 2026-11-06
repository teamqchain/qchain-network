#!/bin/bash
# PQC network (new file, 2026-10-31): deploy QChaincode as a service (ccaas), as in the
# proven Docker network:
#   package (connection.json -> chaincode-qchaincode:9998, metadata type ccaas, label qchaincode_2.0);
#   install on both peers; start qchainpqc_chaincode-qchaincode (image qchain-pqc/ccaas-qchain:2.0, which
#   contains this chaincode/ code) with the package ID; approve for both orgs; commit; querycommitted.
# Definition: channel defaults (MAJORITY Endorsement), sequence ${CC_SEQUENCE:-1}, no init, no collections.
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/pqc-env.sh"
pqc_need "$PQC_PEER" "$DOCKER"
SEQ=${CC_SEQUENCE:-1}
PKG=$NETWORK_ROOT/chaincode-pkg
[ -e "$PKG/$CC_NAME.tar.gz" ] && pqc_die "$PKG/$CC_NAME.tar.gz already exists"
mkdir -p "$PKG"

echo "=== package $CC_LABEL (ccaas) ==="
printf '{"address":"chaincode-qchaincode:9998","dial_timeout":"10s","tls_required":false}\n' > "$PKG/connection.json"
printf '{"type":"ccaas","label":"%s"}\n' "$CC_LABEL" > "$PKG/metadata.json"
tar -C "$PKG" -czf "$PKG/code.tar.gz" connection.json
tar -C "$PKG" -czf "$PKG/$CC_NAME.tar.gz" metadata.json code.tar.gz
ID=$( . "$NETWORK_ROOT/scripts/env-gov.sh" > /dev/null; "$PQC_PEER" lifecycle chaincode calculatepackageid "$PKG/$CC_NAME.tar.gz" )
echo "  package ID $ID"

for org in gov gen; do
  echo "=== install on $org ==="
  ( . "$NETWORK_ROOT/scripts/env-$org.sh" > /dev/null; "$PQC_PEER" lifecycle chaincode install "$PKG/$CC_NAME.tar.gz" )
done

echo "=== start the chaincode service ==="
QCHAINCODE_PACKAGE_ID="$ID" "$DOCKER" compose -p "$COMPOSE_PROJECT" -f "$COMPOSE_MAIN" --profile chaincode up -d chaincode-qchaincode

ORD=(-o "$ORDERER_ADDRESS" --tls --cafile "$ORDERER_TLSCA")
for org in gov gen; do
  echo "=== approve for $org ==="
  ( . "$NETWORK_ROOT/scripts/env-$org.sh" > /dev/null
    "$PQC_PEER" lifecycle chaincode approveformyorg "${ORD[@]}" --channelID "$CHANNEL_NAME" --name "$CC_NAME" \
      --version "$CC_VERSION" --package-id "$ID" --sequence "$SEQ" )
done

( . "$NETWORK_ROOT/scripts/env-gov.sh" > /dev/null
  "$PQC_PEER" lifecycle chaincode checkcommitreadiness --channelID "$CHANNEL_NAME" --name "$CC_NAME" --version "$CC_VERSION" --sequence "$SEQ" --output json
  echo "=== commit ==="
  "$PQC_PEER" lifecycle chaincode commit "${ORD[@]}" --channelID "$CHANNEL_NAME" --name "$CC_NAME" --version "$CC_VERSION" --sequence "$SEQ" \
    --peerAddresses "$GOV_PEER_ADDRESS" --tlsRootCertFiles "$GOV_PEER_TLSROOT" \
    --peerAddresses "$GEN_PEER_ADDRESS" --tlsRootCertFiles "$GEN_PEER_TLSROOT"
  "$PQC_PEER" lifecycle chaincode querycommitted --channelID "$CHANNEL_NAME" --name "$CC_NAME" )
echo "Chaincode $CC_NAME $CC_VERSION committed on $CHANNEL_NAME."
