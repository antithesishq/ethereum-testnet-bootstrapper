#!/bin/bash

while [ ! -f "$EXECUTION_CHECKPOINT_FILE" ]; do
  echo "Waiting for execution checkpoint file: $EXECUTION_CHECKPOINT_FILE"
    sleep 1
done

# Time for execution clients to start up.
# go geth init
echo "RETH: Init the genesis"
reth init \
    --datadir "$EXECUTION_NODE_DIR" \
    --chain "$EXECUTION_GENESIS_FILE"

if [ "$RUN_JSON_RPC_SNOOPER" == "true" ]; then
  echo "Launching json_rpc_snoop."
  json_rpc_snoop -p "$CL_EXECUTION_ENGINE_HTTP_PORT" http://localhost:"$EXECUTION_ENGINE_HTTP_PORT" 2>&1 | tee "$EXECUTION_NODE_DIR/json_rpc_snoop.log" &
fi

reth_args=(
  node
  -$EXECUTION_LOG_LEVEL
  --log.file.directory=$EXECUTION_NODE_DIR/logs/
  --datadir=$EXECUTION_NODE_DIR
  --chain=$EXECUTION_GENESIS_FILE
  --port=$EXECUTION_P2P_PORT
  --discovery.port=$EXECUTION_P2P_PORT
  --http
  --http.api=$EXECUTION_HTTP_APIS
  --http.addr=0.0.0.0
  --http.port=$EXECUTION_HTTP_PORT
  --http.corsdomain=*
  --ws
  --ws.api=$EXECUTION_WS_APIS
  --ws.addr=0.0.0.0
  --ws.port=$EXECUTION_WS_PORT
  --ws.origins=*
  --nat=extip:$IP_ADDRESS
  --authrpc.addr=0.0.0.0
  --authrpc.port=$EXECUTION_ENGINE_HTTP_PORT
  --authrpc.jwtsecret=$JWT_SECRET_FILE
  --metrics=0.0.0.0:$EXECUTION_METRIC_PORT
)

echo "Launching reth execution client."
reth "${reth_args[@]}" > /data/logs/"service_$CONTAINER_NAME--reth" 2>&1
