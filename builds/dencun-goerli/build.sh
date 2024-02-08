#!/usr/bin/env bash
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

TAG="dencun-goerli"

#log_step "building all clients"
#build_image "etb-all-clients:$TAG" "etb-all-clients_mainnet.Dockerfile"

#log_step "building all clients instrumented"
#build_image "etb-all-clients-inst:$TAG" "etb-all-clients_mainnet-inst-local.Dockerfile"

log_step "building all clients race"
build_image "etb-all-clients-race:$TAG" "etb-all-clients_mainnet-race.Dockerfile"
