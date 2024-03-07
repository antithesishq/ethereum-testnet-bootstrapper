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
  "$CONSENSUS_LOG_LEVEL_FILE"
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

beacon_args=(
    --boot-nodes="$bootnode_enr"
    --datadir="$CONSENSUS_NODE_DIR"
    --debug-level="$CONSENSUS_LOG_LEVEL"
    --discovery-port "$CONSENSUS_P2P_PORT"
    --enable-private-discovery
    --enr-address "$IP_ADDRESS"
    --enr-tcp-port "$CONSENSUS_P2P_PORT"
    --enr-udp-port "$CONSENSUS_P2P_PORT"
    --execution-endpoints="http://127.0.0.1:$EXECUTION_ENGINE_HTTP_PORT"
    --http-address=0.0.0.0
    --http-allow-origin="*"
    --http-port="$CONSENSUS_BEACON_API_PORT"
    --jwt-secrets="$JWT_SECRET_FILE"
    --listen-address=0.0.0.0
    --metrics
    --metrics-address=0.0.0.0
    --metrics-allow-origin="*"
    --port="$CONSENSUS_P2P_PORT"
    --staking
    --subscribe-all-subnets
    --target-peers="$NUM_CLIENT_NODES"
)
    # --trusted-setup-file-override="$TRUSTED_SETUP_JSON_FILE"
# to test p2p we can disable scoring
# In case we want to log differently to a file
#    --logfile-debug-level="$CONSENSUS_LOG_LEVEL_FILE"
#    --logfile="/data/log_files/service_$CONTAINER_NAME--lighthouse-bn.log"
validator_args=(
    --beacon-nodes="http://127.0.0.1:$CONSENSUS_BEACON_API_PORT"
    --debug-level="$CONSENSUS_LOG_LEVEL"
    --graffiti="$CONSENSUS_GRAFFITI"
    --http
    --http-port="$CONSENSUS_VALIDATOR_RPC_PORT"
    --init-slashing-protection
    --metrics
    --metrics-address=0.0.0.0
    --metrics-allow-origin="*"
    --secrets-dir "$CONSENSUS_NODE_DIR/secrets"
    --suggested-fee-recipient=0x00000000219ab540356cbb839cbe05303d7705fa
    --validators-dir "$CONSENSUS_NODE_DIR/keys"
)
# 

# --logfile-debug-level="debug"
# --logfile="/data/log_files/service_$CONTAINER_NAME--lighthouse-vc.log"

if [ "$IS_DENEB" == 1 ]; then
  beacon_args+=(
    --suggested-fee-recipient=0x00000000219ab540356cbb839cbe05303d7705fa
  )
  echo "Launching deneb-ready Lighthouse beacon node in ${CONTAINER_NAME}"
else
  echo "Launching Lighthouse beacon node in ${CONTAINER_NAME}"
fi

mock_builder_args=(
  --cl "127.0.0.1:$CONSENSUS_BEACON_API_PORT"
  --el "127.0.0.1:$EXECUTION_ENGINE_HTTP_PORT"
  --jwt-secret "$(cat $JWT_SECRET_FILE)"
  --el-rpc-port $EXECUTION_HTTP_PORT
  --extra-data "mock-builder"
  --log-level "info"
  --get-payload-delay-ms 50
  --bid-multiplier 5
  --port 18550
  --client-init-timeout 60    
)

if [ "$DISABLE_PEER_SCORING" == 1 ]; then
    echo "disabling peer scoring"
    beacon_args+=(
      --disable-peer-scoring
    )
fi

if [ "$MOCK_BUILDER" == 1 ]; then
  echo "Launching mock builder"
  beacon_args+=(
    --builder http://127.0.0.1:18550
  )
  validator_args+=(
    --builder-proposals
  )

  # at random add the flag prefer-builder-proposals or builder-boost-factor
  if [ $((RANDOM%2)) -eq 0 ]; then
    echo "Adding prefer-builder-proposals flag"
    validator_args+=(
      --prefer-builder-proposals
    )
  else
    echo "Adding prefer-builder-proposals flag"
    validator_args+=(
      --builder-boost-factor $((RANDOM % 100 + 1))
    )
  fi

  mock-builder "${mock_builder_args[@]}" > /data/logs/"service_$CONTAINER_NAME--builder" 2>&1 &
fi



lighthouse --testnet-dir="$COLLECTION_DIR" bn "${beacon_args[@]}" > /data/logs/"service_$CONTAINER_NAME--bn" 2>&1 &

sleep 10
echo "Launching Lighthouse validator client in ${CONTAINER_NAME}"
lighthouse --testnet-dir="$COLLECTION_DIR" vc "${validator_args[@]}" > /data/logs/"service_$CONTAINER_NAME--vc" 2>&1
