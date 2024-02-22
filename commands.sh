#!/bin/bash


#
curl -X POST "http://localhost:8080/api/v1/test_run" -H "Content-Type: application/json" -d '{ "test_id": "external-1", "config": {}, "allow_duplicate": false }'

# change prysm log level
docker compose exec prysm-geth-0 curl -X POST "http://localhost:5000/eth/v1alpha1/debug/logging?level=1" -H "accept: application/json"