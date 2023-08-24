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

if [ "$IS_DENEB" == 1 ]; then
  echo "Launching deneb ready nethermind."
  nethermind_args=(
    # --Init.KzgSetupFile "$TRUSTED_SETUP_TXT_FILE" \
    --Metrics.Enabled=true
    --Metrics.ExposePort="$EXECUTION_METRIC_PORT"
    --config="/tmp/nethermind.cfg"
    --datadir="$EXECUTION_NODE_DIR"
    --Init.ChainSpecPath="$EXECUTION_GENESIS_FILE"
    --Init.StoreReceipts=true
    --Init.WebSocketsEnabled=true
    --Init.EnableUnsecuredDevWallet=true
    --Init.DiagnosticMode="None"
    --Init.IsMining=false
    --Pruning.Mode=None
    --JsonRpc.Enabled=true
    --JsonRpc.EnabledModules="$EXECUTION_HTTP_APIS"
    --JsonRpc.Port="$EXECUTION_HTTP_PORT"
    --JsonRpc.WebSocketsPort="$EXECUTION_WS_PORT"
    --JsonRpc.Host=0.0.0.0
    --Network.ExternalIp="$IP_ADDRESS"
    --Network.LocalIp="$IP_ADDRESS"
    --Network.DiscoveryPort="$EXECUTION_P2P_PORT"
    --Network.P2PPort="$EXECUTION_P2P_PORT"
    --JsonRpc.JwtSecretFile="$JWT_SECRET_FILE"
    --JsonRpc.AdditionalRpcUrls="http://localhost:$EXECUTION_ENGINE_HTTP_PORT|http|net;eth;subscribe;engine;web3;client;clique,http://localhost:$EXECUTION_ENGINE_WS_PORT|ws|net;eth;subscribe;engine;web3;client"
    --log $EXECUTION_LOG_LEVEL
  )

else
  nethermind_args=(
    --config="/tmp/nethermind.cfg"
    --datadir="$EXECUTION_NODE_DIR"
    --Init.ChainSpecPath="$EXECUTION_GENESIS_FILE"
    --Init.StoreReceipts=true
    --Init.WebSocketsEnabled=true
    --Init.EnableUnsecuredDevWallet=true
    --Init.DiagnosticMode="None"
    --JsonRpc.Enabled=true
    --JsonRpc.EnabledModules="$EXECUTION_HTTP_APIS"
    --JsonRpc.Port="$EXECUTION_HTTP_PORT"
    --JsonRpc.WebSocketsPort="$EXECUTION_WS_PORT"
    --JsonRpc.Host=0.0.0.0
    --Network.ExternalIp="$IP_ADDRESS"
    --Network.LocalIp="$IP_ADDRESS"
    --Network.DiscoveryPort="$EXECUTION_P2P_PORT"
    --Network.P2PPort="$EXECUTION_P2P_PORT"
    --JsonRpc.JwtSecretFile="$JWT_SECRET_FILE"
    --JsonRpc.AdditionalRpcUrls="http://localhost:$EXECUTION_ENGINE_HTTP_PORT|http|net;eth;subscribe;engine;web3;client;clique,http://localhost:$EXECUTION_ENGINE_WS_PORT|ws|net;eth;subscribe;engine;web3;client"
    --log $EXECUTION_LOG_LEVEL
  )
fi
nethermind "${nethermind_args[@]}" > /data/logs/"service_$CONTAINER_NAME--nethermind" 2>&1
