###############################################################################
#           Dockerfile to build all clients mainnet preset.           #
###############################################################################
# Consensus Clients
ARG LIGHTHOUSE_REPO="https://github.com/sigp/lighthouse"
ARG LIGHTHOUSE_BRANCH="v5.0.0" 

ARG PRYSM_REPO="https://github.com/prysmaticlabs/prysm.git"
ARG PRYSM_BRANCH="v5.0.0"

ARG LODESTAR_REPO="https://github.com/ChainSafe/lodestar.git"
ARG LODESTAR_BRANCH="v1.16.0"
#
ARG NIMBUS_ETH2_REPO="https://github.com/status-im/nimbus-eth2.git"
ARG NIMBUS_ETH2_BRANCH="v24.2.1"

ARG TEKU_REPO="https://github.com/ConsenSys/teku.git"
ARG TEKU_BRANCH="24.2.0"

# Execution Clients
ARG BESU_REPO="https://github.com/hyperledger/besu.git"
ARG BESU_BRANCH="24.1.2"

ARG GETH_REPO="https://github.com/ethereum/go-ethereum.git"
ARG GETH_BRANCH="v1.13.13"

ARG NETHERMIND_REPO="https://github.com/NethermindEth/nethermind.git"
ARG NETHERMIND_BRANCH="1.25.4"

# ARG ETHEREUMJS_REPO="https://github.com/ethereumjs/ethereumjs-monorepo.git"
# ARG ETHEREUMJS_BRANCH="7a0a37b7355c77ce841d5b04da55a2a4b53fe550"

ARG RETH_REPO="https://github.com/paradigmxyz/reth"
ARG RETH_BRANCH="v0.1.0-alpha.19"

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

ARG ASSERTOR_REPO="https://github.com/qu0b/assertoor"
ARG ASSERTOR_BRANCH="feature/concurrentTests"

###############################################################################
# Builder to build all of the clients.
FROM debian:stable-slim AS etb-client-builder

COPY ./repos /git
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
    librocksdb7.8

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

# Build rocksdb
# RUN if [ ! -d "rocksdb" ]; then \
#         git clone --depth 1 https://github.com/facebook/rocksdb.git; \
#     else \
#         cd rocksdb && \
#         make clean; \
#     fi && \
#     git log -n 1 --format=format:"%H" > /rocksdb.version

# RUN cd rocksdb && make -j32 install

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

# LIGHTHOUSE INSTRUMENTED
#FROM etb-client-builder AS lighthouse-builder-inst
#ARG LIGHTHOUSE_BRANCH
#ARG LIGHTHOUSE_REPO
## Check if the directory exists
#RUN if [ ! -d "lighthouse" ]; then \
#        git clone "${LIGHTHOUSE_REPO}"; \
#        cd lighthouse && git checkout "${LIGHTHOUSE_BRANCH}"; \
#    else \
#        cd lighthouse && \
#        git fetch && \
#        git checkout "${LIGHTHOUSE_BRANCH}"; \
#    fi && \
#    git log -n 1 --format=format:"%H" > /lighthouse.version
#
## Antithesis instrumented lighthouse binary
#RUN cd lighthouse && LD_LIBRARY_PATH=/usr/lib/ RUSTFLAGS="-Cpasses=sancov-module -Cllvm-args=-sanitizer-coverage-level=3 -Cllvm-args=-sanitizer-coverage-trace-pc-guard -Ccodegen-units=1 -Cdebuginfo=2 -L/usr/lib/ -lvoidstar"  cargo build --release --manifest-path lighthouse/Cargo.toml --bin lighthouse

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
FROM etb-client-builder AS nimbus-eth2-builder
ARG NIMBUS_ETH2_BRANCH
ARG NIMBUS_ETH2_REPO
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
    make -j32 update && \
    arch=$(arch | sed s/aarch64/arm64/ | sed s/x86_64/amd64/) && \
    make -j32 nimbus_beacon_node NIMFLAGS="-d:disableMarchNative --cpu:${arch} --cc:clang --clang.exe:clang-15 --clang.linkerexe:clang-15 --passC:-fno-lto --passL:-fno-lto"

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


RUN cd teku && \
    ./gradlew --parallel installDist

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

# PRYSM INSTRUMENTED
FROM etb-client-builder AS prysm-builder-inst
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

# Antithesis instrumented prysm binary
RUN cd prysm && \
    bazelisk build --config=release //cmd/beacon-chain:beacon-chain //cmd/validator:validator

RUN mkdir -p prysm_instrumented

RUN /opt/antithesis/go_instrumentation/bin/goinstrumentor \
    -logtostderr -stderrthreshold=INFO \
    -antithesis /opt/antithesis/go_instrumentation/instrumentation/go/wrappers \
    prysm prysm_instrumented 

RUN cd prysm_instrumented/customer && go build -race -o /tmp/validator ./cmd/validator
RUN cd prysm_instrumented/customer && go build -race -o /tmp/beacon-chain ./cmd/beacon-chain


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

# Geth instrumented
FROM etb-client-builder AS geth-builder-inst
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
ARG NETHERMIND_BRANCH
ARG NETHERMIND_REPO
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

# RETH INSTRUMENTED
#FROM etb-client-builder AS reth-builder-inst
#ARG RETH_BRANCH
#ARG RETH_REPO
#RUN if [ ! -d "reth" ]; then \
#        git clone "${RETH_REPO}"; \
#        cd reth && git checkout "${RETH_BRANCH}"; \
#    else \
#        cd reth && \
#        git fetch && \
#        git checkout "${RETH_BRANCH}"; \
#    fi && \
#    git log -n 1 --format=format:"%H" > /reth.version
#
## Antithesis reth lighthouse binary
#RUN cd reth && LD_LIBRARY_PATH=/usr/lib/ RUSTFLAGS="-Cpasses=sancov-module -Cllvm-args=-sanitizer-coverage-level=3 -Cllvm-args=-sanitizer-coverage-trace-pc-guard -Ccodegen-units=1 -Cdebuginfo=2 -L/usr/lib/ -lvoidstar"  cargo build --release --bin reth

############################### Misc.  Modules  ###############################
FROM etb-client-builder AS misc-builder
ARG TX_FUZZ_BRANCH
ARG TX_FUZZ_REPO
ARG BEACON_METRICS_GAZER_REPO
ARG BEACON_METRICS_GAZER_BRANCH

RUN go install github.com/wealdtech/ethereal/v2@latest
RUN go install github.com/wealdtech/ethdo@v1.35.2
RUN go install github.com/protolambda/eth2-val-tools@latest

#RUN git clone --depth 1 --single-branch --branch "${TX_FUZZ_BRANCH}" "${TX_FUZZ_REPO}" && \
RUN if [ ! -d "tx-fuzz" ]; then \
        git clone "${TX_FUZZ_REPO}"; \
        cd tx-fuzz && git checkout "${TX_FUZZ_BRANCH}"; \
    else \
        cd tx-fuzz && \
        git fetch && \
        git checkout "${TX_FUZZ_BRANCH}"; \
    fi && \
    cd cmd/livefuzzer && go build

#RUN git clone --depth 1 --single-branch --branch "${BEACON_METRICS_GAZER_BRANCH}" "${BEACON_METRICS_GAZER_REPO}" && \
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

RUN if [ ! -d "mock-builder" ]; then \
        git clone "${MOCK_BUILDER_REPO}"; \
        cd mock-builder && git checkout "${MOCK_BUILDER_BRANCH}"; \
    else \
        cd mock-builder && \
        git fetch && \
        git checkout "${MOCK_BUILDER_BRANCH}"; \
    fi && \
    git log -n 1 --format=format:"%H" > /mock-builder.version

RUN cd mock-builder && \
    go build .

ARG ASSERTOR_REPO
ARG ASSERTOR_BRANCH

RUN if [ ! -d "assertoor" ]; then \
        git clone "${ASSERTOR_REPO}"; \
        cd assertoor && git checkout "${ASSERTOR_BRANCH}"; \
    else \
        cd assertoor && \
        git fetch && \
        git checkout "${ASSERTOR_BRANCH}"; \
    fi && \
    git log -n 1 --format=format:"%H" > /assertoor.version

RUN cd assertoor && \
    sed -i '/go cmd.Execute()/i \\tlog.SetOutput(os.Stdout)' main.go && \
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

COPY --from=misc-builder /root/.cargo/bin/jwt /usr/local/bin/jwt
# mock-builder
COPY --from=misc-builder /git/mock-builder/mock-builder /usr/local/bin/mock-builder

#assertoor
COPY --from=misc-builder /git/assertoor/bin/assertoor /usr/local/bin/assertoor


COPY --from=misc-builder /git/grandine/grandine_antithesis /usr/local/bin/grandine
RUN chmod +x /usr/local/bin/grandine

# consensus clients
COPY --from=nimbus-eth2-builder /git/nimbus-eth2/build/nimbus_beacon_node /usr/local/bin/nimbus_beacon_node
COPY --from=nimbus-eth2-builder /nimbus.version /nimbus.version

COPY --from=lighthouse-builder /lighthouse.version /lighthouse.version
COPY --from=lighthouse-builder /git/lighthouse/target/release/lighthouse /usr/local/bin/lighthouse

#COPY --from=lighthouse-builder-inst /git/lighthouse/target/release/lighthouse /opt/antithesis/instrumented/bin/lighthouse

COPY --from=teku-builder  /git/teku/build/install/teku/. /opt/teku
COPY --from=teku-builder /teku.version /teku.version
RUN ln -s /opt/teku/bin/teku /usr/local/bin/teku

# execution clients
COPY --from=geth-builder /geth.version /geth.version
COPY --from=geth-builder /git/go-ethereum/build/bin/geth /usr/local/bin/geth

COPY --from=geth-builder-inst /root/go/bin/geth /opt/antithesis/instrumented/bin/geth
COPY --from=geth-builder-inst /git/geth_instrumented/symbols/* /opt/antithesis/symbols/
COPY --from=geth-builder-inst /git/geth_instrumented/customer /geth_instrumented_code

# COPY --from=prysm-builder /validator /usr/local/bin/

COPY --from=prysm-builder /git/prysm/bazel-bin/cmd/beacon-chain/beacon-chain_/beacon-chain /usr/local/bin/beacon-chain
COPY --from=prysm-builder /git/prysm/bazel-bin/cmd/validator/validator_/validator /usr/local/bin/validator

COPY --from=prysm-builder-inst /prysm.version /prysm.version
COPY --from=prysm-builder-inst /tmp/beacon-chain /opt/antithesis/instrumented/bin/beacon-chain
COPY --from=prysm-builder-inst /tmp/validator /opt/antithesis/instrumented/bin/validator
COPY --from=prysm-builder-inst /git/prysm_instrumented/symbols/* /opt/antithesis/symbols/
COPY --from=prysm-builder-inst /git/prysm_instrumented/customer /prysm_instrumented_code
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
