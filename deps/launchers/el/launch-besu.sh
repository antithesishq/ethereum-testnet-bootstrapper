#!/bin/bash

set -euo pipefail

# the set -u option will make this fail if any of these variables don't exist
# shellcheck disable=SC2034
env_vars=(
  "$EXECUTION_CHECKPOINT_FILE"
  "$EXECUTION_CLIENT"
  "$EXECUTION_ENGINE_HTTP_PORT"
  "$EXECUTION_ENGINE_WS_PORT"
  "$EXECUTION_GENESIS_FILE"
  "$EXECUTION_HTTP_APIS"
  "$EXECUTION_HTTP_PORT"
  "$EXECUTION_LAUNCHER"
  "$EXECUTION_LOG_LEVEL"
  "$EXECUTION_METRIC_PORT"
  "$EXECUTION_NODE_DIR"
  "$EXECUTION_P2P_PORT"
  "$EXECUTION_WS_APIS"
  "$EXECUTION_WS_PORT"
  "$IP_ADDRESS"
  "$IP_SUBNET"
  "$JWT_SECRET_FILE"
  "$CHAIN_ID"
  "$IS_DENEB"
)

while [ ! -f "$EXECUTION_CHECKPOINT_FILE" ]; do
  echo "Waiting for execution checkpoint file: $EXECUTION_CHECKPOINT_FILE"
  sleep 1
done

besu_args=(
  # --bootnodes="$EXECUTION_BOOTNODE"
  --data-path="$EXECUTION_NODE_DIR"
  --data-storage-format="BONSAI"
  --engine-host-allowlist="*"
  --engine-jwt-enabled
  --engine-jwt-secret="$JWT_SECRET_FILE"
  --engine-rpc-enabled=true
  --engine-rpc-port="$EXECUTION_ENGINE_HTTP_PORT"
  --genesis-file="$EXECUTION_GENESIS_FILE"
  --host-allowlist="*"
  --logging="$EXECUTION_LOG_LEVEL"
  --metrics-enabled
  --metrics-host="$IP_ADDRESS"
  --metrics-port="$EXECUTION_METRIC_PORT"
  --nat-method=DOCKER
  --network-id="$CHAIN_ID"
  --p2p-enabled=true
  --p2p-host="$IP_ADDRESS"
  --p2p-port="$EXECUTION_P2P_PORT"
  --rpc-http-cors-origins="*"
  --rpc-http-enabled=true
  --rpc-http-api="$EXECUTION_HTTP_APIS"
  --rpc-http-host=0.0.0.0
  --rpc-http-port="$EXECUTION_HTTP_PORT"
  --rpc-ws-enabled=true
  --rpc-ws-api="$EXECUTION_WS_APIS"
  --rpc-ws-host=0.0.0.0
  --rpc-ws-port="$EXECUTION_WS_PORT"
  --sync-mode=FULL
)
if [ "$IS_DENEB" == 1 ]; then
  besu_args+=(
    --kzg-trusted-setup="$TRUSTED_SETUP_TXT_FILE"
    --engine-rpc-port="$EXECUTION_ENGINE_HTTP_PORT"
  )
  echo "Launching deneb ready besu"
else
  echo "Launching besu"
fi
besu "${besu_args[@]}" > /data/logs/"service_$CONTAINER_NAME--besu" 2>&1
