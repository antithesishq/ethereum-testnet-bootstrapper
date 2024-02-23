#!/usr/bin/env bash
set -e
# Usage:
# $1: Image tag
# $2: Dockerfile
function build_image() {
    if [ "${REBUILD_IMAGES}" == 1 ]; then
        container_builder build --no-cache -t $1 -f $2 || echo "failed to rebuild $1"
    else
        container_builder build -t $1 -f $2 || echo "failed to build $1"
    fi
}


# Usage:
# $1: logging string.
function log_step() {
    echo "[ethereum-testnet-bootstrapper] — $1"
}

function container_builder() {
    if hash docker 2>/dev/null; then
        BUILDKIT=1 docker "$@" .
    else
        podman "$@"
    fi
}

TAG="dencun"
CONTAINER_REPOSITORY="us-central1-docker.pkg.dev/molten-verve-216720/ethereum-repository"
BOOTSTRAPPER="$CONTAINER_REPOSITORY/ethereum-testnet-bootstrapper:$TAG"
ETB_ALL_CLIENTS="$CONTAINER_REPOSITORY/etb-all-clients:$TAG"
CONFIG_IMAGE="$CONTAINER_REPOSITORY/etb-mainnet-config-prysm-geth:$TAG"
CONFIG="/configs/clients/mainnet-deneb-prysm-geth.yaml"
CONFIG_IMAGE_ASSERTOOR="$CONTAINER_REPOSITORY/etb-mainnet-config-prysm-geth-assertoor:$TAG"
CONFIG_ASSERTOOR="/configs/clients/mainnet-deneb-prysm-geth-assertoor.yaml"

#log_step "building bootstrapper"
#build_image $BOOTSTRAPPER "bootstrapper.Dockerfile" . && docker push "$BOOTSTRAPPER"
#
#log_step "building etb all clients"
#cd ./deps/dockers/ && build_image $ETB_ALL_CLIENTS "etb-all-clients_mainnet_dencun.Dockerfile" && docker push $ETB_ALL_CLIENTS  && cd ../..
#
log_step "building config image"
docker build --build-arg "CONFIG_PATH=$CONFIG" -t $CONFIG_IMAGE -f config.Dockerfile . && docker push $CONFIG_IMAGE

log_step "building config image $CONFIG_ASSERTOOR"
docker build --build-arg "CONFIG_PATH=$CONFIG_ASSERTOOR" -t $CONFIG_IMAGE_ASSERTOOR -f config.Dockerfile . && docker push $CONFIG_IMAGE_ASSERTOOR
