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


beacon_args=(
  --metrics
  --metrics-address="$IP_ADDRESS"
  --metrics-port="$CONSENSUS_BEACON_METRIC_PORT"
  --non-interactive
  --data-dir="$CONSENSUS_NODE_DIR"
  --log-level="$CONSENSUS_LOG_LEVEL"
  --network="$CONSENSUS_NODE_DIR/../"
  --secrets-dir="$CONSENSUS_NODE_DIR/secrets"
  --validators-dir="$CONSENSUS_NODE_DIR/keys"
  --rest
  --rest-address="0.0.0.0"
  --rest-port="$CONSENSUS_BEACON_API_PORT"
  --listen-address="$IP_ADDRESS"
  --tcp-port="$CONSENSUS_P2P_PORT"
  --udp-port="$CONSENSUS_P2P_PORT"
  --nat="extip:$IP_ADDRESS"
  --discv5=true
  --subscribe-all-subnets
  --insecure-netkey-password
  --netkey-file="$CONSENSUS_NODE_DIR/netkey-file.txt"
  --graffiti="$CONSENSUS_GRAFFITI"
  --in-process-validators=true
  --doppelganger-detection=true
  --bootstrap-node="$bootnode_enr"
  --jwt-secret="$JWT_SECRET_FILE"
  --web3-url=http://"127.0.0.1:$EXECUTION_ENGINE_HTTP_PORT"
  --dump:on
  --doppelganger-detection=off
)

mock_builder_args=(
  --cl "127.0.0.1:$CONSENSUS_BEACON_API_PORT"
  --el "127.0.0.1:$EXECUTION_ENGINE_HTTP_PORT"
  --jwt-secret "$(cat $JWT_SECRET_FILE)"
  --el-rpc-port $EXECUTION_HTTP_PORT
  --extra-data "mock-builder"
  --log-level "info"
  --get-payload-delay-ms 300
  --bid-multiplier 5
  --port 18550
  --client-init-timeout 60    
)

# if [ "$DISABLE_PEER_SCORING" == 1 ]; then
#     echo "disabling peer scoring"
#     beacon_args+=(
#       --direct-peer
#     )
# fi

if [ "$MOCK_BUILDER" == 1 ]; then
  echo "Launching mock builder"
  beacon_args+=(
    --payload-builder=true
    --payload-builder-url=http://127.0.0.1:18550
  )
  validator_args+=(
    --enable-builder
  )
  mock-builder "${mock_builder_args[@]}" > /data/logs/"service_$CONTAINER_NAME--builder" 2>&1 &
fi

echo "Launching nimbus in ${CONTAINER_NAME}"
nimbus_beacon_node "${beacon_args[@]}" > /data/logs/"service_$CONTAINER_NAME--nimbus" 2>&1
