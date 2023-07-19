#!/usr/bin/env bash
set +x
# export config=configs/mainnet-deneb-testnet.yaml
make clean && make init-testnet config=configs/mainnet-deneb-testnet.yaml log_level=debug && DOCKER_BUILDKIT=1 docker build --no-cache -f config.Dockerfile -t us-central1-docker.pkg.dev/molten-verve-216720/ethereum-repository/etb-mainnet-config:latest-deneb
