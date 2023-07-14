###############################################################################
#           Dockerfile to build all clients minimal mainnet preset.           #
###############################################################################
# Consensus Clients
ARG LIGHTHOUSE_REPO="https://github.com/sigp/lighthouse.git"
ARG LIGHTHOUSE_BRANCH="deneb-free-blobs"

#ARG LODESTAR_REPO="https://github.com/ChainSafe/lodestar.git"
#ARG LODESTAR_BRANCH="stable"
#
#ARG NIMBUS_ETH2_REPO="https://github.com/status-im/nimbus-eth2.git"
#ARG NIMBUS_ETH2_BRANCH="stable"
#
#ARG PRYSM_REPO="https://github.com/prysmaticlabs/prysm.git"
#ARG PRYSM_BRANCH="v4.0.4-patchFix"

ARG TEKU_REPO="https://github.com/ConsenSys/teku.git"
ARG TEKU_BRANCH="23.6.1"

# Execution Clients
#ARG BESU_REPO="https://github.com/hyperledger/besu.git"
#ARG BESU_BRANCH="main"

ARG GETH_REPO="https://github.com/MariusVanDerWijden/go-ethereum.git"
ARG GETH_BRANCH="4844-devnet-6"

ARG NETHERMIND_REPO="https://github.com/NethermindEth/nethermind.git"
ARG NETHERMIND_BRANCH="feature/eip-4844-v6"

# All of the fuzzers we will be using
ARG TX_FUZZ_REPO="https://github.com/MariusVanDerWijden/tx-fuzz.git"
ARG TX_FUZZ_BRANCH="4844"

# Metrics gathering
ARG BEACON_METRICS_GAZER_REPO="https://github.com/qu0b/beacon-metrics-gazer.git"
ARG BEACON_METRICS_GAZER_BRANCH="master"
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
    git

# set up dotnet (nethermind)
RUN wget https://packages.microsoft.com/config/debian/11/packages-microsoft-prod.deb -O packages-microsoft-prod.deb && dpkg -i packages-microsoft-prod.deb && rm packages-microsoft-prod.deb
RUN apt update && apt install -y dotnet-sdk-7.0


WORKDIR /git

# set up clang 15 (nimbus+deps)
RUN wget --no-check-certificate https://apt.llvm.org/llvm.sh && chmod +x llvm.sh && ./llvm.sh 15
ENV LLVM_CONFIG=llvm-config-15

# set up go (geth+prysm)
RUN wget https://go.dev/dl/go1.20.3.linux-amd64.tar.gz
RUN tar -zxvf go1.20.3.linux-amd64.tar.gz -C /usr/local/
RUN ln -s /usr/local/go/bin/go /usr/local/bin/go
RUN ln -s /usr/local/go/bin/gofmt /usr/local/bin/gofmt
ENV PATH="$PATH:/root/go/bin"

# setup nodejs (lodestar)
RUN apt update \
    && apt install curl ca-certificates -y --no-install-recommends \
    && curl -sL https://deb.nodesource.com/setup_18.x | bash -

RUN apt-get update && apt-get install -y --no-install-recommends nodejs
RUN npm install -g npm@latest
RUN npm install -g @bazel/bazelisk # prysm build system

# setup cargo/rustc (lighthouse)
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- --default-toolchain nightly -y
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
    mv target/release/lighthouse target/release/lighthouse_uinstrumented

# Antithesis instrumented lighthouse binary
RUN cd lighthouse && \ 
LD_LIBRARY_PATH=/usr/lib/ RUSTFLAGS="-Cpasses=sancov-module -Cllvm-args=-sanitizer-coverage-level=3 -Cllvm-args=-sanitizer-coverage-trace-pc-guard -Ccodegen-units=1 -Cdebuginfo=2 -L/usr/lib/ -lvoidstar" cargo build --release --manifest-path lighthouse/Cargo.toml --features spec-minimal --bin lighthouse

# LODESTAR
#FROM etb-client-builder AS lodestar-builder
#ARG LODESTAR_BRANCH
#ARG LODESTAR_REPO
#RUN git clone "${LODESTAR_REPO}" && \
#    cd lodestar && \
#    git checkout "${LODESTAR_BRANCH}" && \
#    git log -n 1 --format=format:"%H" > /lodestar.version
#
#RUN cd lodestar && \
#    yarn install --non-interactive --frozen-lockfile && \
#    yarn build && \
#    yarn install --non-interactive --frozen-lockfile --production

# NIMBUS
#FROM etb-client-builder AS nimbus-eth2-builder
#ARG NIMBUS_ETH2_BRANCH
#ARG NIMBUS_ETH2_REPO
#RUN git clone "${NIMBUS_ETH2_REPO}" && \
#    cd nimbus-eth2 && \
#    git checkout "${NIMBUS_ETH2_BRANCH}" && \
#    git log -n 1 --format=format:"%H" > /nimbus.version && \
#    make -j16 update

# Antithensis instrumented nimbus binary
# RUN make -j16 USE_LIBBACKTRACE=0 nimbus_beacon_node NIMFLAGS="-d:const_preset=minimal -d:web3_consensus_const_preset=minimal -d:disableMarchNative -d:FIELD_ELEMENTS_PER_BLOB=4 --cc:clang --clang.exe:clang-15 --clang.linkerexe:clang-15 --passC:'-fno-lto -fsanitize-coverage=trace-pc-guard' --passL:'-fno-lto -L/usr/lib/ -lvoidstar'"
# RUN mv /nimbus-eth2/build/nimbus_beacon_node /nimbus-eth2/build/nimbus_beacon_node_instrumented

#RUN cd nimbus-eth2 && \
#    make -j16 nimbus_beacon_node NIMFLAGS="-d:disableMarchNative --cc:clang --clang.exe:clang-15 --clang.linkerexe:clang-15"



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
#FROM gcr.io/prysmaticlabs/build-agent AS prysm-builder
#ARG PRYSM_BRANCH
#ARG PRYSM_REPO
#RUN git clone "${PRYSM_REPO}" && \
#    cd prysm && \
#    git checkout "${PRYSM_BRANCH}" && \
#    git log -n 1 --format=format:"%H" > /prysm.version
#
#RUN cd prysm && bazel build //cmd/beacon-chain:beacon-chain //cmd/validator:validator

# Antithesis instrumented prysm binary
# RUN /opt/antithesis/go_instrumentation/bin/goinstrumentor \
#     -logtostderr -stderrthreshold=INFO \
#     -antithesis /opt/antithesis/go_instrumentation/instrumentation/go/wrappers \
#     prysm prysm_instrumented

# RUN go build -tags minimal -o /validator ./cmd/validator
# RUN go build -tags minimal -o /beacon-chain ./cmd/beacon-chain
# RUN go build -race -tags minimal -o /validator_race ./cmd/validator
# RUN go build -race -tags minimal -o /beacon-chain_race ./cmd/beacon-chain

############################# Execution  Clients  #############################
# Geth
FROM etb-client-builder AS geth-builder
ARG GETH_BRANCH
ARG GETH_REPO
RUN git clone "${GETH_REPO}" && \
    cd go-ethereum && \
    git checkout "${GETH_BRANCH}" && \
    git log -n 1 --format=format:"%H" > /geth.version

# Antithesis add instrumentation
RUN mkdir geth_instrumented
RUN /opt/antithesis/go_instrumentation/bin/goinstrumentor \
    -logtostderr -stderrthreshold=INFO \
    -antithesis /opt/antithesis/go_instrumentation/instrumentation/go/wrappers \
    go-ethereum geth_instrumented

RUN cd go-ethereum && go install ./... && \
    mv /root/go/bin/geth /tmp/geth_uninstrumented && \
    mv /root/go/bin/bootnode /tmp/bootnode_uninstrumented

RUN cd geth_instrumented/customer && \
    go install -race ./... && mv /root/go/bin/geth /tmp/geth_race

RUN cd geth_instrumented/customer && \
    go install ./...

# Besu
#FROM etb-client-builder AS besu-builder
#ARG BESU_BRANCH
#ARG BESU_REPO
#RUN git clone "${BESU_REPO}" && \
#    cd besu && \
#    git checkout "${BESU_BRANCH}" && \
#    git log -n 1 --format=format:"%H" > /besu.version
#
#RUN cd besu && \
#    ./gradlew installDist

# Nethermind
FROM etb-client-builder AS nethermind-builder
ARG NETHERMIND_BRANCH
ARG NETHERMIND_REPO
RUN git clone "${NETHERMIND_REPO}" && \
    cd nethermind && \
    git checkout "${NETHERMIND_BRANCH}" && \
    git log -n 1 --format=format:"%H" > /nethermind.version

RUN cd nethermind && \
    dotnet publish src/Nethermind/Nethermind.Runner -c release -o out

############################### Misc.  Modules  ###############################
FROM etb-client-builder AS misc-builder
ARG TX_FUZZ_BRANCH
ARG TX_FUZZ_REPO
ARG BEACON_METRICS_GAZER_REPO
ARG BEACON_METRICS_GAZER_BRANCH

RUN go install github.com/wealdtech/ethereal/v2@latest \
    && go install github.com/wealdtech/ethdo@latest \
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
########################### etb-all-clients runner  ###########################
FROM debian:bullseye-slim

WORKDIR /git

RUN apt update && apt install curl ca-certificates -y --no-install-recommends \
    wget \
    lsb-release \
    software-properties-common && \
    curl -sL https://deb.nodesource.com/setup_18.x | bash -

RUN wget https://packages.microsoft.com/config/debian/11/packages-microsoft-prod.deb -O packages-microsoft-prod.deb && \
    dpkg -i packages-microsoft-prod.deb && \
    rm packages-microsoft-prod.deb

RUN apt-get update && apt-get install -y --no-install-recommends \
    nodejs \
    libgflags-dev \
    libsnappy-dev \
    zlib1g-dev \
    libbz2-dev \
    liblz4-dev \
    libzstd-dev \
    openjdk-17-jre \
    dotnet-runtime-7.0 \
    aspnetcore-runtime-7.0 \
    python3-dev \
    python3-pip

RUN pip3 install ruamel.yaml web3

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

# consensus clients
#COPY --from=nimbus-eth2-builder /git/nimbus-eth2/build/nimbus_beacon_node /usr/local/bin/nimbus_beacon_node
#COPY --from=nimbus-eth2-builder /nimbus.version /nimbus.version

COPY --from=lighthouse-builder /lighthouse.version /lighthouse.version
# Antithesis copy instrumented and uninstrumented versions of lighthouse
COPY --from=lighthouse-builder /git/lighthouse/target/release/lighthouse_uninstrumented /usr/local/bin/lighthouse_uninstrumented
COPY --from=lighthouse-builder /git/lighthouse/target/release/lighthouse /usr/local/bin/lighthouse

COPY --from=teku-builder  /git/teku/build/install/teku/. /opt/teku
COPY --from=teku-builder /teku.version /teku.version
RUN ln -s /opt/teku/bin/teku /usr/local/bin/teku

#COPY --from=prysm-builder /prysm/bazel-bin/cmd/beacon-chain/beacon-chain_/beacon-chain /usr/local/bin/beacon-chain
#COPY --from=prysm-builder /prysm/bazel-bin/cmd/validator/validator_/validator /usr/local/bin/validator
#COPY --from=prysm-builder /prysm.version /prysm.version
#
#COPY --from=lodestar-builder /git/lodestar /git/lodestar
#COPY --from=lodestar-builder /lodestar.version /lodestar.version
#RUN ln -s /git/lodestar/node_modules/.bin/lodestar /usr/local/bin/lodestar

# execution clients
COPY --from=geth-builder /geth.version /geth.version

# Antithesis geth instrumentation
COPY --from=geth-builder /root/go/bin/geth /usr/local/bin/geth
COPY --from=builder /root/go/bin/bootnode /usr/local/bin/bootnode
COPY --from=builder /tmp/geth_race /usr/local/bin/geth_race
COPY --from=builder /tmp/geth_uninstrumented /usr/local/bin/geth_uninstrumented
COPY --from=builder /tmp/bootnode_uninstrumented /usr/local/bin/bootnode_uninstrumented
COPY --from=builder /git/geth_instrumented/symbols/* /opt/antithesis/symbols/
COPY --from=builder /git/geth_instrumented/customer /geth_instrumented_code

#COPY --from=besu-builder /besu.version /besu.version
#COPY --from=besu-builder /git/besu/build/install/besu/. /opt/besu
#RUN ln -s /opt/besu/bin/besu /usr/local/bin/besu

COPY --from=nethermind-builder /nethermind.version /nethermind.version
COPY --from=nethermind-builder /git/nethermind/out /nethermind/
RUN ln -s /nethermind/Nethermind.Runner /usr/local/bin/nethermind