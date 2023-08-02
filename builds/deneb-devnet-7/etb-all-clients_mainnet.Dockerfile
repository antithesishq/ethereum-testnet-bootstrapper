###############################################################################
#           Dockerfile to build all clients minimal mainnet preset.           #
###############################################################################
# Consensus Clients
ARG LIGHTHOUSE_REPO="https://github.com/jtraglia/lighthouse"
ARG LIGHTHOUSE_BRANCH="d534ac0"

ARG TEKU_REPO="https://github.com/ConsenSys/teku.git"
ARG TEKU_BRANCH="23.6.1"

# Execution Clients
# ARG BESU_REPO="https://github.com/hyperledger/besu.git"
# ARG BESU_BRANCH="403297b874b68cb414c4bf13e98549b3597c61ca"

ARG BESU_REPO="https://github.com/jflo/besu.git"
# ARG BESU_BRANCH="EIP-4844"
ARG BESU_BRANCH="403297b874b68cb414c4bf13e98549b3597c61ca"


ARG NETHERMIND_REPO="https://github.com/NethermindEth/nethermind.git"
ARG NETHERMIND_BRANCH="d0f10c32ba584f765819779bf20dd5b78e0611c0"

ARG NETHERMINED_BLOB_SPAMMER="https://github.com/NethermindEth/nethermind.git"
ARG NETHERMIND_BLOB_SPAMMER_BRANCH="101bfe45a9c1e52e04708157a70c36c2e9b128c8"

# All of the fuzzers we will be using
ARG TX_FUZZ_REPO="https://github.com/qu0b/tx-fuzz.git"
ARG TX_FUZZ_BRANCH="debug"

# Metrics gathering
ARG BEACON_METRICS_GAZER_REPO="https://github.com/qu0b/beacon-metrics-gazer.git"
ARG BEACON_METRICS_GAZER_BRANCH="master"
###############################################################################
# Builder to build all of the clients.
FROM debian:bullseye-slim AS etb-client-builder

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

# setup cargo/rustc (lighthouse)
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- --default-toolchain stable -y
ENV PATH="$PATH:/root/.cargo/bin"
# Build rocksdb
RUN git clone --depth=1 https://github.com/facebook/rocksdb.git
RUN cd rocksdb && make -j4 install

RUN apt install -y protobuf-compiler libprotobuf-dev # protobuf compiler for lighthouse
RUN ln -s /usr/local/bin/python3 /usr/local/bin/python

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
    cargo build --release --manifest-path lighthouse/Cargo.toml --bin lighthouse

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

############################# Execution  Clients  #############################
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

############################### Misc.  Modules  ###############################
FROM etb-client-builder AS misc-builder
ARG TX_FUZZ_BRANCH
ARG TX_FUZZ_REPO
ARG BEACON_METRICS_GAZER_REPO
ARG BEACON_METRICS_GAZER_BRANCH
ARG NETHERMINED_BLOB_SPAMMER
ARG NETHERMIND_BLOB_SPAMMER_BRANCH

RUN go install github.com/wealdtech/ethereal/v2@latest \
    && go install github.com/wealdtech/ethdo@latest \
    && go install github.com/protolambda/eth2-val-tools@latest

RUN git clone "${TX_FUZZ_REPO}" && \
    cd tx-fuzz && \
    git checkout "${TX_FUZZ_BRANCH}"

RUN cd tx-fuzz && \
    cd cmd/livefuzzer && go build

RUN git clone "${NETHERMINED_BLOB_SPAMMER}" && \
    cd nethermind && \
    git checkout "${NETHERMIND_BLOB_SPAMMER_BRANCH}"

RUN cd nethermind && \
    dotnet publish ./src/Nethermind/Nethermind.SendBlobs/Nethermind.SendBlobs.csproj --sc -o out

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
    python3-pip \
    jq

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

# nethermind blob sender
COPY --from=misc-builder /git/nethermind/out/Nethermind.SendBlobs /usr/local/bin/Nethermind.SendBlobs

COPY --from=lighthouse-builder /lighthouse.version /lighthouse.version
COPY --from=lighthouse-builder /git/lighthouse/target/release/lighthouse /usr/local/bin/lighthouse

COPY --from=teku-builder  /git/teku/build/install/teku/. /opt/teku
COPY --from=teku-builder /teku.version /teku.version
RUN ln -s /opt/teku/bin/teku /usr/local/bin/teku

# execution clients
COPY --from=besu-builder /besu.version /besu.version
COPY --from=besu-builder /git/besu/build/install/besu/. /opt/besu
RUN ln -s /opt/besu/bin/besu /usr/local/bin/besu

COPY --from=nethermind-builder /nethermind.version /nethermind.version
COPY --from=nethermind-builder /git/nethermind/out /nethermind/
RUN ln -s /nethermind/Nethermind.Runner /usr/local/bin/nethermind