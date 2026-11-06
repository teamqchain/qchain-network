# CHANGES-PQC.md

The differences between `~/qchain-network` (source, unchanged) and this PQC copy, created 2026-10-31.
The approved plan is in `~/qchain-network-pqc.PLAN.md`. Every edited script and YAML file also carries a short header comment. JSON files can't hold comments, so their changes are listed only here.

Design decisions in force:

1. **b1:** cryptogen ML-DSA-44 material for nodes and admins. The per-org PQC fabric-ca is bootstrapped with the cryptogen CA cert+key (D7) and issues the application identities.
2. **Ports:** 2xxxx with container port = host port, bound to 127.0.0.1 only; operations ports are 3xxxx and not published.
3. **State DB:** goleveldb; CouchDB is optional.
4. **cryptogen users:** Count 0, plus the named users issuer1@government (role=issuer) and plain1@general.
5. **Services:** qchain-server dropped; ipfs behind a profile.
6. **JS scripts:** kept with a "not usable" header.
7. **registerEnroll.sh:** edited in place.
8. **Binaries:** cryptogen/configtxgen are taken from `$PQC_BIN` (default `~/pqc-scratch/docker/bin`), never from `~/qchain-native/bin`.
9. **Orderer CA:** `ca.orderer` dropped.
10. **Chaincode:** `qchaincode` / `qchaincode_2.0`.

## Edited files

| File | What changed | Why |
|---|---|---|
| `.gitignore` | added the PQC runtime paths (crypto-material/, pqc-keystore/, *.id, *_sk, fabric-ca/*/{cafiles,tls,msp,ca-cert.pem,ca-chain.pem}, chaincode-pkg/, teardown-pqc.log) | keys and wallets are generated at run time and must never be committed |
| `config/configtx.yaml` | Channel capability V2_0 → **V3_0**. Global `Orderer.Addresses` removed and `OrdererEndpoints: orderer0.orderer.example.com:27050` added on OrdererOrg. Consenter port 27050. Anchor ports 27051/29051. `Consortium` line removed | ML-DSA identities need the V3_0 MSP (proven genesis: Channel V3_0, Orderer V2_0, Application V2_5). configtxgen at fabric e472b4ea refuses global orderer endpoints with V3_0 (`encoder.go:189`) and requires org endpoints (`:338`). New port map. Channel-participation genesis has no consortium. Policies and endorsement unchanged |
| `config/core.yaml` | `peer.BCCSP.Default` SW → PQC; added `PQC.KeyStorePath: /etc/hyperledger/fabric/pqc-keystore`. `vm.endpoint` unset. `chaincode.nodeenv.image` cleared. `externalBuilders` path → `/opt/ccaas` | PQC provider as in the proven nodes. Chaincode runs as a service (ccaas); there are no Docker builds and no stock images. The ccaas builder is baked into `qchain-pqc/peer`. The other `$(DOCKER_NS)/fabric-*` defaults are inert without a Docker VM |
| `config/orderer.yaml` | `General.BCCSP.Default` SW → PQC; added `PQC.KeyStorePath: /var/hyperledger/orderer/pqc-keystore` | PQC provider as in the proven orderer |
| `config/crypto-config.yaml` | `PublicKeyAlgorithm: mldsa44` for every CA, node and user. Users Count 2 → 0, plus `Specs`: issuer1 (Government, `Attrs: role: issuer`) and plain1 (General). Misleading "peer0 and peer1" comment fixed | input for the PQC cryptogen (b1), same shape as the proven test networks; application users come from fabric-ca |
| `connection/connection-gov.example.json` | peer url port 7051 → 27051; tlsCACerts path `../qchain-network/` → `../qchain-network-pqc/`; CA url → `https://localhost:27054`; CA tlsCACerts hint → `fabric-ca/government/tls/tls-cert.pem` (ECDSA server TLS cert, not ca-cert.pem) | port map; the CA server TLS is external ECDSA (D4); the CA host names are not in /etc/hosts, and the TLS cert has a `localhost` SAN. `httpOptions.verify:false` kept as in the source (flagged in README) |
| `connection/connection-gen.example.json` | same, with 29051 / 28054 / `fabric-ca/general/tls/tls-cert.pem` | same |
| `docker/docker-compose.yaml` | full PQC rewrite. Project `name: qchainpqc`; network `qchainpqc_net`; volumes `qchainpqc_*-data`; containers `qchainpqc_<fqdn>`. Images `qchain-pqc/orderer:e472b4ea` and `qchain-pqc/peer:e472b4ea`. Ports 127.0.0.1 only, container = host (27050, 27053, 27051, 29051). Operations 38443/39444/39445, not published. Read-only bind mounts: crypto msp/tls/pqc-keystore and `../config/{core,orderer}.yaml`. **docker.sock mounts and `CORE_VM_*` removed.** `CORE_LEDGER_STATE_STATEDATABASE=goleveldb` (CouchDB env removed). New `chaincode-qchaincode` service (ccaas, `qchain-pqc/ccaas-qchain:2.0`, profile `chaincode`, `CHAINCODE_ID` from `QCHAINCODE_PACKAGE_ID`). `couchdb0` moved to profile `couchdb` (unpublished). `ipfs` moved to profile `ipfs` (127.0.0.1:24001/25001/28080). **qchain-server removed.** uid 1000, read_only, tmpfs `/tmp:mode=1777`, restart "no", mem limits as in the proven run | PQC images (stock ones cannot run ML-DSA identities); no collisions with other projects; ccaas instead of Docker-built chaincode; the source's own start script never ran qchain-server (stale build path) or ipfs |
| `docker/docker-compose-ca.yaml` | `ca.government` and `ca.general` use `qchain-pqc/fabric-ca-server:e82caf43`, `container_name: qchainpqc_ca.<org>`, **exec-form** `command: ["start","-H","/var/hyperledger/production"]` (was `sh -c 'fabric-ca-server start -b admin:adminpw -d'`). Home = `../fabric-ca/<org>` bind-mounted at `/var/hyperledger/production`. Ports 127.0.0.1:27054 / 28054; operations 37054 / 38054, not published. **ca.orderer removed.** Same project, network and hardening as the main file | the image has no shell; the bootstrap identity is in the config registry (as in the proven CA); the CA home path is uid-1000 owned in the image (proven); b1 has no orderer CA |
| `fabric-ca/government/fabric-ca-server-config.yaml` | port 27054. `tls.certfile/keyfile` = `tls/tls-cert.pem` / `tls/tls-key.pem`. `ca.certfile/keyfile` = `cafiles/ca.government.uae.com-cert.pem` / `cafiles/priv_sk` (D7). `csr.keyrequest.algo: mldsa44` (the `csr.ca` block removed). `tls` signing profile removed. `bccsp: default: PQC, pqc: keystorepath: msp/keystore` (was SW). Registry, db, affiliations unchanged | doc config (`~/fabric-ca/docs/source/pqc-mldsa.md`): a PQC CA refuses TLS without an external key file; upper-case PQC, no password; the `tls` profile (key encipherment / key agreement) is unused in b1 and unfit for ML-DSA |
| `fabric-ca/general/fabric-ca-server-config.yaml` | same, port 28054, General files | same |
| `scripts/registerEnroll.sh` | edited in place, same name. Sources `pqc-env.sh`; PQC `fabric-ca-client` by explicit path (`PATH=…:~/fabric/build/bin` removed). Every client home gets `fabric-ca-client-config.yaml` (PQC, mldsa44). `--tls.certfiles` = the CA's ECDSA TLS cert. CA admin homes moved to `crypto-material/peerOrganizations/<org>/ca-admin`. Node/admin/orderer register+enroll and the TLS-profile enrolls removed. issuer1/verifier1 kept (same attrs, secrets and `--enrollment.attrs role`). NodeOUs `config.yaml` points at the actual `cacerts/*.pem`. Wallets built with `mkwallet-g1` instead of `sed` over `keystore/*_sk`. New helpers `client_cfg`/`nodeous` (`--functions-only`) | b1: node material from cryptogen; ML-DSA keys; the org `msp/` is the channel MSP and must not be overwritten; the sed wallet picked any `_sk` (breaks after reenroll), mkwallet-g1 picks the matching key |
| `scripts/env-gov.sh`, `scripts/env-gen.sh` | source `pqc-env.sh`; `PEER=$PQC_PEER`; `FABRIC_CFG_PATH` = `crypto-material/cli-config/admin-<org>` (generated); `CORE_PEER_ADDRESS` = 27051 / 29051 | host CLI with BCCSP PQC and its own key store (per-identity config files, as in the proven CLIs); port map |
| `scripts/start-fabric-network.sh` | `docker compose -p qchainpqc`, docker by explicit path, `COMPOSE_IGNORE_ORPHANS`, refuses to start without crypto material, starts 2 CAs + orderer + 2 peers (no CouchDB) | project naming; the CAs and nodes are in two files of one project; no empty root-owned bind mounts; goleveldb |
| `scripts/setup-fabric-autostart.sh` | unit `qchainpqc-fabric.service`; paths from this directory | do not clobber the source's unit; the copy is not inside the QChain repo. Never run during this task |
| `scripts/start-demo.sh` | `REPO_ROOT` defaults to `~/QChain-PQC-blockchain` (`QCHAIN_REPO`); **no longer calls `offchain/docker-run.sh`** and prints the PQC backend settings instead; Fabric checks use the `qchainpqc_` container names (exact match); docker by explicit path | docker-run.sh mounts `$REPO_ROOT/qchain-network` (the original network) and the backend's default ports, so auto-starting it from here would point the API at the wrong network |
| `scripts/enrollAdmin.js`, `scripts/registerUser.js` | header comment only: "NOT USABLE WITH ML-DSA" with the replacements; code unchanged | the Node `fabric-ca-client` SDK makes ECDSA P-256 keys client-side |

## Added files

| File | Purpose |
|---|---|
| `CHANGES-PQC.md` | this file |
| `README-PQC.md` | what differs, prerequisites, documented commands, limits |
| `scripts/pqc-env.sh` | explicit binary paths (overridable), ports, names, paths; `pqc_need` (refuses missing binaries and anything under `~/qchain-native`), `pqc_dockerup` |
| `scripts/generate-crypto-pqc.sh` | run-time generation: cryptogen ML-DSA-44; pqc-keystore copies; host CLI configs; D7 CA files; ECDSA CA server TLS (openssl). Never overwrites, never prints keys |
| `scripts/create-channel-pqc.sh` | configtxgen genesis (`mychannel`), osnadmin join, peer joins, heights |
| `scripts/deployCC-pqc.sh` | ccaas package `qchaincode_2.0`, install ×2, start the chaincode service, approve ×2, commit, querycommitted |
| `scripts/registerUser-pqc.sh` | PQC replacement for registerUser.js (same user name, affiliation, ecert attrs, wallet path) |
| `scripts/stop-fabric-network.sh` | `compose stop` (keeps containers, volumes and crypto) |
| `scripts/teardown-pqc.sh` | removes `qchainpqc_*` containers/volumes/network only (list first, `--yes` to act). Separate action `purge-crypto --yes-delete-keys` for keys and runtime files. HOLDs on a signal or an unreachable daemon. Never prunes; no deletion in traps |

## Removed from the copy

| Path | Why |
|---|---|
| `fabric-ca/orderer/fabric-ca-server-config.yaml` (and its directory) | decision 9: ca.orderer dropped (b1: the orderer org has only cryptogen identities) |

## Unchanged (copied as-is)

- `chaincode/` (4 files): identical to the code in `qchain-pqc/ccaas-qchain:2.0`.
- `channel-artifacts/.gitkeep`.
- `scripts/setup-demo.sh`, `scripts/setup-ipfs-service.sh`, `scripts/setup-tailscale-funnel.sh`, `scripts/schema.sql`, `scripts/package.json`.
