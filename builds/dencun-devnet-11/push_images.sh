set -e

ETB_ALL_CLIENTS="etb-all-clients"
ETB_ALL_CLIENTS_INST="etb-all-clients-inst"

TAG="dencun-devnet-11"

BOOTSTRAPPER="ethereum-testnet-bootstrapper"
CONFIG_IMAGE="etb-mainnet-config"
CONFIG_IMAGE_INST="etb-mainnet-config-inst"
CONFIG_IMAGE_INST_ALT="etb-mainnet-config-inst-alt"
CONFIG_IMAGE_CUSTOM="etb-mainnet-config-custom"
CONFIG_IMAGE_EVIL="etb-mainnet-config-evil"
CONFIG_IMAGE_BUILDER="etb-mainnet-config-builder"
# CONFIG_IMAGE_MINIMAL="etb-minimal-config"
# CONFIG_IMAGE_MINIMAL_INST="etb-minimal-config-inst"

CONTAINER_REPOSITORY="us-central1-docker.pkg.dev/molten-verve-216720/ethereum-repository"

# build the images
#/bin/bash -c "REBUILD_IMAGES=1 ./build.sh"

# Check if Makefile exists in the current directory
if [ ! -f "Makefile" ]; then
    echo "Makefile not found in the current directory. A Makefile is required to proceed. Make sure you are in the root of the project directory"
    exit 1
fi

make build-bootstrapper

make build-config config=builds/$TAG/mainnet-testnet.yaml
docker tag "$CONFIG_IMAGE:latest" "$CONTAINER_REPOSITORY/$CONFIG_IMAGE:$TAG"

make build-config config=builds/$TAG/mainnet-testnet-inst.yaml
docker tag "$CONFIG_IMAGE:latest" "$CONTAINER_REPOSITORY/$CONFIG_IMAGE_INST:$TAG"

make build-config config=builds/$TAG/mainnet-testnet-inst-alt.yaml
docker tag "$CONFIG_IMAGE:latest" "$CONTAINER_REPOSITORY/$CONFIG_IMAGE_INST_ALT:$TAG"

make build-config config=builds/$TAG/mainnet-testnet-custom.yaml
docker tag "$CONFIG_IMAGE:latest" "$CONTAINER_REPOSITORY/$CONFIG_IMAGE_CUSTOM:$TAG"

make build-config config=builds/$TAG/mainnet-testnet-evil.yaml
docker tag "$CONFIG_IMAGE:latest" "$CONTAINER_REPOSITORY/$CONFIG_IMAGE_EVIL:$TAG"

make build-config config=builds/$TAG/mainnet-testnet-builder.yaml
docker tag "$CONFIG_IMAGE:latest" "$CONTAINER_REPOSITORY/$CONFIG_IMAGE_BUILDER:$TAG"

# make build-config config=builds/$TAG/minimal-testnet.yaml
# docker tag "$CONFIG_IMAGE:latest" "$CONTAINER_REPOSITORY/$CONFIG_IMAGE_MINIMAL:$TAG"

# make build-config config=builds/$TAG/minimal-testnet-inst.yaml
# docker tag "$CONFIG_IMAGE:latest" "$CONTAINER_REPOSITORY/$CONFIG_IMAGE_MINIMAL_INST:$TAG"

docker tag "$BOOTSTRAPPER:latest" "$CONTAINER_REPOSITORY/$BOOTSTRAPPER:$TAG"
docker tag "$ETB_ALL_CLIENTS:$TAG" "$CONTAINER_REPOSITORY/$ETB_ALL_CLIENTS:$TAG"
docker tag "$ETB_ALL_CLIENTS_INST:$TAG" "$CONTAINER_REPOSITORY/$ETB_ALL_CLIENTS_INST:$TAG"


docker push "$CONTAINER_REPOSITORY/$CONFIG_IMAGE:$TAG"
docker push "$CONTAINER_REPOSITORY/$CONFIG_IMAGE_INST:$TAG"
docker push "$CONTAINER_REPOSITORY/$CONFIG_IMAGE_INST_ALT:$TAG"
docker push "$CONTAINER_REPOSITORY/$CONFIG_IMAGE_CUSTOM:$TAG"
docker push "$CONTAINER_REPOSITORY/$CONFIG_IMAGE_EVIL:$TAG"
docker push "$CONTAINER_REPOSITORY/$CONFIG_IMAGE_BUILDER:$TAG"


docker push "$CONTAINER_REPOSITORY/$BOOTSTRAPPER:$TAG"
docker push "$CONTAINER_REPOSITORY/$ETB_ALL_CLIENTS:$TAG"
docker push "$CONTAINER_REPOSITORY/$ETB_ALL_CLIENTS_INST:$TAG"
