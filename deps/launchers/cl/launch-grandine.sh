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

grandine_args=(
  --data-dir="$CONSENSUS_NODE_DIR"
  --prune-storage
  --eth1-rpc-urls="http://127.0.0.1:$EXECUTION_ENGINE_HTTP_PORT"
  --jwt-secret="$JWT_SECRET_FILE"
  --genesis-state-file="$CONSENSUS_GENESIS_FILE"
  --metrics
  --metrics-address=0.0.0.0
  --metrics-port="$CONSENSUS_BEACON_METRIC_PORT"
  --configuration-file="$CONSENSUS_CONFIG_FILE"
  --boot-nodes="$bootnode_enr"
  --discovery-port "$CONSENSUS_P2P_PORT"
  --enable-private-discovery
  --enr-address "$IP_ADDRESS"
  --enr-tcp-port "$CONSENSUS_P2P_PORT"
  --enr-udp-port "$CONSENSUS_P2P_PORT"
  --http-address=0.0.0.0
  --http-allowed-origins="*"
  --http-port="$CONSENSUS_BEACON_API_PORT"
  --keystore-dir="$CONSENSUS_NODE_DIR/keys"
  --keystore-password-dir="$CONSENSUS_NODE_DIR/secrets"
  --graffiti="$CONSENSUS_GRAFFITI"
  --suggested-fee-recipient=0xA18Fd83a55A9BEdB96d66C24b768259eED183be3
  --subscribe-all-subnets
  --target-peers="$NUM_CLIENT_NODES"
)

echo "Launching grandine"

if [ "$DISABLE_PEER_SCORING" == 1 ]; then
    echo "disabling peer scoring"
    beacon_args+=(
      --disable-peer-scoring
    )
fi

grandine "${grandine_args[@]}" > /data/logs/"service_$CONTAINER_NAME--grandine" 2>&1
