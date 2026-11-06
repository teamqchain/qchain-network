# qchain-network-pqc

A post-quantum copy of `qchain-network`. Every Fabric identity uses ML-DSA-44: the orderer, the peers, the admins and the application users. Peer-to-peer and orderer TLS certificates are ML-DSA-44 as well. It was created on 2026-10-31.

The layout and script names are the same as in `qchain-network`. Every difference is listed, with the reason, in [CHANGES-PQC.md](CHANGES-PQC.md). The original `~/qchain-network` was not modified.

> **Status:** files only. Nothing in this directory has been run yet: no crypto material, no containers, no channel. The commands below are documented, not executed.

## What is different from qchain-network

| | qchain-network | qchain-network-pqc |
|---|---|---|
| Signature algorithm | ECDSA P-256 (SW BCCSP) | ML-DSA-44 (BCCSP `PQC`, fabric-lib-go bccsp-pqc) |
| Images | `hyperledger/fabric-*:latest` | `qchain-pqc/orderer:e472b4ea`, `qchain-pqc/peer:e472b4ea`, `qchain-pqc/fabric-ca-server:e82caf43`, `qchain-pqc/ccaas-qchain:2.0` |
| Node + admin crypto | Fabric CA enrolls (including a TLS profile) | PQC **cryptogen** (`config/crypto-config.yaml`), design b1 |
| Application identities | Fabric CA (Node SDK or CLI) | PQC **fabric-ca** per org. Its CA cert and key are the cryptogen org CA's (D7), so CA-issued users chain to the channel MSP root |
| CA server TLS | CA self-generated | external **ECDSA P-256** cert and key per CA (a PQC CA refuses TLS without a key file); clients trust it with `--tls.certfiles` |
| CAs | government, general, orderer | government, general (no orderer CA) |
| Channel | `mychannel`, Channel V2_0 | `mychannel`, **Channel V3_0** (needed for ML-DSA identities), Orderer V2_0, Application V2_5 |
| Chaincode | Docker-built node chaincode (docker.sock) | chaincode as a service (ccaas), `qchaincode` / label `qchaincode_2.0`; no docker.sock |
| State DB | CouchDB | goleveldb (CouchDB optional, profile `couchdb`) |
| Wallets | `sed` over `keystore/*_sk` | `mkwallet-g1` (QChain 6ba0658) |
| Compose | project `docker`, unprefixed names | project **`qchainpqc`**, every container, volume and network `qchainpqc_*` |
| ipfs / qchain-server | in the main compose | ipfs behind profile `ipfs`; qchain-server removed (it was stale) |

### Ports (127.0.0.1 only; container port = host port)

| Service | Port | Operations (internal, not published) |
|---|---|---|
| orderer0 | 27050, admin 27053 | 38443 |
| peer0.government | 27051 (chaincode 27052, internal) | 39444 |
| peer0.general | 29051 (chaincode 29052, internal) | 39445 |
| ca.government | 27054 | 37054 |
| ca.general | 28054 | 38054 |
| chaincode-qchaincode | 9998 (internal) | |
| ipfs (profile) | 24001, 25001, 28080 | |

These do not collide with `qchain-network`, the qchaind test network or the exited climatenet/agent containers.

The host CLI reaches the nodes by name through the existing `/etc/hosts` entries, which map `orderer0.orderer.example.com`, `peer0.government.uae.com` and `peer0.general.uae.com` to 127.0.0.1. The CAs are reached at `https://localhost:<port>`; their TLS certificates have a `localhost` SAN.

## Prerequisites

1. **Docker Desktop** with WSL integration for Ubuntu.
   - Never run `docker system prune`, `docker volume prune` or `--remove-orphans`.
   - Never start the climatenet containers.
2. **Images, present locally** (check with `docker images qchain-pqc/*`):
   - `qchain-pqc/orderer:e472b4ea`
   - `qchain-pqc/peer:e472b4ea` (ccaas builder at `/opt/ccaas`)
   - `qchain-pqc/fabric-ca-server:e82caf43`
   - `qchain-pqc/ccaas-qchain:2.0` (contains this `chaincode/` code, byte-identical)
   - Optional: `couchdb:3.3.2` (present) and `ipfs/kubo:latest` (**not present locally**).
   - Do not use the stock `hyperledger/*` images; they cannot run ML-DSA identities.
3. **Host binaries** in `$PQC_BIN` (default `~/pqc-scratch/docker/bin`; all paths can be changed in `scripts/pqc-env.sh`):
   - Present: `peer`, `osnadmin` (fabric e472b4ea, `-tags pqc`) and `fabric-ca-client` (fabric-ca e82caf43, `-tags pkcs11,pqc`).
   - **Missing; build them first** (one build at a time; not done by any script):
     ```
     cd ~/fabric && GOTOOLCHAIN=go1.27.0 GOFLAGS=-p=1 go build -tags pqc -o ~/pqc-scratch/docker/bin/cryptogen   ./cmd/cryptogen
     cd ~/fabric && GOTOOLCHAIN=go1.27.0 GOFLAGS=-p=1 go build -tags pqc -o ~/pqc-scratch/docker/bin/configtxgen ./cmd/configtxgen
     ```
     `~/fabric` has untracked files, so these builds show `vcs.modified=true`. For `vcs.modified=false`, build from the clean clone `~/pqc-scratch/docker/src/fabric-e472b4ea` instead.
   - The scripts refuse binaries under `~/qchain-native`.
4. **mkwallet-g1** at `~/pqc-scratch/smoke/bin2/mkwallet-g1` (QChain 6ba0658), or set `MKWALLET`.
5. **OpenSSL 3.5** at `/usr/bin/openssl`. It is used only for the ECDSA CA server TLS certs and random user secrets.

## Commands (documented; run from `~/qchain-network-pqc`)

```bash
# 1. crypto material (cryptogen ML-DSA-44, key store copies, CLI configs, D7 CA files, ECDSA CA TLS)
bash scripts/generate-crypto-pqc.sh

# 2. start the CAs, the orderer and the peers (compose project qchainpqc)
bash scripts/start-fabric-network.sh

# 3. channel mychannel: genesis, orderer join, peer joins (anchor peers are in the genesis block)
bash scripts/create-channel-pqc.sh

# 4. CA identities: CA admins, issuer1 (role=issuer) and verifier1 (role=verifier) at GeneralCA, wallets
bash scripts/registerEnroll.sh
#    more users (replaces registerUser.js):
bash scripts/registerUser-pqc.sh Ahmed AlMansouri General issuer

# 5. chaincode qchaincode 2.0 as a service: package, install x2, start the service, approve x2, commit
bash scripts/deployCC-pqc.sh

# host CLI context (PQC peer CLI in $PEER)
. scripts/env-gov.sh    # or env-gen.sh
"$PEER" chaincode query -C mychannel -n qchaincode -c '{"function":"getHolder","Args":["<id>"]}'

# stop (keeps everything) / tear down (qchainpqc_* only; lists first, --yes acts)
bash scripts/stop-fabric-network.sh
bash scripts/teardown-pqc.sh            # list
bash scripts/teardown-pqc.sh --yes      # remove qchainpqc_* containers, volumes and network
# key deletion is a separate, explicit action (refuses while any qchainpqc_ container exists)
bash scripts/teardown-pqc.sh purge-crypto                    # list
bash scripts/teardown-pqc.sh purge-crypto --yes-delete-keys  # delete crypto-material/, wallet/, CA runtime files
```

Optional CouchDB: start `docker compose -p qchainpqc -f docker/docker-compose.yaml --profile couchdb up -d couchdb0`. Then set the following on both peers, for example with an override file:
- `CORE_LEDGER_STATE_STATEDATABASE=CouchDB`
- `CORE_LEDGER_STATE_COUCHDBCONFIG_COUCHDBADDRESS=couchdb0:5984`
- `CORE_LEDGER_STATE_COUCHDBCONFIG_USERNAME/PASSWORD`

This has not been tried with the PQC images.

### Backend (QChain offchain): settings only, the backend repo is not changed here

- `NETWORK_ROOT`: this directory, mounted read-only (the backend reads `crypto-material/peerOrganizations/<org>/peers/<peer>/tls/ca.crt` and `wallet/<org>/<id>.id`).
- `GOV_PEER_ENDPOINT=peer0.government.uae.com:27051` and `GEN_PEER_ENDPOINT=peer0.general.uae.com:29051`.
- `CHANNEL_NAME=mychannel` and `CHAINCODE_NAME=qchaincode` (both are the backend defaults).
- The backend must be built from QChain 6ba0658 or later, which signs Gateway transactions with ML-DSA identities.
- Its wallet format is what `mkwallet-g1` writes: a JSON `.id` with the certificate, the PKCS#8 ML-DSA-44 private key and the mspId.
- `offchain/docker-run.sh` hardcodes `$REPO_ROOT/qchain-network` and passes no peer endpoints, so it needs a variant or overrides for this network. `scripts/start-demo.sh` therefore no longer starts it.

## Known limits

- **ML-DSA-44 only.** No other ML-DSA levels; no ECDSA network baseline was measured.
- **The CA server TLS is classical** (ECDSA P-256 certificate). With OpenSSL 3.5 clients, TLS 1.3 negotiated the hybrid X25519MLKEM768 key exchange; the certificate signature remains ECDSA.
- **Design b1 relies on the D7 shortcut.** Each CA uses the cryptogen org CA key, so that key exists both in `crypto-material/` and in `fabric-ca/<org>/cafiles/`. The source's pure Fabric-CA flow (CA-issued node TLS through a `tls` profile, fresh CA roots) is a later proof step and has not been tried.
- **Remaining ECDSA paths in Fabric** (not used here): tlsgen, the discover CLI, SmartBFT/cluster.
- **Not in use:** `scripts/enrollAdmin.js` and `scripts/registerUser.js` cannot make ML-DSA identities (the Node SDK generates ECDSA keys).
- **Test credentials:** the CA bootstrap password `adminpw` and the issuer1/verifier1 secrets are the source's test defaults and must not be reused anywhere real.
- **TLS verification off:** `httpOptions.verify:false` in the connection examples (as in the source) disables CA TLS verification for SDK clients.
- **Single laptop:** a single orderer and two peers on loopback (Docker Desktop on WSL2).
