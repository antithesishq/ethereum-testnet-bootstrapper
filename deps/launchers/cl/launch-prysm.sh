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
  "$EXECUTION_HTTP_PORT"
  "$EXECUTION_ENGINE_HTTP_PORT"
  "$EXECUTION_ENGINE_WS_PORT"
)

# we can wait for the bootnode enr to drop before we get the signal to start up.
while [ ! -f "$CONSENSUS_BOOTNODE_FILE" ]; do
  echo "consensus client waiting for bootnode enr file: $CONSENSUS_BOOTNODE_FILE"
  sleep 1
done

while [ ! -f "$CONSENSUS_CHECKPOINT_FILE" ]; do
  echo "Waiting for consensus checkpoint file: $CONSENSUS_CHECKPOINT_FILE"
  sleep 1
done


beacon_args=(
  --dev
  --monitoring-host="$IP_ADDRESS"
  --monitoring-port="$CONSENSUS_BEACON_METRIC_PORT"
  --accept-terms-of-use=true
  --datadir="$CONSENSUS_NODE_DIR"
  --chain-config-file="$CONSENSUS_CONFIG_FILE" 
  --genesis-state="$CONSENSUS_GENESIS_FILE" 
  --bootstrap-node="$(<"$CONSENSUS_BOOTNODE_FILE")"
  --verbosity="$CONSENSUS_LOG_LEVEL"
  --p2p-host-ip="$IP_ADDRESS"
  --p2p-max-peers="$NUM_CLIENT_NODES"
  --p2p-udp-port="$CONSENSUS_P2P_PORT"
  --p2p-tcp-port="$CONSENSUS_P2P_PORT"
  --monitoring-host=0.0.0.0
  --monitoring-port="$CONSENSUS_BEACON_METRIC_PORT"
  --rpc-host=0.0.0.0
  --rpc-port="$CONSENSUS_BEACON_RPC_PORT"
  --grpc-gateway-host=0.0.0.0
  --grpc-gateway-port="$CONSENSUS_BEACON_API_PORT"
  --enable-debug-rpc-endpoints
  --p2p-allowlist="$IP_SUBNET"
  --subscribe-all-subnets
  --force-clear-db
  --jwt-secret="$JWT_SECRET_FILE"
  --suggested-fee-recipient=0x00000000219ab540356cbb839cbe05303d7705fa
  --execution-endpoint="http://127.0.0.1:$EXECUTION_ENGINE_HTTP_PORT"
  --min-sync-peers 1
)

#  --log-file="$CONSENSUS_NODE_DIR/beacon.log"

validator_args=(
  --monitoring-host="$IP_ADDRESS"
  --monitoring-port="$CONSENSUS_VALIDATOR_METRIC_PORT"
  --accept-terms-of-use=true
  --datadir="$CONSENSUS_NODE_DIR"
  --chain-config-file="$CONSENSUS_CONFIG_FILE"
  --beacon-rpc-provider="127.0.0.1:$CONSENSUS_BEACON_RPC_PORT"
  --monitoring-host=0.0.0.0
  --monitoring-port="$CONSENSUS_VALIDATOR_METRIC_PORT"
  --graffiti="$CONSENSUS_GRAFFITI"
  --wallet-dir="$CONSENSUS_NODE_DIR"
  --wallet-password-file="$CONSENSUS_NODE_DIR/wallet-password.txt"
  --suggested-fee-recipient=0x00000000219ab540356cbb839cbe05303d7705fa
  --verbosity="$CONSENSUS_LOG_LEVEL"
)

mock_builder_args=(
  --cl "127.0.0.1:$CONSENSUS_BEACON_API_PORT"
  --el "127.0.0.1:$EXECUTION_ENGINE_HTTP_PORT"
  --jwt-secret "$(cat $JWT_SECRET_FILE)"
  --el-rpc-port $EXECUTION_HTTP_PORT
  --extra-data "mock-builder"
  --log-level "info"
  --get-payload-delay-ms 100
  --bid-multiplier 5
  --port 18550
  --client-init-timeout 60    
)

if [ "$MOCK_BUILDER" == 1 ]; then
  echo "Launching mock builder"
  beacon_args+=(
    --http-mev-relay http://127.0.0.1:18550
  )
  validator_args+=(
    --enable-builder
  )
  mock-builder "${mock_builder_args[@]}" > /data/logs/"service_$CONTAINER_NAME--builder" 2>&1 &
fi

echo "Launching Prysm beacon node in ${CONTAINER_NAME}"
beacon-chain "${beacon_args[@]}" > /data/logs/"service_$CONTAINER_NAME--prysm-bn" 2>&1 &

sleep 10

echo "Launching Prysm validator client in ${CONTAINER_NAME}"

validator "${validator_args[@]}" > /data/logs/"service_$CONTAINER_NAME--prysm-vc" 2>&1
