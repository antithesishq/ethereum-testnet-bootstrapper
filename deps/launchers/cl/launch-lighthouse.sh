#!/bin/bash

env_vars=(
  "CONSENSUS_BEACON_API_PORT"
  "CONSENSUS_BEACON_METRIC_PORT"
  "CONSENSUS_BEACON_RPC_PORT"
  "CONSENSUS_BOOTNODE_FILE"
  "CONSENSUS_CHECKPOINT_FILE"
  "CONSENSUS_CLIENT"
  "CONSENSUS_CONFIG_FILE"
  "CONSENSUS_GENESIS_FILE"
  "CONSENSUS_GRAFFITI"
  "CONSENSUS_NODE_DIR"
  "CONSENSUS_P2P_PORT"
  "CONSENSUS_VALIDATOR_METRIC_PORT"
  "CONSENSUS_VALIDATOR_RPC_PORT"
  "IP_ADDRESS"
  "IP_SUBNET"
  "JWT_SECRET_FILE"
  "TESTNET_DIR"
  "NUM_CLIENT_NODES"
  "EXECUTION_ENGINE_HTTP_PORT"
  "EXECUTION_ENGINE_WS_PORT"
)
# verify vars we need are set and available.
for var in "${env_vars[@]}" ; do
    if [[ -z "${!var}" ]]; then
        echo "Lighthouse error in geth var check."
        echo "$var not set"
        exit 1
    fi
done

# we can wait for the bootnode enr to drop before we get the signal to start up.
while [ ! -f "$CONSENSUS_BOOTNODE_FILE" ]; do
  echo "consensus client waiting for bootnode enr file: $CONSENSUS_BOOTNODE_FILE"
  sleep 1
done

bootnode_enr=`cat $CONSENSUS_BOOTNODE_FILE`

while [ ! -f "$CONSENSUS_CHECKPOINT_FILE" ]; do
  echo "Waiting for consensus checkpoint file: $CONSENSUS_CHECKPOINT_FILE"
    sleep 1
done

echo "Launching lighthouse."

lighthouse \
      --testnet-dir="$TESTNET_DIR" \
      bn \
      --datadir="$CONSENSUS_NODE_DIR" \
      --staking \
      --http-address=0.0.0.0 \
      --http-port="$CONSENSUS_BEACON_API_PORT" \
      --http-allow-origin="*" \
      --http-allow-sync-stalled \
      --listen-address=0.0.0.0 \
      --execution-endpoints="http://127.0.0.1:$EXECUTION_ENGINE_HTTP_PORT" \
      --enable-private-discovery \
      --enr-address "$IP_ADDRESS" \
      --enr-udp-port "$CONSENSUS_P2P_PORT" \
      --enr-tcp-port "$CONSENSUS_P2P_PORT" \
      --discovery-port "$CONSENSUS_P2P_PORT" \
      --jwt-secrets="$JWT_SECRET_FILE" \
      --boot-nodes="$bootnode_enr" \
      --target-peers="$NUM_CLIENT_NODES" \
      --suggested-fee-recipient=0x00000000219ab540356cbb839cbe05303d7705fa &

#lighthouse \
#  --logfile="$CONSENSUS_NODE_DIR/beacon.log" \
#  --logfile-debug-level="$LIGHTHOUSE_DEBUG_LEVEL" \
#	--debug-level="$LIGHTHOUSE_DEBUG_LEVEL" \
#	--datadir="$CONSENSUS_NODE_DIR" \
#	--testnet-dir="$TESTNET_DIR" \
#	bn \
#  --disable-enr-auto-update \
#	--enr-address "$IP_ADDRESS" \
#	--enr-udp-port "$CONSENSUS_P2P_PORT" \
#	--enr-tcp-port "$CONSENSUS_P2P_PORT" \
#	--port="$CONSENSUS_P2P_PORT" \
#	--discovery-port "$CONSENSUS_P2P_PORT" \
#  --eth1 \
#	--http \
#	--http-address=0.0.0.0 \
#	--http-port="$CONSENSUS_BEACON_API_PORT" \
#  --http-allow-origin="*" \
#  --metrics \
#  --metrics-address=0.0.0.0 \
#  --metrics-port="$CONSENSUS_BEACON_METRIC_PORT" \
#  --metrics-allow-origin="*" \
#  --listen-address=0.0.0.0 \
#  --graffiti="$CONSENSUS_GRAFFITI" \
#  --target-peers="$CONSENSUS_TARGET_PEERS" \
#  --http-allow-sync-stalled \
#  --disable-packet-filter \
#  --validator-monitor-auto \
#  --enable-private-discovery \
#  --execution-endpoints="http://127.0.0.1:$EXECUTION_ENGINE_HTTP_PORT" \
#  --jwt-secrets="$JWT_SECRET_FILE" \
#  --suggested-fee-recipient=0x00000000219ab540356cbb839cbe05303d7705fa \
#  --subscribe-all-subnets &

sleep 10
lighthouse \
      --testnet-dir="$TESTNET_DIR" \
      vc \
      --validators-dir "$CONSENSUS_NODE_DIR/keys" \
      --secrets-dir "$CONSENSUS_NODE_DIR/secrets" \
      --init-slashing-protection \
      --beacon-nodes="http://127.0.0.1:$CONSENSUS_BEACON_API_PORT" \
      --graffiti="$CONSENSUS_GRAFFITI" \
      --http --http-port="$CONSENSUS_VALIDATOR_RPC_PORT" \
      --suggested-fee-recipient=0x00000000219ab540356cbb839cbe05303d7705fa \
      --logfile="$CONSENSUS_NODE_DIR/validator.log" --logfile-debug-level="$LIGHTHOUSE_DEBUG_LEVEL"