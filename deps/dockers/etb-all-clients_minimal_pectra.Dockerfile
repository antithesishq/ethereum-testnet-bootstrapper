###############################################################################
#           Dockerfile to build all clients mainnet preset.           #
###############################################################################
# Consensus Clients  
ARG LIGHTHOUSE_REPO="https://github.com/sigp/lighthouse"
ARG LIGHTHOUSE_BRANCH="v5.1.3" 

ARG GRANDINE_REPO="https://github.com/grandinetech/grandine.git"
ARG GRANDINE_BRANCH="0.4.1"
# debug branch

ARG PRYSM_REPO="https://github.com/prysmaticlabs/prysm.git"
ARG PRYSM_BRANCH="v5.0.3"

ARG LODESTAR_REPO="https://github.com/ChainSafe/lodestar.git"
ARG LODESTAR_BRANCH="v1.18.1"

ARG NIMBUS_ETH2_REPO="https://github.com/status-im/nimbus-eth2.git"
ARG NIMBUS_ETH2_BRANCH="v24.4.0"

ARG TEKU_REPO="https://github.com/ConsenSys/teku.git"
ARG TEKU_BRANCH="24.4.0"

# Execution Clients
ARG BESU_REPO="https://github.com/hyperledger/besu.git"
ARG BESU_BRANCH="24.5.1"

ARG GETH_REPO="https://github.com/ethereum/go-ethereum.git"
ARG GETH_BRANCH="v1.14.3"

ARG NETHERMIND_REPO="https://github.com/NethermindEth/nethermind.git"
ARG NETHERMIND_BRANCH="1.26.0"

ARG RETH_REPO="https://github.com/paradigmxyz/reth"
ARG RETH_BRANCH="v0.2.0-beta.6"

ARG TX_FUZZ_REPO="https://github.com/MariusVanDerWijden/tx-fuzz"
ARG TX_FUZZ_BRANCH="cbe8f24a510ab7d89363df9b6dfb4d297a698a7c"

# Metrics gathering
ARG BEACON_METRICS_GAZER_REPO="https://github.com/qu0b/beacon-metrics-gazer.git"
ARG BEACON_METRICS_GAZER_BRANCH="11b4b5491da1e451c7f664a64a6ab57231f45714"

# Mock builder for testing builder API
ARG MOCK_BUILDER_REPO="https://github.com/marioevz/mock-builder.git"
ARG MOCK_BUILDER_BRANCH="v1.2.0"

ARG ASSERTOR_REPO="https://github.com/ethpandaops/assertoor"
ARG ASSERTOR_BRANCH="v0.0.9"

ARG JSON_RPC_SNOOP_REPO="https://github.com/ethDreamer/json_rpc_snoop.git"
ARG JSON_RPC_SNOOP_BRANCH="master"

###############################################################################
# Builder to build all of the clients.
FROM debian:stable-slim AS etb-client-builder

# Antithesis dependencies for creating instrumented binaries
COPY instrumentation/lib/libvoidstar.so /usr/lib/libvoidstar.so
RUN mkdir -p /opt/antithesis/
COPY instrumentation/go_instrumentation /opt/antithesis/go_instrumentation
RUN /opt/antithesis/go_instrumentation/bin/goinstrumentor -version


# build deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    libpcre3-dev \
    lsb-release \
    software-properties-common \
    apt-transport-https \
    openjdk-17-jdk \
    ca-certificates \
    wget \
    tzdata \
    bash \
    python3-dev \
    make \
    g++ \
    gnupg \
    cmake \
    libc6 \
    libc6-dev \
    libsnappy-dev \
    gradle \
    pkg-config \
    libssl-dev \
    git \
    git-lfs \
    librocksdb7.8 \
    libclang-dev

# set up dotnet (nethermind)
RUN wget https://dot.net/v1/dotnet-install.sh -O dotnet-install.sh && \
    chmod +x dotnet-install.sh && \
    ./dotnet-install.sh --channel 8.0
ENV PATH="$PATH:/root/.dotnet/"

VOLUME /git

WORKDIR /git

# set up clang 15 (nimbus+lighthouse+deps)
RUN wget --no-check-certificate https://apt.llvm.org/llvm.sh && chmod +x llvm.sh && ./llvm.sh 15
ENV LLVM_CONFIG=llvm-config-15

# set up go (geth+prysm)
RUN arch=$(arch | sed s/aarch64/arm64/ | sed s/x86_64/amd64/) && \
    wget https://go.dev/dl/go1.21.5.linux-${arch}.tar.gz

RUN arch=$(arch | sed s/aarch64/arm64/ | sed s/x86_64/amd64/) && \
    tar -zxvf go1.21.5.linux-${arch}.tar.gz -C /usr/local/

RUN ln -s /usr/local/go/bin/go /usr/local/bin/go && \
    ln -s /usr/local/go/bin/gofmt /usr/local/bin/gofmt

ENV PATH="$PATH:/root/go/bin"

# setup nodejs (lodestar)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
apt-get install -y nodejs

RUN npm install -g @bazel/bazelisk # prysm build system

# setup cargo/rustc (lighthouse)
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- --default-toolchain stable -y
ENV PATH="$PATH:/root/.cargo/bin"

RUN apt install -y protobuf-compiler libprotobuf-dev # protobuf compiler for lighthouse
RUN ln -s /usr/local/bin/python3 /usr/local/bin/python
RUN npm install --global yarn
############################# Consensus  Clients  #############################

# LIGHTHOUSE
FROM etb-client-builder AS lighthouse-builder
ARG LIGHTHOUSE_BRANCH
ARG LIGHTHOUSE_REPO
# Check if the directory exists
RUN git clone "${LIGHTHOUSE_REPO}"; \
    cd lighthouse && git checkout "${LIGHTHOUSE_BRANCH}"; \
    git log -n 1 --format=format:"%H" > /lighthouse.version

RUN cd lighthouse && \
    cargo update -p proc-macro2 && \
    cargo build --release --bin lighthouse

# LIGHTHOUSE INSTRUMENTED
#FROM etb-client-builder AS lighthouse-builder-inst
#ARG LIGHTHOUSE_BRANCH
#ARG LIGHTHOUSE_REPO
## Check if the directory exists
#RUN  git clone "${LIGHTHOUSE_REPO}"; \
#     cd lighthouse && git checkout "${LIGHTHOUSE_BRANCH}"; \
#     git log -n 1 --format=format:"%H" > /lighthouse.version
#
## Antithesis instrumented lighthouse binary
# RUN cd lighthouse && LD_LIBRARY_PATH=/usr/lib/ RUSTFLAGS="-Cpasses=sancov-module -Cllvm-args=-sanitizer-coverage-level=3 -Cllvm-args=-sanitizer-coverage-trace-pc-guard -Ccodegen-units=1 -Cdebuginfo=2 -L/usr/lib/ -lvoidstar"  cargo build --release --manifest-path lighthouse/Cargo.toml --bin lighthouse

# GRANDINE
FROM etb-client-builder AS grandine-builder
ARG GRANDINE_BRANCH
ARG GRANDINE_REPO
# Check if the directory exists
RUN git clone "${GRANDINE_REPO}"; \
    cd grandine && git checkout "${GRANDINE_BRANCH}"; \
    git submodule update --init dedicated_executor eth2_libp2p; \
    git log -n 1 --format=format:"%H" > /grandine.version

RUN cd grandine && \
    cargo build --release --features default-networks --bin grandine

## GRANDINE INSTRUMENTED
#FROM etb-client-builder AS grandine-builder-inst
#ARG GRANDINE_BRANCH
#ARG GRANDINE_REPO
## Check if the directory exists
#RUN  git clone "${GRANDINE_REPO}"; \
#     cd grandine && git checkout "${GRANDINE_BRANCH}"; \
#     git submodule update --init dedicated_executor eth2_libp2p; \
#     git log -n 1 --format=format:"%H" > /grandine.version
#
## Antithesis instrumented grandine binary
# RUN cd grandine && LD_LIBRARY_PATH=/usr/lib/ RUSTFLAGS="-Cpasses=sancov-module -Cllvm-args=-sanitizer-coverage-level=3 -Cllvm-args=-sanitizer-coverage-trace-pc-guard -Ccodegen-units=1 -Cdebuginfo=2 -L/usr/lib/ -lvoidstar"  cargo build --release --features default-networks --bin grandine

# LODESTAR
FROM etb-client-builder AS lodestar-builder
ARG LODESTAR_BRANCH
ARG LODESTAR_REPO
RUN git clone "${LODESTAR_REPO}"; \
    cd lodestar && git checkout "${LODESTAR_BRANCH}"; \
    git log -n 1 --format=format:"%H" > /lodestar.version

RUN cd lodestar && \
    yarn install --non-interactive --frozen-lockfile && \
    yarn build && \
    yarn install --non-interactive --frozen-lockfile --production

# NIMBUS
FROM etb-client-builder AS nimbus-eth2
ARG NIMBUS_ETH2_BRANCH
ARG NIMBUS_ETH2_REPO
RUN git clone "${NIMBUS_ETH2_REPO}"; \
    cd nimbus-eth2 && git checkout "${NIMBUS_ETH2_BRANCH}"; \
    git log -n 1 --format=format:"%H" > /nimbus.version

FROM nimbus-eth2 AS nimbus-eth2-builder
ARG NIMBUS_ETH2_BRANCH
ARG NIMBUS_ETH2_REPO
RUN cd nimbus-eth2 && \
    make -j32 update && \
    arch=$(arch | sed s/aarch64/arm64/ | sed s/x86_64/amd64/) && \
    make -j32 nimbus_beacon_node NIMFLAGS="-d:disableMarchNative --cpu:${arch} --cc:clang --clang.exe:clang-15 --clang.linkerexe:clang-15 --passC:-fno-lto --passL:-fno-lto"

FROM nimbus-eth2 AS nimbus-minimal-eth2-builder
ARG NIMBUS_ETH2_BRANCH
ARG NIMBUS_ETH2_REPO
RUN cd nimbus-eth2 && \
    make -j32 update && \
    arch=$(arch | sed s/aarch64/arm64/ | sed s/x86_64/amd64/) && \
    make -j32 nimbus_beacon_node NIMFLAGS="-d:disableMarchNative -d:const_preset=minimal --cpu:${arch} --cc:clang --clang.exe:clang-15 --clang.linkerexe:clang-15 --passC:-fno-lto --passL:-fno-lto"


# TEKU
FROM etb-client-builder AS teku-builder
ARG TEKU_BRANCH
ARG TEKU_REPO

RUN git clone "${TEKU_REPO}"; \
    cd teku && git checkout "${TEKU_BRANCH}"; \
    git log -n 1 --format=format:"%H" > /teku.version


RUN cd teku && \
    ./gradlew --parallel installDist

# PRYSM
FROM etb-client-builder AS prysm-builder
ARG PRYSM_BRANCH
ARG PRYSM_REPO
RUN git clone "${PRYSM_REPO}"; \
    cd prysm && git checkout "${PRYSM_BRANCH}"; \
    git log -n 1 --format=format:"%H" > /prysm.version

FROM prysm-builder AS prysm
RUN cd prysm && \
    bazelisk build --config=release //cmd/beacon-chain:beacon-chain //cmd/validator:validator

FROM prysm-builder AS prysm-minimal
RUN cd prysm && \
    bazelisk build --config=minimal //cmd/beacon-chain:beacon-chain //cmd/validator:validator

FROM prysm-builder AS prysm-race
RUN cd prysm && \
    bazelisk build --config=release --@io_bazel_rules_go//go/config:race //cmd/beacon-chain:beacon-chain //cmd/validator:validator

FROM prysm-builder AS prysm-minimal-race
RUN cd prysm && \
    bazelisk build --config=minimal --@io_bazel_rules_go//go/config:race //cmd/beacon-chain:beacon-chain //cmd/validator:validator

# PRYSM INSTRUMENTED
FROM prysm-builder AS prysm-inst
RUN cd prysm && \
    bazelisk build --config=release --@io_bazel_rules_go//go/config:race //cmd/beacon-chain:beacon-chain //cmd/validator:validator

RUN mkdir -p prysm_instrumented

RUN /opt/antithesis/go_instrumentation/bin/goinstrumentor \
    -logtostderr -stderrthreshold=INFO \
    -antithesis /opt/antithesis/go_instrumentation/instrumentation/go/wrappers \
    prysm prysm_instrumented 

RUN cd prysm_instrumented/customer && go build -o /tmp/validator ./cmd/validator
RUN cd prysm_instrumented/customer && go build -o /tmp/beacon-chain ./cmd/beacon-chain

############################# Execution  Clients  #############################
# Geth
FROM etb-client-builder AS geth-builder
ARG GETH_BRANCH
ARG GETH_REPO
RUN        git clone "${GETH_REPO}"; \
       cd go-ethereum && git checkout "${GETH_BRANCH}"; \
   git log -n 1 --format=format:"%H" > /geth.version

FROM geth-builder AS geth
RUN cd go-ethereum && \
    make geth

FROM geth-builder as geth-race
RUN cd go-ethereum && \
    go install -race -ldflags "-extldflags '-Wl,-z,stack-size=0x800000'" -tags urfave_cli_no_docs,ckzg -trimpath ./cmd/geth


# Geth instrumented
FROM geth-builder AS geth-inst
RUN cd go-ethereum && \
    make geth

# Antithesis add instrumentation
RUN mkdir geth_instrumented

RUN /opt/antithesis/go_instrumentation/bin/goinstrumentor \
    -logtostderr -stderrthreshold=INFO \
    -antithesis /opt/antithesis/go_instrumentation/instrumentation/go/wrappers \
    go-ethereum geth_instrumented

RUN cd geth_instrumented/customer && \
    go install -race -ldflags "-extldflags '-Wl,-z,stack-size=0x800000'" -tags urfave_cli_no_docs,ckzg -trimpath ./cmd/geth

# Besu
FROM etb-client-builder AS besu-builder
ARG BESU_BRANCH
ARG BESU_REPO
RUN git clone "${BESU_REPO}"; \
    cd besu && git checkout "${BESU_BRANCH}"; \
    git log -n 1 --format=format:"%H" > /besu.version

RUN cd besu && \
    ./gradlew --parallel installDist

# Nethermind
FROM etb-client-builder AS nethermind-builder
ARG NETHERMIND_BRANCH
ARG NETHERMIND_REPO
RUN git clone "${NETHERMIND_REPO}"; \
    cd nethermind && git checkout "${NETHERMIND_BRANCH}"; \
    git log -n 1 --format=format:"%H" > /nethermind.version

RUN cd nethermind && \
    dotnet publish -p:PublishReadyToRun=false src/Nethermind/Nethermind.Runner -c release -o out

# RETH
FROM etb-client-builder AS reth-builder
ARG RETH_BRANCH
ARG RETH_REPO
RUN git clone "${RETH_REPO}"; \
    cd reth && git checkout "${RETH_BRANCH}"; \
    git log -n 1 --format=format:"%H" > /reth.version

RUN cd reth && \
    cargo build --release

# RETH INSTRUMENTED
#FROM etb-client-builder AS reth-builder-inst
#ARG RETH_BRANCH
#ARG RETH_REPO
#RUN  git clone "${RETH_REPO}"; \
#     cd reth && git checkout "${RETH_BRANCH}"; \
#     git log -n 1 --format=format:"%H" > /reth.version
#
## Antithesis reth lighthouse binary
# RUN cd reth && LD_LIBRARY_PATH=/usr/lib/ RUSTFLAGS="-Cpasses=sancov-module -Cllvm-args=-sanitizer-coverage-level=3 -Cllvm-args=-sanitizer-coverage-trace-pc-guard -Ccodegen-units=1 -Cdebuginfo=2 -L/usr/lib/ -lvoidstar"  cargo build --release --bin reth

############################### Misc.  Modules  ###############################
FROM etb-client-builder AS misc-builder
ARG TX_FUZZ_BRANCH
ARG TX_FUZZ_REPO
ARG BEACON_METRICS_GAZER_REPO
ARG BEACON_METRICS_GAZER_BRANCH
ARG JSON_RPC_SNOOP_REPO
ARG JSON_RPC_SNOOP_BRANCH

RUN go install github.com/wealdtech/ethereal/v2@latest
RUN go install github.com/wealdtech/ethdo@v1.35.2
RUN go install github.com/protolambda/eth2-val-tools@latest

#RUN git clone --depth 1 --single-branch --branch "${TX_FUZZ_BRANCH}" "${TX_FUZZ_REPO}" && \
RUN git clone "${TX_FUZZ_REPO}"; \
    cd tx-fuzz && git checkout "${TX_FUZZ_BRANCH}"; \
    cd cmd/livefuzzer && go build

#RUN git clone --depth 1 --single-branch --branch "${BEACON_METRICS_GAZER_BRANCH}" "${BEACON_METRICS_GAZER_REPO}" && \
RUN git clone "${BEACON_METRICS_GAZER_REPO}"; \
    cd beacon-metrics-gazer && git checkout "${BEACON_METRICS_GAZER_BRANCH}"; \
    git log -n 1 --format=format:"%H" > /beacon-metrics-gazer.version

RUN cd beacon-metrics-gazer && \
    cargo update -p proc-macro2 && \
    cargo build --release

RUN git clone "${JSON_RPC_SNOOP_REPO}" && \
    cd json_rpc_snoop && \
    git checkout "${JSON_RPC_SNOOP_BRANCH}"

RUN cd json_rpc_snoop && \
    make

RUN cargo install jwt-cli

ARG MOCK_BUILDER_REPO
ARG MOCK_BUILDER_BRANCH

RUN git clone "${MOCK_BUILDER_REPO}"; \
    cd mock-builder && git checkout "${MOCK_BUILDER_BRANCH}"; \
    git log -n 1 --format=format:"%H" > /mock-builder.version

RUN cd mock-builder && \
    go build .

ARG ASSERTOR_REPO
ARG ASSERTOR_BRANCH

RUN git clone "${ASSERTOR_REPO}"; \
    cd assertoor && git checkout "${ASSERTOR_BRANCH}"; \
    git log -n 1 --format=format:"%H" > /assertoor.version

RUN cd assertoor && \
    make build

########################### etb-all-clients runner  ###########################
FROM debian:stable-slim

# Antithesis instrumentation files
COPY instrumentation/lib/libvoidstar.so /usr/lib/libvoidstar.so
RUN mkdir -p /opt/antithesis/
COPY instrumentation/go_instrumentation /opt/antithesis/go_instrumentation
RUN /opt/antithesis/go_instrumentation/bin/goinstrumentor -version


WORKDIR /git

RUN mkdir -p /opt/antithesis/instrumented/bin
RUN mkdir -p /opt/antithesis/race/bin
RUN mkdir -p /opt/antithesis/minimal/bin
RUN mkdir -p /opt/antithesis/minimal/race/bin
RUN mkdir -p /opt/antithesis/minimal/instrumented/bin


RUN apt update && apt install curl ca-certificates -y --no-install-recommends \
    wget \
    lsb-release \
    software-properties-common

RUN wget https://dot.net/v1/dotnet-install.sh -O dotnet-install.sh && \
    chmod +x dotnet-install.sh && \
    ./dotnet-install.sh --channel 8.0

ENV PATH="$PATH:/root/.dotnet/"
ENV DOTNET_ROOT=/root/.dotnet

RUN apt-get update && apt-get install -y --no-install-recommends \
    librocksdb7.8 \
    openjdk-17-jdk \
    python3-dev \
    python3-pip \
    jq \
    xxd

RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
apt-get install -y nodejs

RUN pip3 install --break-system-packages ruamel.yaml web3 pydantic

# for coverage artifacts and runtime libraries.
RUN wget --no-check-certificate https://apt.llvm.org/llvm.sh && \
    chmod +x llvm.sh && \
    ./llvm.sh 15

ENV LLVM_CONFIG=llvm-config-15

# misc tools used in etb
COPY --from=misc-builder /root/go/bin/ethereal /usr/local/bin/ethereal
COPY --from=misc-builder /root/go/bin/ethdo /usr/local/bin/ethdo
COPY --from=misc-builder /root/go/bin/eth2-val-tools /usr/local/bin/eth2-val-tools
# tx-fuzz
COPY --from=misc-builder /git/tx-fuzz/cmd/livefuzzer/livefuzzer /usr/local/bin/livefuzzer
# beacon-metrics-gazer
COPY --from=misc-builder /git/beacon-metrics-gazer/target/release/beacon-metrics-gazer /usr/local/bin/beacon-metrics-gazer

COPY --from=misc-builder /git/json_rpc_snoop/target/release/json_rpc_snoop /usr/local/bin/json_rpc_snoop

COPY --from=misc-builder /root/.cargo/bin/jwt /usr/local/bin/jwt
# mock-builder
COPY --from=misc-builder /git/mock-builder/mock-builder /usr/local/bin/mock-builder

#assertoor
COPY --from=misc-builder /git/assertoor/bin/assertoor /usr/local/bin/assertoor

# consensus clients
COPY --from=nimbus-eth2-builder /git/nimbus-eth2/build/nimbus_beacon_node /usr/local/bin/nimbus_beacon_node
COPY --from=nimbus-eth2-builder /nimbus.version /nimbus.version

COPY --from=nimbus-minimal-eth2-builder /git/nimbus-eth2/build/nimbus_beacon_node /opt/antithesis/minimal/bin/nimbus_beacon_node

COPY --from=lighthouse-builder /lighthouse.version /lighthouse.version
COPY --from=lighthouse-builder /git/lighthouse/target/release/lighthouse /usr/local/bin/lighthouse

#COPY --from=lighthouse-builder-inst /git/lighthouse/target/release/lighthouse /opt/antithesis/instrumented/bin/lighthouse

COPY --from=grandine-builder /grandine.version /grandine.version
COPY --from=grandine-builder /git/grandine/target/release/grandine /usr/local/bin/grandine

#COPY --from=grandine-builder-inst /git/grandine/target/release/grandine /opt/antithesis/instrumented/bin/grandine

COPY --from=teku-builder  /git/teku/build/install/teku/. /opt/teku
COPY --from=teku-builder /teku.version /teku.version
RUN ln -s /opt/teku/bin/teku /usr/local/bin/teku

# execution clients
COPY --from=geth /geth.version /geth.version
COPY --from=geth /git/go-ethereum/build/bin/geth /usr/local/bin/geth

COPY --from=geth-race /root/go/bin/geth /opt/antithesis/race/bin/geth

COPY --from=geth-inst /root/go/bin/geth /opt/antithesis/instrumented/bin/geth
COPY --from=geth-inst /git/geth_instrumented/symbols/* /opt/antithesis/symbols/
COPY --from=geth-inst /git/geth_instrumented/customer /geth_instrumented_code

COPY --from=prysm /git/prysm/bazel-bin/cmd/beacon-chain/beacon-chain_/beacon-chain /usr/local/bin/beacon-chain
COPY --from=prysm /git/prysm/bazel-bin/cmd/validator/validator_/validator /usr/local/bin/validator
COPY --from=prysm-minimal /git/prysm/bazel-bin/cmd/beacon-chain/beacon-chain_/beacon-chain /opt/antithesis/minimal/bin/beacon-chain
COPY --from=prysm-minimal /git/prysm/bazel-bin/cmd/validator/validator_/validator /opt/antithesis/minimal/bin/validator


COPY --from=prysm-race /git/prysm/bazel-bin/cmd/beacon-chain/beacon-chain_/beacon-chain /opt/antithesis/race/bin/beacon-chain
COPY --from=prysm-race /git/prysm/bazel-bin/cmd/validator/validator_/validator /opt/antithesis/race/bin/validator
COPY --from=prysm-minimal-race /git/prysm/bazel-bin/cmd/beacon-chain/beacon-chain_/beacon-chain /opt/antithesis/minimal/race/bin/beacon-chain
COPY --from=prysm-minimal-race /git/prysm/bazel-bin/cmd/validator/validator_/validator /opt/antithesis/minimal/race/bin/validator

COPY --from=prysm-inst /prysm.version /prysm.version
COPY --from=prysm-inst /tmp/beacon-chain /opt/antithesis/instrumented/bin/beacon-chain
COPY --from=prysm-inst /tmp/validator /opt/antithesis/instrumented/bin/validator
COPY --from=prysm-inst /git/prysm_instrumented/symbols/* /opt/antithesis/symbols/
COPY --from=prysm-inst /git/prysm_instrumented/customer /prysm_instrumented_code
#
COPY --from=lodestar-builder /git/lodestar /git/lodestar
COPY --from=lodestar-builder /lodestar.version /lodestar.version
RUN ln -s /git/lodestar/node_modules/.bin/lodestar /usr/local/bin/lodestar

COPY --from=reth-builder /reth.version /reth.version
COPY --from=reth-builder /git/reth/target/release/reth /usr/local/bin/reth

#COPY --from=reth-builder-inst /git/reth/target/release/reth /opt/antithesis/instrumented/bin/reth

COPY --from=besu-builder /besu.version /besu.version
COPY --from=besu-builder /git/besu/build/install/besu/. /opt/besu
RUN ln -s /opt/besu/bin/besu /usr/local/bin/besu

COPY --from=nethermind-builder /nethermind.version /nethermind.version
COPY --from=nethermind-builder /git/nethermind/out /nethermind/
RUN ln -s /nethermind/nethermind /usr/local/bin/nethermind