#!/bin/bash

set -eo pipefail

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

geth_bin=$(which geth)

if [ -n "$PATH_PATCH" ]; then
  echo "Patching binary path $PATH_PATCH"
  geth_bin=$PATH_PATCH/geth
  export PATH="$PATH_PATCH:$PATH"
fi

echo "Using path: $PATH"

# Time for execution clients to start up.
# go geth init
echo "GETH: Init the genesis"
geth init \
  --state.scheme=hash \
  --db.engine=pebble \
  --datadir "$EXECUTION_NODE_DIR" \
  "$EXECUTION_GENESIS_FILE"


geth_args=(
  --allow-insecure-unlock
  --authrpc.addr=0.0.0.0
  --authrpc.jwtsecret="$JWT_SECRET_FILE"
  --authrpc.port="$EXECUTION_ENGINE_HTTP_PORT"
  --authrpc.vhosts="*"
  --datadir="$EXECUTION_NODE_DIR"
  --discovery.dns=""
  --gcmode=archive
  --http
  --http.api "$EXECUTION_HTTP_APIS"
  --http.addr 0.0.0.0
  --http.corsdomain "*"
  --http.port "$EXECUTION_HTTP_PORT"
  --http.vhosts="*"
  --ipcdisable=true
  --log.vmodule=rpc=5
  --metrics
  --metrics.addr="$IP_ADDRESS"
  --metrics.port="$EXECUTION_METRIC_PORT"
  --nat "extip:$IP_ADDRESS"
  --netrestrict="$IP_SUBNET"
  --networkid="$CHAIN_ID"
  --port "$EXECUTION_P2P_PORT"
  --rpc.allow-unprotected-txs
  --syncmode=full
  --verbosity "$EXECUTION_LOG_LEVEL"
  --ws --ws.api "$EXECUTION_WS_APIS"
  --ws.addr 0.0.0.0
  --ws.port="$EXECUTION_WS_PORT"
  --state.scheme=hash
  --db.engine=pebble
)
echo "Launching geth"

$geth_bin "${geth_args[@]}" > /data/logs/"service_$CONTAINER_NAME--geth" 2>&1
