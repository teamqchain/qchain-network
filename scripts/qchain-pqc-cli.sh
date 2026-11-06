#!/usr/bin/env bash
# qchain-pqc-cli.sh: run the PQC Fabric CLIs from the qchain-pqc/tools image instead of host
# binaries (for hosts whose OpenSSL is < 3.3, e.g. Ubuntu 24.04).
#
# Install once (creates <dir>/peer, osnadmin, fabric-ca-client, cryptogen, configtxgen, mkwallet-g1
# as symlinks to this script):
#   bash qchain-pqc-cli.sh install ~/pqc-tools/bin
# Then point the network scripts at it:
#   export PQC_BIN=~/pqc-tools/bin MKWALLET=~/pqc-tools/bin/mkwallet-g1
#
# Each call runs `docker run --rm` with:
#   - the CLI's own name as the command, all arguments passed through unchanged;
#   - --network host (QCHAIN_TOOLS_NETWORK overrides it; Docker Desktop's host network is its VM,
#     so locally use qchainpqc_net, where the node aliases and ports match the host addresses);
#   - your uid:gid, so generated files are owned by you;
#   - NETWORK_ROOT (default ~/qchain-network-pqc), the current directory and QCHAIN_TOOLS_MOUNTS
#     (colon-separated) bind-mounted at the same paths, so absolute paths in arguments and in
#     FABRIC_CFG_PATH / CORE_PEER_* / FABRIC_CA_CLIENT_HOME work as on the host;
#   - every CORE_*, ORDERER_*, FABRIC_*, OSNADMIN_* variable of the caller.
set -euo pipefail

TOOLS="peer osnadmin fabric-ca-client cryptogen configtxgen mkwallet-g1"
IMAGE="${QCHAIN_TOOLS_IMAGE:-qchain-pqc/tools:20261105}"
DOCKER="${DOCKER:-docker}"

self=$(readlink -f "${BASH_SOURCE[0]}")
name=$(basename "$0")

if [ "$name" = "$(basename "$self")" ]; then
  case "${1:-}" in
    install)
      dir=${2:?usage: $0 install <dir>}
      mkdir -p "$dir"
      for t in $TOOLS; do ln -sfn "$self" "$dir/$t"; done
      echo "installed: $(cd "$dir" && ls | tr '\n' ' ')-> $self"
      echo "export PQC_BIN=$(cd "$dir" && pwd) MKWALLET=$(cd "$dir" && pwd)/mkwallet-g1"
      exit 0;;
    run) shift; name=${1:?usage: $0 run <tool> [args...]}; shift;;
    *) echo "usage: $0 install <dir> | run <tool> [args...]  (or call through an installed symlink)" >&2; exit 2;;
  esac
fi
case " $TOOLS " in *" $name "*) ;; *) echo "qchain-pqc-cli: unknown tool $name" >&2; exit 2;; esac

root="${NETWORK_ROOT:-$HOME/qchain-network-pqc}"
mounts=("$root" "$PWD")
IFS=: read -r -a extra <<< "${QCHAIN_TOOLS_MOUNTS:-}"
mounts+=("${extra[@]}")

args=(run --rm -i --network "${QCHAIN_TOOLS_NETWORK:-host}" --user "$(id -u):$(id -g)" -w "$PWD")
seen=" "
for m in "${mounts[@]}"; do
  [ -n "$m" ] && [ -d "$m" ] || continue
  m=$(cd "$m" && pwd)
  case "$seen" in *" $m "*) continue;; esac
  seen="$seen$m "
  args+=(-v "$m:$m")
done
while IFS= read -r v; do args+=(-e "$v"); done < <(compgen -e | grep -E '^(CORE_|ORDERER_|FABRIC_|OSNADMIN_)' || true)

exec "$DOCKER" "${args[@]}" "$IMAGE" "/usr/local/bin/$name" "$@"
