#!/usr/bin/env bash
set +x
export config=/source/configs/minimal/capella-testing.yaml
make clean && make init-testnet