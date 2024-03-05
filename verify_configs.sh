#!/bin/bash

base_path="./configs/clients/"
config_files=(
    "mainnet-deneb-prysm-geth-assertoor.yaml"
    "mainnet-deneb-prysm-geth-assertoor-race.yaml"
    "mainnet-deneb-prysm-nethermind-assertoor.yaml"
    "mainnet-deneb-lighthouse-nethermind-assertoor.yaml"
    "mainnet-deneb-lighthouse-geth-assertoor.yaml"
    "mainnet-deneb-lodestar-besu-assertoor.yaml"
    "mainnet-deneb-grandine-reth-assertoor.yaml"
    "mainnet-deneb-nimbus-reth-assertoor.yaml"
    "mainnet-deneb-teku-besu-assertoor.yaml"
    "mainnet-deneb-mix-1.yaml"
    "mainnet-deneb-mix-2.yaml"
    "mainnet-deneb-mix-3.yaml"
    "mainnet-deneb-mix-4.yaml"
)

declare -A statuses  # Use a clearer name for the associative array

for file in "${config_files[@]}"; do

    make -s init-testnet config="$base_path$file"
    docker -l error compose up -d  # Use docker-compose as a single command
    
    end_time=$((SECONDS + 220))  # 5 minutes from now

    while (( SECONDS < end_time )); do
        if [ "$(curl -s http://localhost:8080/api/v1/test_runs | jq -e '.data[0].status == "success"')" = "true" ]; then            statuses["$file"]="success"  # Store success status
            break
        fi
        sleep 10
    done

    if [ "${statuses[$file]}" != "success" ]; then
        statuses["$file"]="failed"  # Explicitly mark as failed if not successful
        echo "Test failed for $file"
        docker compose down
        make clean
        exit 1
    fi

    echo "Test for $file: ${statuses[$file]}"

    docker -l error compose down
    make -s clean
done

# Output key-value pairs of statuses
for file in "${config_files[@]}"; do
    echo "$file: ${statuses[$file]}"
done
