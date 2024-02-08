###############################################################################
#           Dockerfile to build all clients mainnet preset.           #
###############################################################################
# Consensus Clients

# devnet 9 ready
ARG LIGHTHOUSE_REPO="https://github.com/sigp/lighthouse"
ARG LIGHTHOUSE_BRANCH="v4.6.0"

ARG PRYSM_REPO="https://github.com/prysmaticlabs/prysm.git"
ARG PRYSM_BRANCH="v4.2.1-rc.2"

ARG LODESTAR_REPO="https://github.com/ChainSafe/lodestar.git"
ARG LODESTAR_BRANCH="v1.15.0-rc.0"

# devnet 9 ready
ARG NIMBUS_ETH2_REPO="https://github.com/status-im/nimbus-eth2.git"
ARG NIMBUS_ETH2_BRANCH="v24.1.2"

ARG TEKU_REPO="https://github.com/ConsenSys/teku.git"
ARG TEKU_BRANCH="24.1.0"

# ARG TEKU_EVIL_REPO="https://github.com/tbenr/teku"
# ARG TEKU_EVIL_BRANCH="evil-blobs"

# Execution Clients
ARG BESU_REPO="https://github.com/hyperledger/besu.git"
ARG BESU_BRANCH="24.1.1"

ARG GETH_REPO="https://github.com/ethereum/go-ethereum.git"
ARG GETH_BRANCH="v1.13.11"

ARG NETHERMIND_REPO="https://github.com/NethermindEth/nethermind.git"
ARG NETHERMIND_BRANCH="1.25.3"

# ARG ETHEREUMJS_REPO="https://github.com/ethereumjs/ethereumjs-monorepo.git"
# ARG ETHEREUMJS_BRANCH="stable-3981bca"

# ARG ERIGON_REPO="https://github.com/ledgerwatch/erigon"
# ARG ERIGON_BRANCH="v2.56.1"

ARG RETH_REPO="https://github.com/paradigmxyz/reth"
ARG RETH_BRANCH="v0.1.0-alpha.16"

# All of the fuzzers we will be using
# ARG TX_FUZZ_REPO="https://github.com/qu0b/tx-fuzz.git"
# ARG TX_FUZZ_BRANCH="22631838d3ffd9f57f4b09e02a4e71686a921414"

ARG TX_FUZZ_REPO="https://github.com/MariusVanDerWijden/tx-fuzz"
ARG TX_FUZZ_BRANCH="master"

# Metrics gathering
ARG BEACON_METRICS_GAZER_REPO="https://github.com/qu0b/beacon-metrics-gazer.git"
ARG BEACON_METRICS_GAZER_BRANCH="master"

# Mock builder for testing builder API
ARG MOCK_BUILDER_REPO="https://github.com/marioevz/mock-builder.git"
ARG MOCK_BUILDER_BRANCH="v1.1.0"

###############################################################################
# Builder to build all of the clients.
FROM debian:stable-slim AS etb-client-builder

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
    librocksdb7.8

COPY ./repos /git


# set up dotnet (nethermind)
RUN wget https://dot.net/v1/dotnet-install.sh -O dotnet-install.sh && \
    chmod +x dotnet-install.sh && \
    ./dotnet-install.sh --channel 8.0
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
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
apt-get install -y nodejs

RUN npm install -g @bazel/bazelisk # prysm build system

# setup cargo/rustc (lighthouse)
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- --default-toolchain stable -y
ENV PATH="$PATH:/root/.cargo/bin"

# Build rocksdb
# RUN if [ ! -d "rocksdb" ]; then \
#         git clone --depth 1 https://github.com/facebook/rocksdb.git; \
#     else \
#         cd rocksdb && \
#         git pull && \
#         make clean; \
#     fi && \
#     git log -n 1 --format=format:"%H" > /rocksdb.version

# RUN cd rocksdb && make -j$(nproc) static_lib

RUN apt install -y protobuf-compiler libprotobuf-dev # protobuf compiler for lighthouse
RUN ln -s /usr/local/bin/python3 /usr/local/bin/python
RUN npm install --global yarn
############################# Consensus  Clients  #############################

# LIGHTHOUSE
FROM etb-client-builder AS lighthouse-builder
ARG LIGHTHOUSE_BRANCH
ARG LIGHTHOUSE_REPO
# Check if the directory exists
RUN if [ ! -d "lighthouse" ]; then \
        git clone "${LIGHTHOUSE_REPO}"; \
        cd lighthouse && git checkout "${LIGHTHOUSE_BRANCH}"; \
    else \
        cd lighthouse && \
        git fetch && \
        git checkout "${LIGHTHOUSE_BRANCH}"; \
    fi && \
    git log -n 1 --format=format:"%H" > /lighthouse.version

RUN cd lighthouse && \
    cargo update -p proc-macro2 && \
    cargo build --release --bin lighthouse

# LODESTAR
FROM etb-client-builder AS lodestar-builder
ARG LODESTAR_BRANCH
ARG LODESTAR_REPO
RUN if [ ! -d "lodestar" ]; then \
        git clone "${LODESTAR_REPO}"; \
        cd lodestar && git checkout "${LODESTAR_BRANCH}"; \
    else \
        cd lodestar && \
        git fetch && \
        git checkout "${LODESTAR_BRANCH}"; \
    fi && \
    git log -n 1 --format=format:"%H" > /lodestar.version

RUN cd lodestar && \
    yarn install --non-interactive --frozen-lockfile && \
    yarn build && \
    yarn install --non-interactive --frozen-lockfile --production

# NIMBUS
FROM etb-client-builder AS nimbus-builder
ARG NIMBUS_ETH2_BRANCH
ARG NIMBUS_ETH2_REPO
#RUN git clone --depth 1 --branch "${NIMBUS_ETH2_BRANCH}" "${NIMBUS_ETH2_REPO}"  && \
RUN if [ ! -d "nimbus-eth2" ]; then \
        git clone "${NIMBUS_ETH2_REPO}"; \
        cd nimbus-eth2 && git checkout "${NIMBUS_ETH2_BRANCH}"; \
    else \
        cd nimbus-eth2 && \
        git fetch && \
        git checkout "${NIMBUS_ETH2_BRANCH}"; \
    fi && \
    git log -n 1 --format=format:"%H" > /nimbus.version

RUN cd nimbus-eth2 && \
    make -j$(nproc) update && \
    arch=$(arch | sed s/aarch64/arm64/ | sed s/x86_64/amd64/) && \
    make -j$(nproc) nimbus_beacon_node NIMFLAGS="-d:disableMarchNative --cpu:${arch} --cc:clang --clang.exe:clang-15 --clang.linkerexe:clang-15 --passC:-fno-lto --passL:-fno-lto"

# TEKU
FROM etb-client-builder AS teku-builder
ARG TEKU_BRANCH
ARG TEKU_REPO
RUN if [ ! -d "teku" ]; then \
        git clone "${TEKU_REPO}"; \
        cd teku && git checkout "${TEKU_BRANCH}"; \
    else \
        cd teku && \
        git fetch && \
        git checkout "${TEKU_BRANCH}"; \
    fi && \
    git log -n 1 --format=format:"%H" > /teku.version
    
# RUN cd teku && \
#     git submodule update --init --recursive && \

RUN cd teku && \
    ./gradlew --parallel installDist


# TEKU-EVIL
# FROM etb-client-builder AS teku-evil-builder
# ARG TEKU_EVIL_BRANCH
# ARG TEKU_EVIL_REPO
# RUN git clone "${TEKU_EVIL_REPO}" && \
#     cd teku && \
#     
#     git submodule update --init --recursive && \
#     git log -n 1 --format=format:"%H" > /teku.version

# RUN cd teku && \
#     ./gradlew installDist

# PRYSM
FROM etb-client-builder AS prysm-builder
ARG PRYSM_BRANCH
ARG PRYSM_REPO
RUN if [ ! -d "prysm" ]; then \
        git clone "${PRYSM_REPO}"; \
        cd prysm && git checkout "${PRYSM_BRANCH}"; \
    else \
        cd prysm && \
        git fetch && \
        git checkout "${PRYSM_BRANCH}"; \
    fi && \
    git log -n 1 --format=format:"%H" > /prysm.version

RUN cd prysm && \
    bazelisk build --config=release //cmd/beacon-chain:beacon-chain //cmd/validator:validator


############################# Execution  Clients  #############################
# Geth
FROM etb-client-builder AS geth-builder
ARG GETH_BRANCH
ARG GETH_REPO
RUN if [ ! -d "go-ethereum" ]; then \
       git clone "${GETH_REPO}"; \
       cd go-ethereum && git checkout "${GETH_BRANCH}"; \
   else \
       cd go-ethereum && \
       git fetch && \
       git checkout "${GETH_BRANCH}"; \
   fi && \
   git log -n 1 --format=format:"%H" > /geth.version

RUN cd go-ethereum && \
    make geth

# Besu
FROM etb-client-builder AS besu-builder
ARG BESU_REPO
ARG BESU_BRANCH
RUN if [ ! -d "besu" ]; then \
        git clone "${BESU_REPO}"; \
        cd besu && git checkout "${BESU_BRANCH}"; \
    else \
        cd besu && \
        git fetch && \
        git checkout "${BESU_BRANCH}"; \
    fi && \
    git log -n 1 --format=format:"%H" > /besu.version

RUN cd besu && \
    ./gradlew --parallel installDist

# Nethermind
FROM etb-client-builder AS nethermind-builder
ARG NETHERMIND_REPO
ARG NETHERMIND_BRANCH
RUN if [ ! -d "nethermind" ]; then \
        git clone "${NETHERMIND_REPO}"; \
        cd nethermind && git checkout "${NETHERMIND_BRANCH}"; \
    else \
        cd nethermind && \
        git fetch && \
        git checkout "${NETHERMIND_BRANCH}"; \
    fi && \
    git log -n 1 --format=format:"%H" > /nethermind.version

RUN cd nethermind && \
    dotnet publish -p:PublishReadyToRun=false src/Nethermind/Nethermind.Runner -c release -o out

# # EthereumJS
# FROM etb-client-builder AS ethereumjs-builder
# ARG ETHEREUMJS_REPO
# ARG ETHEREUMJS_BRANCH
# RUN git clone --depth 1  -b ${ETHEREUMJS_BRANCH}" "${ETHEREUMJS_REPO}" && \
#     cd ethereumjs-monorepo && \
#     git log -n 1 --format=format:"%H" > /ethereumjs.version

# RUN cd ethereumjs-monorepo && \
#     npm install && \
#     npm run build --workspaces

# # Erigon
# FROM etb-client-builder AS erigon-builder
# ARG ERIGON_REPO
# ARG ERIGON_BRANCH
# RUN git clone "${ERIGON_REPO}" && \
#     cd ERIGON && \
#     
#     git log -n 1 --format=format:"%H" > /ERIGON.version

# RUN cd ERIGON && \

# RETH
FROM etb-client-builder AS reth-builder
ARG RETH_BRANCH
ARG RETH_REPO
RUN if [ ! -d "reth" ]; then \
        git clone "${RETH_REPO}"; \
        cd reth && git checkout "${RETH_BRANCH}"; \
    else \
        cd reth && \
        git fetch && \
        git checkout "${RETH_BRANCH}"; \
    fi && \
    git log -n 1 --format=format:"%H" > /reth.version

RUN cd reth && \
    cargo build --release

############################### Misc.  Modules  ###############################
FROM etb-client-builder AS misc-builder
ARG TX_FUZZ_BRANCH
ARG TX_FUZZ_REPO
ARG BEACON_METRICS_GAZER_REPO
ARG BEACON_METRICS_GAZER_BRANCH

RUN go install github.com/wealdtech/ethereal/v2@latest
RUN go install github.com/wealdtech/ethdo@v1.35.2
RUN go install github.com/protolambda/eth2-val-tools@latest

#RUN git clone --depth 1 --branch "${TX_FUZZ_BRANCH}" "${TX_FUZZ_REPO}"  && \
RUN    cd tx-fuzz && \
    cd cmd/livefuzzer && go build

RUN if [ ! -d "beacon-metrics-gazer" ]; then \
        git clone "${BEACON_METRICS_GAZER_REPO}"; \
        cd beacon-metrics-gazer && git checkout "${BEACON_METRICS_GAZER_BRANCH}"; \
    else \
        cd beacon-metrics-gazer && \
        git fetch && \
        git checkout "${BEACON_METRICS_GAZER_BRANCH}"; \
    fi && \
    git log -n 1 --format=format:"%H" > /beacon-metrics-gazer.version

RUN cd beacon-metrics-gazer && \
    cargo update -p proc-macro2 && \
    cargo build --release

RUN cargo install jwt-cli

ARG MOCK_BUILDER_REPO
ARG MOCK_BUILDER_BRANCH
#RUN git clone --depth 1 --branch "${MOCK_BUILDER_BRANCH}" "${MOCK_BUILDER_REPO}" && \
RUN    cd mock-builder && \
    go build .

########################### etb-all-clients runner  ###########################
FROM debian:stable-slim

WORKDIR /git

RUN apt update && apt install curl ca-certificates -y --no-install-recommends \
    wget \
    lsb-release \
    software-properties-common && \
    curl -sL https://deb.nodesource.com/setup_20.x | bash -

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

# install node to run lodestar
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

COPY --from=misc-builder /root/.cargo/bin/jwt /usr/local/bin/jwt
# mock-builder
COPY --from=misc-builder /git/mock-builder/mock-builder /usr/local/bin/mock-builder


# consensus clients
COPY --from=nimbus-builder /git/nimbus-eth2/build/nimbus_beacon_node /usr/local/bin/nimbus_beacon_node
COPY --from=nimbus-builder /nimbus.version /nimbus.version

COPY --from=lighthouse-builder /lighthouse.version /lighthouse.version
COPY --from=lighthouse-builder /git/lighthouse/target/release/lighthouse /usr/local/bin/lighthouse

COPY --from=teku-builder /git/teku/build/install/teku/. /opt/teku
COPY --from=teku-builder /teku.version /teku.version
RUN ln -s /opt/teku/bin/teku /usr/local/bin/teku

# COPY --from=etb-client-builder  /git/teku/build/install/teku/. /opt/teku_evil
# COPY --from=etb-client-builder /teku.version /teku_evil.version
# RUN ln -s /opt/teku_evil/bin/teku /usr/local/bin/teku-evil

COPY --from=prysm-builder /git/prysm/bazel-bin/cmd/beacon-chain/beacon-chain_/beacon-chain /usr/local/bin/beacon-chain
COPY --from=prysm-builder /git/prysm/bazel-bin/cmd/validator/validator_/validator /usr/local/bin/validator
COPY --from=prysm-builder /prysm.version /prysm.version
#
COPY --from=lodestar-builder /git/lodestar /git/lodestar
COPY --from=lodestar-builder /lodestar.version /lodestar.version
RUN ln -s /git/lodestar/node_modules/.bin/lodestar /usr/local/bin/lodestar

# execution clients
COPY --from=geth-builder /geth.version /geth.version
COPY --from=geth-builder /git/go-ethereum/build/bin/geth /usr/local/bin/geth

COPY --from=reth-builder /reth.version /reth.version
COPY --from=reth-builder /git/reth/target/release/reth /usr/local/bin/reth

COPY --from=besu-builder /besu.version /besu.version
COPY --from=besu-builder /git/besu/build/install/besu/. /opt/besu
RUN ln -s /opt/besu/bin/besu /usr/local/bin/besu

COPY --from=nethermind-builder /nethermind.version /nethermind.version
COPY --from=nethermind-builder /git/nethermind/out /nethermind/
RUN ln -s /nethermind/nethermind /usr/local/bin/nethermind

