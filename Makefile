.PHONY: clean

REPO_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

log_level ?= "info"
# Build ethereum-testnet-bootstrapper image
build-bootstrapper:
	docker build -t ethereum-testnet-bootstrapper -f bootstrapper.Dockerfile .
rebuild-bootstrapper:
	docker build --no-cache -t ethereum-testnet-bootstrapper -f bootstrapper.Dockerfile .

build-config:
	docker build -t etb-mainnet-config -f config.Dockerfile .

rebuild-config:
	docker build --no-cache --build-arg="CONFIG_PATH=$(config)" -t etb-mainnet-config -f config.Dockerfile .

# Build the etb-all-clients images:
build-client-images:
	cd deps/dockers && ./build-dockers.sh

build-client-images-inst:
	cd deps/dockers && ./build-dockers-inst.sh

# a rebuild uses --no-cache in the docker build step.
rebuild-client-images:
	cd deps/dockers && REBUILD_IMAGES=1 ./build-dockers.sh

rebuild-client-images-inst:
	cd deps/dockers && REBUILD_IMAGES=1 ./build-dockers-inst.sh

build-all-images: build-bootstrapper build-client-images build-config
rebuild-all-images: rebuild-bootstrapper rebuild-client-images rebuild-config

# remove last run.
clean:
	rm -rf docker-compose.yaml data/
	mkdir -p data

# init the testnet dirs and all files needed to later bootstrap the testnet.
init-testnet: clean
	docker run -v $(REPO_DIR)/:/source/ -v $(REPO_DIR)/data/:/data ethereum-testnet-bootstrapper --config $(config) --init-testnet --log-level $(log_level)

# get an interactive shell into the testnet-bootstrapper
shell:
	docker run --rm --entrypoint /bin/bash -it -v $(REPO_DIR)/:/source/ -v $(REPO_DIR)/data/:/data ethereum-testnet-bootstrapper

# after an init this runs the bootstrapper and start up the testnet.
run-bootstrapper:
	docker run -it -v $(REPO_DIR)/:/source/ -v $(REPO_DIR)/data/:/data ethereum-testnet-bootstrapper --config $(config) --bootstrap-testnet --log-level $(log_level)

