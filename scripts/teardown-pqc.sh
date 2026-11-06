#!/bin/bash
# PQC copy (new file, qchain-network-pqc 2026-10-31): teardown of the qchainpqc network. Two separate actions:
#
#   teardown-pqc.sh [--yes]
#       Remove the qchainpqc_* containers, volumes and network ONLY (names must start with qchainpqc_).
#       Without --yes it only lists what it would remove. Images are kept. Never runs docker prune.
#
#   teardown-pqc.sh purge-crypto [--yes-delete-keys]
#       Separate, explicit key deletion: crypto-material/, wallet/, chaincode-pkg/, channel-artifacts/*.block
#       and the CA runtime files in fabric-ca/<org>/ (cafiles/, tls/, msp/, db, Issuer*, ca-cert.pem);
#       the fabric-ca-server-config.yaml files stay. Refuses while any qchainpqc_ container exists.
#       Without --yes-delete-keys it only lists the paths (names, never contents).
#
# Safety: if the docker daemon is unreachable (3 attempts over ~10 s) or a signal arrives, it HOLDs: it stops,
# deletes nothing further and reports what was removed so far. No deletion ever happens in a trap.
set -uo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/pqc-env.sh"
pqc_need "$DOCKER"
LOG=$NETWORK_ROOT/teardown-pqc.log
REMOVED=0
hold() { echo "HOLD: $* - nothing further removed; removed so far: $REMOVED (log: $LOG)"; exit 2; }
trap 'hold "signal received"' HUP INT TERM
logrm() { echo "$(date '+%F %T') removed $1" >> "$LOG"; REMOVED=$((REMOVED + 1)); }

pqc_dockerup || hold "docker daemon unreachable"
MODE=${1:-objects}

if [ "$MODE" = purge-crypto ]; then
  left=$("$DOCKER" ps -aq --filter name='^qchainpqc_' | wc -l)
  [ "$left" = 0 ] || pqc_die "$left qchainpqc_ container(s) still exist; run teardown-pqc.sh --yes first"
  P=()
  for p in "$CM" "$NETWORK_ROOT/wallet" "$NETWORK_ROOT/chaincode-pkg"; do [ -e "$p" ] && P+=("$p"); done
  for p in "$NETWORK_ROOT"/channel-artifacts/*.block; do [ -e "$p" ] && P+=("$p"); done
  for o in government general; do
    for n in cafiles tls msp fabric-ca-server.db IssuerPublicKey IssuerRevocationPublicKey ca-cert.pem ca-chain.pem; do
      [ -e "$NETWORK_ROOT/fabric-ca/$o/$n" ] && P+=("$NETWORK_ROOT/fabric-ca/$o/$n"); done
  done
  echo "purge-crypto would delete (${#P[@]} paths):"; for p in "${P[@]}"; do echo "  ${p#$NETWORK_ROOT/}"; done
  [ "${2:-}" = --yes-delete-keys ] || { echo "(list only; add --yes-delete-keys to delete)"; exit 0; }
  for p in "${P[@]}"; do
    case "$p" in "$NETWORK_ROOT"/*) ;; *) hold "refusing path outside the network dir: $p";; esac
    rm -rf -- "$p" && logrm "${p#$NETWORK_ROOT/}" || hold "rm failed: $p"
  done
  echo "purge-crypto done: $REMOVED paths removed"; exit 0
fi

[ "$MODE" = objects ] || [ "$MODE" = --yes ] || pqc_die "unknown action $MODE"
C=$("$DOCKER" ps -a --filter name='^qchainpqc_' --format '{{.Names}}' | grep '^qchainpqc_' || true)
V=$("$DOCKER" volume ls -q --filter name='^qchainpqc_' | grep '^qchainpqc_' || true)
N=$("$DOCKER" network ls --filter name='^qchainpqc_' --format '{{.Name}}' | grep '^qchainpqc_' || true)
echo "containers: ${C:-none}" | tr '\n' ' '; echo; echo "volumes: ${V:-none}" | tr '\n' ' '; echo; echo "networks: ${N:-none}"
[ "$MODE" = --yes ] || { echo "(list only; add --yes to remove these qchainpqc_ objects)"; exit 0; }
for c in $C; do case $c in qchainpqc_*) ;; *) hold "refusing $c";; esac
  "$DOCKER" stop -t 10 "$c" > /dev/null && "$DOCKER" rm "$c" > /dev/null && logrm "container $c" || hold "removing $c failed"; done
for v in $V; do case $v in qchainpqc_*) ;; *) hold "refusing $v";; esac
  "$DOCKER" volume rm "$v" > /dev/null && logrm "volume $v" || hold "removing $v failed"; done
for n in $N; do case $n in qchainpqc_*) ;; *) hold "refusing $n";; esac
  "$DOCKER" network rm "$n" > /dev/null && logrm "network $n" || hold "removing $n failed"; done
echo "teardown done: $REMOVED objects removed; qchainpqc_ left: $("$DOCKER" ps -aq --filter name='^qchainpqc_' | wc -l)/$("$DOCKER" volume ls -q --filter name='^qchainpqc_' | wc -l)/$("$DOCKER" network ls -q --filter name='^qchainpqc_' | wc -l)"
echo "crypto material kept; delete it separately with: scripts/teardown-pqc.sh purge-crypto --yes-delete-keys"
