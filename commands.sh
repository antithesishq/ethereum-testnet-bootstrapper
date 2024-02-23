#!/bin/bash


curl -X POST "http://localhost:8080/api/v1/test_run" -H "Content-Type: application/json" -d '{ "test_id": "external-7", "config": {}, "allow_duplicate": false }'

# change prysm log level
docker compose exec prysm-geth-0 curl -X POST "http://localhost:5000/eth/v1alpha1/debug/logging?level=1" -H "accept: application/json"

docker compose exec prysm-geth-0 curl -s -H "accept: application/json" -X GET "http://localhost:5000/eth/v2/beacon/blocks/head" | jq .data.message.body.execution_payload


curl -X POST "http://localhost:8080/api/v1/test_run" -H "Content-Type: application/json" -d '{ "test_id": "external-7", "allow_duplicate": false }'

curl -X POST "http://localhost:8080/api/v1/test_run/4/cancel" -H "Content-Type: application/json" -d '{ "test_id": "external-8", "run_id": 4 }'
