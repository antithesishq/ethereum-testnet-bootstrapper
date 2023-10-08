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

echo "{}" >/tmp/nethermind.cfg

# Edit the nethermind logging file to not log to a file
sed -i -e "s/.*writeTo=\"file-async\".*//g" /nethermind/NLog.config

nethermind_args=(
  --Init.ChainSpecPath="$EXECUTION_GENESIS_FILE"
  --Init.DiagnosticMode="None"
  --Init.EnableUnsecuredDevWallet=true
  --Init.StoreReceipts=true
  --Init.WebSocketsEnabled=true
  --JsonRpc.AdditionalRpcUrls="http://localhost:$EXECUTION_ENGINE_HTTP_PORT|http|net;eth;subscribe;engine;web3;client;clique,http://localhost:$EXECUTION_ENGINE_WS_PORT|ws|net;eth;subscribe;engine;web3;client"
  --JsonRpc.Enabled=true
  --JsonRpc.EnabledModules="$EXECUTION_HTTP_APIS"
  --JsonRpc.Host=0.0.0.0
  --JsonRpc.JwtSecretFile="$JWT_SECRET_FILE"
  --JsonRpc.Port="$EXECUTION_HTTP_PORT"
  --JsonRpc.WebSocketsPort="$EXECUTION_WS_PORT"
  --Metrics.Enabled=true
  --Metrics.ExposePort="$EXECUTION_METRIC_PORT"
  --Network.DiscoveryPort="$EXECUTION_P2P_PORT"
  --Network.ExternalIp="$IP_ADDRESS"
  --Network.LocalIp="$IP_ADDRESS"
  --Network.P2PPort="$EXECUTION_P2P_PORT"
  --config="/tmp/nethermind.cfg"
  --datadir="$EXECUTION_NODE_DIR"
  --log "$EXECUTION_LOG_LEVEL"
)

if [ "$IS_DENEB" == 1 ]; then
  nethermind_args+=(
    # --Init.KzgSetupFile "$TRUSTED_SETUP_TXT_FILE"
    --Init.IsMining=false
    --Pruning.Mode=None
  )
  echo "Launching deneb ready nethermind"
else
  echo "Launching nethermind"
fi

nethermind "${nethermind_args[@]}" > /data/logs/"service_$CONTAINER_NAME--nethermind" 2>&1
