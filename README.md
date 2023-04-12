![etb-all-clients](https://github.com/antithesishq/ethereum-testnet-bootstrapper/actions/workflows/etb-all-clients.yml/badge.svg)

# ethereum-testnet-bootstrapper

## Client Versions

**Consensus Clients**

Client | Current Release | Branch/tag used for Antithesis testing
--- | --- | ---
Nimbus | 23.3.2 | [unstable](https://github.com/status-im/nimbus-eth2/tree/unstable)
Lodestar | 1.6.0 | [unstable](https://github.com/ChainSafe/lodestar/tree/unstable)
Lighthouse | 4.0.1-rc.0 | [capella](https://github.com/sigp/lighthouse/tree/capella)
Prysm | 3.2.2 | [4.0.0-rc.2](https://github.com/prysmaticlabs/prysm/tree/v4.0.2-rc.0)
Teku | 23.3.1 | [23.3.1](https://github.com/ConsenSys/teku/releases/tag/23.3.1)

**Execution Clients**
Client | Current Release | Branch used for Antithesis testing
--- | --- | ---
Geth | 1.11.5 | [master](https://github.com/ethereum/go-ethereum/tree/master)
Besu | 23.1.2 | [main](https://github.com/hyperledger/besu/tree/main)
Nethermind | 1.17.3 | [master](https://github.com/NethermindEth/nethermind/tree/master)

## Building images

`make build-all-images`

To rebuild images without cache:

`make rebuild-all-images`

## Building a single image

`source ./common.sh && cd deps/dockers/el && build_image geth geth.Dockerfile`

To rebuild without cache:

`source ./common.sh && cd deps/dockers/el && REBUILD_IMAGES=1 build_image geth geth.Dockerfile`
