#!/bin/bash

set -euo pipefail

# the set -u option will make this fail if any of these variables don't exist
# shellcheck disable=SC2034
env_vars=(
  "$CONSENSUS_BEACON_API_PORT"
  "$CONSENSUS_BEACON_METRIC_PORT"
  "$CONSENSUS_BEACON_RPC_PORT"
  "$CONSENSUS_BOOTNODE_FILE"
  "$CONSENSUS_CHECKPOINT_FILE"
  "$CONSENSUS_CLIENT"
  "$CONSENSUS_CONFIG_FILE"
  "$CONSENSUS_GENESIS_FILE"
  "$CONSENSUS_GRAFFITI"
  "$CONSENSUS_NODE_DIR"
  "$CONSENSUS_P2P_PORT"
  "$CONSENSUS_VALIDATOR_METRIC_PORT"
  "$CONSENSUS_VALIDATOR_RPC_PORT"
  "$CONSENSUS_LOG_LEVEL"
  "$IP_ADDRESS"
  "$IP_SUBNET"
  "$JWT_SECRET_FILE"
  "$COLLECTION_DIR"
  "$NUM_CLIENT_NODES"
  "$EXECUTION_ENGINE_HTTP_PORT"
  "$EXECUTION_ENGINE_WS_PORT"
  "$IS_DENEB"
)

# we can wait for the bootnode enr to drop before we get the signal to start up.
while [ ! -f "$CONSENSUS_BOOTNODE_FILE" ]; do
  echo "consensus client waiting for bootnode enr file: $CONSENSUS_BOOTNODE_FILE"
  sleep 1
done

bootnode_enr="$(cat "$CONSENSUS_BOOTNODE_FILE")"

while [ ! -f "$CONSENSUS_CHECKPOINT_FILE" ]; do
  echo "Waiting for consensus checkpoint file: $CONSENSUS_CHECKPOINT_FILE"
  sleep 1
done

teku_args=(
  --data-path="$CONSENSUS_NODE_DIR"
  --data-storage-mode=PRUNE
  --ee-endpoint="http://127.0.0.1:$EXECUTION_ENGINE_HTTP_PORT"
  --ee-jwt-secret-file="$JWT_SECRET_FILE"
  --initial-state="$CONSENSUS_GENESIS_FILE"
  --log-color-enabled=false
  --log-destination=CONSOLE
  --logging="$CONSENSUS_LOG_LEVEL"
  --metrics-enabled=true
  --metrics-host-allowlist="*"
  --metrics-interface=0.0.0.0
  --metrics-port="$CONSENSUS_BEACON_METRIC_PORT"
  --network="$CONSENSUS_CONFIG_FILE"
  --p2p-advertised-ip="$IP_ADDRESS"
  --p2p-advertised-port="$CONSENSUS_P2P_PORT"
  --p2p-advertised-udp-port="$CONSENSUS_P2P_PORT"
  --p2p-discovery-bootnodes="$bootnode_enr"
  --p2p-discovery-enabled=true
  --p2p-discovery-site-local-addresses-enabled=true
  --p2p-enabled=true
  --p2p-peer-lower-bound=1
  --p2p-peer-upper-bound="$NUM_CLIENT_NODES"
  --p2p-port="$CONSENSUS_P2P_PORT"
  --p2p-subscribe-all-subnets-enabled=true
  --rest-api-docs-enabled=true
  --rest-api-enabled=true
  --rest-api-host-allowlist="*"
  --rest-api-interface=0.0.0.0
  --rest-api-port="$CONSENSUS_BEACON_API_PORT"
  --validator-keys="$CONSENSUS_NODE_DIR/keys:$CONSENSUS_NODE_DIR/secrets"
  --validators-graffiti="$CONSENSUS_GRAFFITI"
  --validators-keystore-locking-enabled=false
  --validators-proposer-default-fee-recipient=0xA18Fd83a55A9BEdB96d66C24b768259eED183be3
  --data-storage-non-canonical-blocks-enabled=true
  --Xlog-include-p2p-warnings-enabled
)
if [ "$IS_DENEB" == 1 ]; then
  teku_args+=(
    --Xmetrics-blob-sidecars-storage-enabled=true
    --Xtrusted-setup="$TRUSTED_SETUP_TXT_FILE"
  )
  echo "Launching deneb ready teku"
else
  echo "Launching teku"
fi

# antithesis: disable log color and set destination to CONSOLE
teku-evil "${teku_args[@]}" > /data/logs/"service_$CONTAINER_NAME--teku" 2>&1
