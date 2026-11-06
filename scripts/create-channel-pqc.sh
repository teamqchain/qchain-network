#!/bin/bash
# PQC network (new file, 2026-10-31): create the application channel (channel
# participation, no system channel) and join both peers.
#   configtxgen (pqc) -> channel-artifacts/mychannel.block (profile TwoOrgsChannel: Channel V3_0, anchor
#   peers included); osnadmin join on orderer0 (Admin@orderer TLS client cert); peer channel join as each
#   org admin; heights on both peers.
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/pqc-env.sh"
pqc_need "$PQC_CONFIGTXGEN" "$PQC_OSNADMIN" "$PQC_PEER"
[ -d "$CM" ] || pqc_die "no crypto-material/ (run scripts/generate-crypto-pqc.sh first)"

BLOCK=$NETWORK_ROOT/channel-artifacts/$CHANNEL_NAME.block
[ -e "$BLOCK" ] && pqc_die "$BLOCK already exists"

echo "=== genesis block ($CHANNEL_NAME) ==="
FABRIC_CFG_PATH="$NETWORK_ROOT/config" "$PQC_CONFIGTXGEN" -profile TwoOrgsChannel -outputBlock "$BLOCK" -channelID "$CHANNEL_NAME"

echo "=== orderer0 joins $CHANNEL_NAME ==="
OA=$CM/ordererOrganizations/orderer.example.com/users/Admin@orderer.example.com/tls
"$PQC_OSNADMIN" channel join --channelID "$CHANNEL_NAME" --config-block "$BLOCK" -o "$ORDERER_ADMIN_ADDRESS" \
  --ca-file "$ORDERER_TLSCA" --client-cert "$OA/client.crt" --client-key "$OA/client.key"
"$PQC_OSNADMIN" channel list -o "$ORDERER_ADMIN_ADDRESS" \
  --ca-file "$ORDERER_TLSCA" --client-cert "$OA/client.crt" --client-key "$OA/client.key"

for org in gov gen; do
  echo "=== peer of $org joins $CHANNEL_NAME ==="
  ( . "$NETWORK_ROOT/scripts/env-$org.sh" > /dev/null; "$PQC_PEER" channel join -b "$BLOCK" )
done
sleep 3
for org in gov gen; do
  ( . "$NETWORK_ROOT/scripts/env-$org.sh" > /dev/null; echo "  $org: $("$PQC_PEER" channel getinfo -c "$CHANNEL_NAME" 2>&1 | grep -o '"height":[0-9]*')" )
done
echo "Channel $CHANNEL_NAME ready (anchor peers are in the genesis block). Next: scripts/deployCC-pqc.sh"
