###############################################################################
#           Dockerfile to build all clients mainnet preset.           #
###############################################################################
# Consensus Clients
ARG LIGHTHOUSE_REPO="https://github.com/sigp/lighthouse"
ARG LIGHTHOUSE_BRANCH="9c1f3a6" 

ARG PRYSM_REPO="https://github.com/prysmaticlabs/prysm.git"
ARG PRYSM_BRANCH="56c65b8527fef4449792e7b593343d193340993e"

ARG LODESTAR_REPO="https://github.com/ChainSafe/lodestar.git"
ARG LODESTAR_BRANCH="v1.11.3"

ARG NIMBUS_ETH2_REPO="https://github.com/status-im/nimbus-eth2.git"
ARG NIMBUS_ETH2_BRANCH="34eade"

ARG TEKU_REPO="https://github.com/ConsenSys/teku.git"
ARG TEKU_BRANCH="d418f8d"

# Execution Clients
ARG BESU_REPO="https://github.com/hyperledger/besu.git"
ARG BESU_BRANCH="f8108878"

ARG GETH_REPO="https://github.com/lightclient/go-ethereum.git"
ARG GETH_BRANCH="4d161dee0c4cb19e7b391b3f0fe4edd139aecbc8"

ARG NETHERMIND_REPO="https://github.com/NethermindEth/nethermind.git"
ARG NETHERMIND_BRANCH="4847b067"

# ARG ETHEREUMJS_REPO="https://github.com/ethereumjs/ethereumjs-monorepo.git"
# ARG ETHEREUMJS_BRANCH="7a0a37b7355c77ce841d5b04da55a2a4b53fe550"

ARG RETH_REPO="https://github.com/paradigmxyz/reth"
ARG ARG RETH_BRANCH="9dd270e"

# All of the fuzzers we will be using
ARG TX_FUZZ_REPO="https://github.com/qu0b/tx-fuzz.git"
ARG TX_FUZZ_BRANCH="22631838d3ffd9f57f4b09e02a4e71686a921414"

# Metrics gathering
ARG BEACON_METRICS_GAZER_REPO="https://github.com/qu0b/beacon-metrics-gazer.git"
ARG BEACON_METRICS_GAZER_BRANCH="master"

# Mock builder for testing builder API
ARG MOCK_BUILDER_REPO="https://github.com/marioevz/mock-builder.git"
ARG MOCK_BUILDER_BRANCH="v1.1.0"

###############################################################################
# Builder to build all of the clients.
FROM debian:bullseye-slim AS etb-client-builder

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
    git-lfs

# set up dotnet (nethermind)
RUN wget https://dot.net/v1/dotnet-install.sh -O dotnet-install.sh && \
    chmod +x dotnet-install.sh && \
    ./dotnet-install.sh --channel 7.0
ENV PATH="$PATH:/root/.dotnet/"

WORKDIR /git

# set up clang 15 (nimbus+lighthouse+deps)
RUN wget --no-check-certificate https://apt.llvm.org/llvm.sh && chmod +x llvm.sh && ./llvm.sh 15
ENV LLVM_CONFIG=llvm-config-15

# set up go (geth+prysm)
RUN arch=$(arch | sed s/aarch64/arm64/ | sed s/x86_64/amd64/) && \
    wget https://go.dev/dl/go1.20.3.linux-${arch}.tar.gz

RUN arch=$(arch | sed s/aarch64/arm64/ | sed s/x86_64/amd64/) && \
    tar -zxvf go1.20.3.linux-${arch}.tar.gz -C /usr/local/

RUN ln -s /usr/local/go/bin/go /usr/local/bin/go && \
    ln -s /usr/local/go/bin/gofmt /usr/local/bin/gofmt


ENV PATH="$PATH:/root/go/bin"

# setup nodejs (lodestar)
RUN apt update \
    && apt install curl ca-certificates -y --no-install-recommends \
    && curl -sL https://deb.nodesource.com/setup_18.x | bash -

RUN apt-get update && apt-get install -y --no-install-recommends nodejs
RUN npm install -g npm@latest
RUN npm install -g @bazel/bazelisk # prysm build system

# setup cargo/rustc (lighthouse)
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- --default-toolchain stable -y
ENV PATH="$PATH:/root/.cargo/bin"
# Build rocksdb
RUN git clone --depth=1 https://github.com/facebook/rocksdb.git
RUN cd rocksdb && make -j4 install

RUN apt install -y protobuf-compiler libprotobuf-dev # protobuf compiler for lighthouse
RUN ln -s /usr/local/bin/python3 /usr/local/bin/python
RUN npm install --global yarn
############################# Consensus  Clients  #############################

# LIGHTHOUSE
FROM etb-client-builder AS lighthouse-builder
ARG LIGHTHOUSE_BRANCH
ARG LIGHTHOUSE_REPO
RUN git clone "${LIGHTHOUSE_REPO}" && \
    cd lighthouse && \
    git checkout "${LIGHTHOUSE_BRANCH}" && \
    git log -n 1 --format=format:"%H" > /lighthouse.version

RUN cd lighthouse && \
    cargo update -p proc-macro2 && \
    cargo build --release --manifest-path lighthouse/Cargo.toml --bin lighthouse && \
    mv target/release/lighthouse target/release/lighthouse_uninstrumented

# Antithesis instrumented lighthouse binary
RUN cd lighthouse && \ 
LD_LIBRARY_PATH=/usr/lib/ RUSTFLAGS="-Cpasses=sancov-module -Cllvm-args=-sanitizer-coverage-level=3 -Cllvm-args=-sanitizer-coverage-trace-pc-guard -Ccodegen-units=1 -Cdebuginfo=2 -L/usr/lib/ -lvoidstar" cargo build --release --manifest-path lighthouse/Cargo.toml --bin lighthouse

# LODESTAR
FROM etb-client-builder AS lodestar-builder
ARG LODESTAR_BRANCH
ARG LODESTAR_REPO
RUN git clone "${LODESTAR_REPO}" && \
    cd lodestar && \
    git checkout "${LODESTAR_BRANCH}" && \
    git log -n 1 --format=format:"%H" > /lodestar.version

RUN cd lodestar && \
    yarn install --non-interactive --frozen-lockfile && \
    yarn build && \
    yarn install --non-interactive --frozen-lockfile --production

# NIMBUS
FROM etb-client-builder AS nimbus-eth2-builder
ARG NIMBUS_ETH2_BRANCH
ARG NIMBUS_ETH2_REPO
RUN git clone "${NIMBUS_ETH2_REPO}" && \
    cd nimbus-eth2 && \
    git checkout "${NIMBUS_ETH2_BRANCH}" && \
    git log -n 1 --format=format:"%H" > /nimbus.version && \
    make -j16 update

RUN cd nimbus-eth2 && \
    arch=$(arch | sed s/aarch64/arm64/ | sed s/x86_64/amd64/) && \
    make -j16 nimbus_beacon_node NIMFLAGS="-d:disableMarchNative --cpu:${arch} --cc:clang --clang.exe:clang-15 --clang.linkerexe:clang-15 --passC:-fno-lto --passL:-fno-lto"

# TEKU
FROM etb-client-builder AS teku-builder
ARG TEKU_BRANCH
ARG TEKU_REPO
RUN git clone "${TEKU_REPO}" && \
    cd teku && \
    git checkout "${TEKU_BRANCH}" && \
    git submodule update --init --recursive && \
    git log -n 1 --format=format:"%H" > /teku.version

RUN cd teku && \
    ./gradlew installDist

# PRYSM
FROM etb-client-builder AS prysm-builder
ARG PRYSM_BRANCH
ARG PRYSM_REPO
RUN git clone "${PRYSM_REPO}" && \
    cd prysm && \
    git checkout "${PRYSM_BRANCH}" && \
    git log -n 1 --format=format:"%H" > /prysm.version

RUN cd prysm && \
    bazelisk build --config=release //cmd/beacon-chain:beacon-chain //cmd/validator:validator

# Antithesis instrumented prysm binary
RUN mkdir prysm_instrumented && \
    /opt/antithesis/go_instrumentation/bin/goinstrumentor \
    -logtostderr -stderrthreshold=INFO \
    -antithesis /opt/antithesis/go_instrumentation/instrumentation/go/wrappers \
    prysm prysm_instrumented

RUN cd prysm_instrumented/customer && go build -o /validator ./cmd/validator
RUN cd prysm_instrumented/customer && go build -o /beacon-chain ./cmd/beacon-chain
RUN cd prysm_instrumented/customer && go build -race -o /validator_race ./cmd/validator
RUN cd prysm_instrumented/customer && go build -race -o /beacon-chain_race ./cmd/beacon-chain


############################# Execution  Clients  #############################
# Geth
FROM etb-client-builder AS geth-builder
ARG GETH_BRANCH
ARG GETH_REPO
RUN git clone "${GETH_REPO}" && \
    cd go-ethereum && \
    git checkout "${GETH_BRANCH}" && \
    git log -n 1 --format=format:"%H" > /geth.version

RUN cd go-ethereum && \
    go install ./... && \
    mv /root/go/bin/geth /tmp/geth_uninstrumented

# Antithesis add instrumentation
RUN mkdir geth_instrumented

RUN /opt/antithesis/go_instrumentation/bin/goinstrumentor \
    -logtostderr -stderrthreshold=INFO \
    -antithesis /opt/antithesis/go_instrumentation/instrumentation/go/wrappers \
    go-ethereum geth_instrumented

RUN cd geth_instrumented/customer && \
    go install -race ./... && mv /root/go/bin/geth /tmp/geth_race

RUN cd geth_instrumented/customer && \
    go install ./...


# Besu
FROM etb-client-builder AS besu-builder
ARG BESU_BRANCH
ARG BESU_REPO
RUN git clone "${BESU_REPO}" && \
    cd besu && \
    git checkout "${BESU_BRANCH}" && \
    git log -n 1 --format=format:"%H" > /besu.version

RUN cd besu && \
    ./gradlew installDist

# Nethermind
FROM etb-client-builder AS nethermind-builder
ARG NETHERMIND_BRANCH
ARG NETHERMIND_REPO
RUN git clone "${NETHERMIND_REPO}" && \
    cd nethermind && \
    git checkout "${NETHERMIND_BRANCH}" && \
    git log -n 1 --format=format:"%H" > /nethermind.version

RUN cd nethermind && \
    dotnet publish -p:PublishReadyToRun=false src/Nethermind/Nethermind.Runner -c release -o out

# RETH
FROM etb-client-builder AS RETH-builder
ARG RETH_BRANCH
ARG RETH_REPO
RUN git clone "${RETH_REPO}" && \
    cd reth && \
    git checkout "${RETH_BRANCH}" && \
    git log -n 1 --format=format:"%H" > /reth.version

RUN cd reth && \
    cargo build --release && \
    mv target/release/reth target/release/reth_uninstrumented

# Antithesis instrumented lighthouse binary
RUN cd reth && \ 
LD_LIBRARY_PATH=/usr/lib/ RUSTFLAGS="-Cpasses=sancov-module -Cllvm-args=-sanitizer-coverage-level=3 -Cllvm-args=-sanitizer-coverage-trace-pc-guard -Ccodegen-units=1 -Cdebuginfo=2 -L/usr/lib/ -lvoidstar" cargo build --release 

############################### Misc.  Modules  ###############################
FROM etb-client-builder AS misc-builder
ARG TX_FUZZ_BRANCH
ARG TX_FUZZ_REPO
ARG BEACON_METRICS_GAZER_REPO
ARG BEACON_METRICS_GAZER_BRANCH

RUN go install github.com/wealdtech/ethereal/v2@latest \
    &&  go install github.com/wealdtech/ethdo@latest \
    && go install github.com/protolambda/eth2-val-tools@latest

RUN git clone "${TX_FUZZ_REPO}" && \
    cd tx-fuzz && \
    git checkout "${TX_FUZZ_BRANCH}"

RUN cd tx-fuzz && \
    cd cmd/livefuzzer && go build

RUN git clone "${BEACON_METRICS_GAZER_REPO}" && \
    cd beacon-metrics-gazer && \
    git checkout "${BEACON_METRICS_GAZER_BRANCH}"

RUN cd beacon-metrics-gazer && \
    cargo update -p proc-macro2 && \
    cargo build --release

RUN cargo install jwt-cli

ARG MOCK_BUILDER_REPO
ARG MOCK_BUILDER_BRANCH
RUN git clone --branch "${MOCK_BUILDER_BRANCH}" "${MOCK_BUILDER_REPO}" && \
    cd mock-builder && \
    go build .

########################### etb-all-clients runner  ###########################
FROM debian:bullseye-slim

# Antithesis instrumentation files
COPY instrumentation/lib/libvoidstar.so /usr/lib/libvoidstar.so
RUN mkdir -p /opt/antithesis/
COPY instrumentation/go_instrumentation /opt/antithesis/go_instrumentation
RUN /opt/antithesis/go_instrumentation/bin/goinstrumentor -version


WORKDIR /git

RUN apt update && apt install curl ca-certificates -y --no-install-recommends \
    wget \
    lsb-release \
    software-properties-common && \
    curl -sL https://deb.nodesource.com/setup_18.x | bash -

RUN wget https://dot.net/v1/dotnet-install.sh -O dotnet-install.sh && \
    chmod +x dotnet-install.sh && \
    ./dotnet-install.sh --channel 7.0

ENV PATH="$PATH:/root/.dotnet/"
ENV DOTNET_ROOT=/root/.dotnet

RUN apt-get update && apt-get install -y --no-install-recommends \
    nodejs \
    libgflags-dev \
    libsnappy-dev \
    zlib1g-dev \
    libbz2-dev \
    liblz4-dev \
    libzstd-dev \
    openjdk-17-jre \
    python3-dev \
    python3-pip \
    jq \
    xxd

RUN pip3 install ruamel.yaml web3 pydantic

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

COPY --from=misc-builder /root/.cargo/bin/jwt /usr/local/bin/jwt
# mock-builder
COPY --from=misc-builder /git/mock-builder/mock-builder /usr/local/bin/mock-builder

# consensus clients
COPY --from=nimbus-eth2-builder /git/nimbus-eth2/build/nimbus_beacon_node /usr/local/bin/nimbus_beacon_node
COPY --from=nimbus-eth2-builder /nimbus.version /nimbus.version

COPY --from=lighthouse-builder /lighthouse.version /lighthouse.version
COPY --from=lighthouse-builder /git/lighthouse/target/release/lighthouse_uninstrumented /usr/local/bin/lighthouse_uninstrumented
COPY --from=lighthouse-builder /git/lighthouse/target/release/lighthouse /usr/local/bin/lighthouse

COPY --from=teku-builder  /git/teku/build/install/teku/. /opt/teku
COPY --from=teku-builder /teku.version /teku.version
RUN ln -s /opt/teku/bin/teku /usr/local/bin/teku

COPY --from=lodestar-builder /git/lodestar /git/lodestar
COPY --from=lodestar-builder /lodestar.version /lodestar.version
RUN ln -s /git/lodestar/node_modules/.bin/lodestar /usr/local/bin/lodestar

# execution clients
COPY --from=geth-builder /geth.version /geth.version
COPY --from=geth-builder /root/go/bin/geth /usr/local/bin/geth
COPY --from=geth-builder /tmp/geth_uninstrumented /usr/local/bin/geth_uninstrumented
COPY --from=geth-builder /tmp/geth_race /usr/local/bin/geth_race
COPY --from=geth-builder /git/geth_instrumented/symbols/* /opt/antithesis/symbols/
COPY --from=geth-builder /git/geth_instrumented/customer /geth_instrumented_code

COPY --from=reth-builder /reth.version /reth.version
COPY --from=reth-builder /git/reth/target/release/reth /usr/local/bin/reth
COPY --from=reth-builder /git/reth/target/release/reth_uninstrumented /usr/local/bin/reth_uninstrumented

COPY --from=besu-builder /besu.version /besu.version
COPY --from=besu-builder /git/besu/build/install/besu/. /opt/besu
RUN ln -s /opt/besu/bin/besu /usr/local/bin/besu

COPY --from=nethermind-builder /nethermind.version /nethermind.version
COPY --from=nethermind-builder /git/nethermind/out /nethermind/
RUN ln -s /nethermind/nethermind /usr/local/bin/nethermindr /beacon-chain /usr/local/bin/
# COPY --from=prysm-builder /validator /usr/local/bin/
COPY --from=prysm-builder /beacon-chain_race /usr/local/bin/beacon-chain
COPY --from=prysm-builder /validator_race /usr/local/bin/validator
COPY --from=prysm-builder /git/prysm/bazel-bin/cmd/beacon-chain/beacon-chain_/beacon-chain /usr/local/bin/beacon-chain_uninstrumented
COPY --from=prysm-builder /git/prysm/bazel-bin/cmd/validator/validator_/validator /usr/local/bin/validator_uninstrumented
COPY --from=prysm-builder /prysm.version /prysm.version
COPY --from=prysm-builder /git/prysm_instrumented/symbols/* /opt/antithesis/symbols/
COPY --from=prysm-builder /git/prysm_instrumented/customer /prysm_instrumented_code
#
# COPY --from=lodestar-builder /git/lodestar /git/lodestar
# COPY --from=lodestar-builder /lodestar.version /lodestar.version
# RUN ln -s /git/lodestar/node_modules/.bin/lodestar /usr/local/bin/lodestar

# execution clients
# COPY --from=geth-builder /geth.version /geth.version
# COPY --from=geth-builder /root/go/bin/geth /usr/local/bin/geth
# COPY --from=geth-builder /tmp/geth_uninstrumented /usr/local/bin/geth_uninstrumented
# COPY --from=geth-builder /tmp/geth_race /usr/local/bin/geth_race
# COPY --from=geth-builder /git/geth_instrumented/symbols/* /opt/antithesis/symbols/
# COPY --from=geth-builder /git/geth_instrumented/customer /geth_instrumented_code

# COPY --from=reth-builder /reth.version /reth.version
# COPY --from=reth-builder /git/reth/target/release/reth /usr/local/bin/reth
# COPY --from=reth-builder /git/reth/target/release/reth_uninstrumented /usr/local/bin/reth_uninstrumented

# COPY --from=besu-builder /besu.version /besu.version
# COPY --from=besu-builder /git/besu/build/install/besu/. /opt/besu
# RUN ln -s /opt/besu/bin/besu /usr/local/bin/besu

# COPY --from=nethermind-builder /nethermind.version /nethermind.version
# COPY --from=nethermind-builder /git/nethermind/out /nethermind/
# RUN ln -s /nethermind/nethermind /usr/local/bin/nethermind