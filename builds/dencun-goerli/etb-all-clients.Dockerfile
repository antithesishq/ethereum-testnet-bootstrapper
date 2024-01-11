###############################################################################
#           Dockerfile to build all clients mainnet preset.           #
###############################################################################
# Consensus Clients
ARG LIGHTHOUSE_REPO="https://github.com/sigp/lighthouse"
ARG LIGHTHOUSE_BRANCH="v4.6.0-rc.0"

ARG PRYSM_REPO="https://github.com/prysmaticlabs/prysm.git"
ARG PRYSM_BRANCH="v4.2.0-rc.1"

ARG LODESTAR_REPO="https://github.com/ChainSafe/lodestar.git"
ARG LODESTAR_BRANCH="v1.14.0-rc.1"

ARG NIMBUS_ETH2_REPO="https://github.com/status-im/nimbus-eth2.git"
ARG NIMBUS_ETH2_BRANCH="multiarch-v24.1.1"

ARG TEKU_REPO="https://github.com/ConsenSys/teku.git"
ARG TEKU_BRANCH="24.1.0"

ARG BESU_REPO="https://github.com/hyperledger/besu.git"
ARG BESU_BRANCH="24.1.0"

ARG GETH_REPO="https://github.com/ethereum/go-ethereum.git"
ARG GETH_BRANCH="v1.13.9"

ARG NETHERMIND_REPO="https://github.com/NethermindEth/nethermind.git"
ARG NETHERMIND_BRANCH="1.25.0"

# ARG ETHEREUMJS_REPO="https://github.com/ethereumjs/ethereumjs-monorepo.git"
# ARG ETHEREUMJS_BRANCH="stable-3981bca"

# ARG ERIGON_REPO="https://github.com/ledgerwatch/erigon"
# ARG ERIGON_BRANCH="v2.56.1"

ARG RETH_REPO="https://github.com/paradigmxyz/reth"
ARG RETH_BRANCH="v0.1.0-alpha.14"

ARG TX_FUZZ_REPO="https://github.com/MariusVanDerWijden/tx-fuzz"
ARG TX_FUZZ_BRANCH="d8b943f3abab4bd8bd63cdfc8c45b8cb71fbb3f2"

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
RUN apt-get update && apt-get install -y \
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
    openssl \
    libssl-dev \
    git \
    git-lfs \
    protobuf-compiler \
    libprotobuf-dev \
    gcc \
    g++ \
    pkg-config \
    llvm-dev \
    libclang-dev \
    clang


RUN ln -s /usr/local/bin/python3 /usr/local/bin/python

# set up dotnet (nethermind)
RUN wget https://dot.net/v1/dotnet-install.sh -O dotnet-install.sh && \
    chmod +x dotnet-install.sh && \
    ./dotnet-install.sh --channel 8.0
ENV PATH="$PATH:/root/.dotnet/"

WORKDIR /git

RUN mkdir -p /git/bin
RUN mkdir -p /git/lib
RUN mkdir -p /git/race/bin
RUN mkdir -p /git/inst/bin


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
RUN apt-get update && \
    apt-get install -y ca-certificates curl gnupg && \
    mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_18.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list && \
    apt-get update && \
    apt-get install nodejs -y && \
    npm install --global yarn && \
    npm install -g @bazel/bazelisk


# setup cargo/rustc (lighthouse)
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- --default-toolchain stable -y
ENV PATH="$PATH:/root/.cargo/bin"

# Build rocksdb
#RUN git clone --depth 500 --no-single-branch --no-tags https://github.com/facebook/rocksdb.git
#RUN cd rocksdb && make -j16 install

############################# Consensus  Clients  #############################
# LIGHTHOUSE

ARG LIGHTHOUSE_BRANCH
ARG LIGHTHOUSE_REPO
RUN git clone --depth 500 --no-single-branch --no-tags "${LIGHTHOUSE_REPO}" && \
    cd lighthouse && \
    git checkout "${LIGHTHOUSE_BRANCH}" && \
    git log -n 1 --format=format:"%H" > /lighthouse.version

RUN cd lighthouse && \
    cargo update -p proc-macro2 && \
    cargo build --release --manifest-path lighthouse/Cargo.toml --bin lighthouse && \
    mv /git/lighthouse/target/release/lighthouse /git/bin/lighthouse

# Antithesis instrumented lighthouse binary
RUN cd lighthouse && CARGO_PROFILE_RELEASE_BUILD_OVERRIDE_DEBUG=true RUST_BACKTRACE=1 LD_LIBRARY_PATH=/usr/lib/ RUSTFLAGS="-Cpasses=sancov-module -Cllvm-args=-sanitizer-coverage-level=3 -Cllvm-args=-sanitizer-coverage-trace-pc-guard -Ccodegen-units=1 -Cdebuginfo=2 -L/usr/lib/ -lvoidstar" cargo build --release --manifest-path lighthouse/Cargo.toml --bin lighthouse && \
cp /git/lighthouse/target/release/lighthouse /git/inst/bin/lighthouse

# LODESTAR
ARG LODESTAR_BRANCH
ARG LODESTAR_REPO
RUN git clone --depth 500 --no-single-branch --no-tags "${LODESTAR_REPO}" && \
    cd lodestar && \
    git checkout "${LODESTAR_BRANCH}" && \
    git log -n 1 --format=format:"%H" > /lodestar.version

RUN cd lodestar && \
    yarn install --non-interactive --frozen-lockfile && \
    yarn build && \
    yarn install --non-interactive --frozen-lockfile --production

RUN cp /git/lodestar/node_modules/.bin/lodestar /git/bin/lodestar


# NIMBUS-builder
ARG NIMBUS_ETH2_BRANCH
ARG NIMBUS_ETH2_REPO
RUN git clone --depth 500 --no-single-branch --no-tags "${NIMBUS_ETH2_REPO}" && \
    cd nimbus-eth2 && \
    git checkout "${NIMBUS_ETH2_BRANCH}" && \
    git log -n 1 --format=format:"%H" > /nimbus.version && \
    make -j16 update

RUN cd nimbus-eth2 && \
    arch=$(arch | sed s/aarch64/arm64/ | sed s/x86_64/amd64/) && \
    make -j16 nimbus_beacon_node NIMFLAGS="-d:disableMarchNative --cpu:${arch} --cc:clang --clang.exe:clang-15 --clang.linkerexe:clang-15 --passC:-fno-lto --passL:-fno-lto" && \
    mv /git/nimbus-eth2/build/nimbus_beacon_node /git/bin/nimbus_beacon_node

# TEKU
ARG TEKU_BRANCH
ARG TEKU_REPO
RUN git clone --depth 500 --no-single-branch --no-tags "${TEKU_REPO}" && \
    cd teku && \
    git checkout "${TEKU_BRANCH}" && \
    git submodule update --init --recursive && \
    git log -n 1 --format=format:"%H" > /teku.version

RUN cd teku && \
    ./gradlew installDist && \
    mv /git/teku/build/install/teku/bin/teku /git/bin

# PRYSM
ARG PRYSM_BRANCH
ARG PRYSM_REPO
RUN git clone --depth 500 --no-single-branch --no-tags "${PRYSM_REPO}" && \
    cd prysm && \
    git checkout "${PRYSM_BRANCH}" && \
    git log -n 1 --format=format:"%H" > /prysm.version

RUN cd prysm && \
    bazelisk build --config=release //cmd/beacon-chain:beacon-chain //cmd/validator:validator && \
    cp /git/prysm/bazel-bin/cmd/beacon-chain/beacon-chain_/beacon-chain /git/bin/beacon-chain && \
    cp /git/prysm/bazel-bin/cmd/validator/validator_/validator /git/bin/validator

RUN cd prysm && \
   go build -race -o /git/race/bin/validator ./cmd/validator && \
   go build -race -o /git/race/bin/beacon-chain ./cmd/beacon-chain

# Antithesis instrumented prysm binary
RUN mkdir /git/lib/prysm_instrumented && \
    /opt/antithesis/go_instrumentation/bin/goinstrumentor \
    -logtostderr -stderrthreshold=INFO \
    -antithesis /opt/antithesis/go_instrumentation/instrumentation/go/wrappers \
    prysm /git/lib/prysm_instrumented

RUN cd /git/lib/prysm_instrumented/customer && go build -o /git/inst/bin/validator ./cmd/validator
RUN cd /git/lib/prysm_instrumented/customer && go build -o /git/inst/bin/beacon-chain ./cmd/beacon-chain
RUN cd /git/lib/prysm_instrumented/customer && go build -race -o /git/inst/bin/validator_race ./cmd/validator
RUN cd /git/lib/prysm_instrumented/customer && go build -race -o /git/inst/bin/beacon-chain_race ./cmd/beacon-chain

############################# Execution  Clients  #############################
# Geth
#RUN git config --global pack.window 1

ARG GETH_BRANCH
ARG GETH_REPO

RUN wget "https://codeload.github.com/ethereum/go-ethereum/zip/${GETH_BRANCH}" && \
    unzip -q "${GETH_BRANCH}" && \
    mv go-ethereum-${GETH_BRANCH} go-ethereum && \
    echo "${GETH_BRANCH}" > /geth.version && \
    cd go-ethereum && \
    go build -o /git/bin/geth -ldflags "-X github.com/ethereum/go-ethereum/internal/version.gitCommit=v1.13.9 -X github.com/ethereum/go-ethereum/internal/version.gitDate=$(date '+%Y-%m-%d') -extldflags '-Wl,-z,stack-size=0x800000'" -tags urfave_cli_no_docs,ckzg -trimpath -v ./cmd/geth && \
    go build -o /git/race/bin/geth -race -ldflags "-X github.com/ethereum/go-ethereum/internal/version.gitCommit=v1.13.9 -X github.com/ethereum/go-ethereum/internal/version.gitDate=$(date '+%Y-%m-%d') -extldflags '-Wl,-z,stack-size=0x800000'" -tags urfave_cli_no_docs,ckzg -trimpath -v ./cmd/geth 
# RUN git clone --depth 500 --no-single-branch --no-tags "${GETH_REPO}" && \
#     cd go-ethereum && \
#     git checkout "${GETH_BRANCH}" && \
#     git log -n 1 --format=format:"%H" > /geth.version && \
#     go build -o /git/bin/geth ./cmd/geth && \
#     go build -race -o /git/race/bin/geth /git/bin/geth

# Antithesis add instrumentation
RUN mkdir -p /git/lib/geth_instrumented

RUN /opt/antithesis/go_instrumentation/bin/goinstrumentor \
    -logtostderr -stderrthreshold=INFO \
    -antithesis /opt/antithesis/go_instrumentation/instrumentation/go/wrappers \
    go-ethereum /git/lib/geth_instrumented && \
    cd /git/lib/geth_instrumented/customer && \
    make geth && \
    cp ./build/bin/geth /git/inst/bin/geth && \
    go build -race -o /git/inst/bin/geth_race ./cmd/geth

# Besu
ARG BESU_REPO
ARG BESU_BRANCH
RUN git clone --depth 500 --no-single-branch --no-tags "${BESU_REPO}" && \
    cd besu && \
    git checkout "${BESU_BRANCH}" && \
    git log -n 1 --format=format:"%H" > /besu.version

RUN cd besu && \
    ./gradlew installDist && \
    cp /git/besu/build/install/besu/bin/besu /git/bin/besu && \
    cp -r /git/besu/build/install/besu /git/lib/besu

# Nethermind
ARG NETHERMIND_REPO
ARG NETHERMIND_BRANCH
RUN git clone --depth 500 --no-single-branch --no-tags "${NETHERMIND_REPO}" && \
    cd nethermind && \
    git checkout "${NETHERMIND_BRANCH}" && \
    git log -n 1 --format=format:"%H" > /nethermind.version && \
    dotnet publish -p:PublishReadyToRun=false src/Nethermind/Nethermind.Runner -c release -o /git/lib/nethermind && \
    cp /git/lib/nethermind/nethermind /git/bin/nethermind

# # EthereumJS
#
# ARG ETHEREUMJS_REPO
# ARG ETHEREUMJS_BRANCH
# RUN git clone --depth 500 --no-single-branch -b ${ETHEREUMJS_BRANCH} "${ETHEREUMJS_REPO}" && \
#     cd ethereumjs-monorepo && \
#     git log -n 1 --format=format:"%H" > /ethereumjs.version

# RUN cd ethereumjs-monorepo && \
#     npm install && \
#     npm run build --workspaces

# # Erigon
#
# ARG ERIGON_REPO
# ARG ERIGON_BRANCH
# RUN git clone "${ERIGON_REPO}" && \
#     cd ERIGON && \
#     git checkout "${ERIGON_BRANCH}" && \
#     git log -n 1 --format=format:"%H" > /ERIGON.version

# RUN cd ERIGON && \

# RETH
ARG RETH_BRANCH
ARG RETH_REPO
RUN git clone --depth 500 --no-single-branch --no-tags "${RETH_REPO}" && \
    cd reth && \
    git checkout "${RETH_BRANCH}" && \
    git log -n 1 --format=format:"%H" > /reth.version && \
    cargo build --release --bin reth && \
    cp /git/reth/target/release/reth /git/bin/reth

# Antithesis instrumented reth binary
RUN cd reth && \ 
    CARGO_PROFILE_RELEASE_BUILD_OVERRIDE_DEBUG=true RUST_BACKTRACE=1 LD_LIBRARY_PATH=/usr/lib/ RUSTFLAGS="-Cpasses=sancov-module -Cllvm-args=-sanitizer-coverage-level=3 -Cllvm-args=-sanitizer-coverage-trace-pc-guard -Ccodegen-units=1 -Cdebuginfo=2 -L/usr/lib/ -lvoidstar" cargo build --release --bin reth && \
    cp /git/reth/target/release/reth /git/inst/bin/reth


############################### Misc.  Modules  ###############################
ARG TX_FUZZ_BRANCH
ARG TX_FUZZ_REPO
ARG BEACON_METRICS_GAZER_REPO
ARG BEACON_METRICS_GAZER_BRANCH

RUN go install github.com/wealdtech/ethereal/v2@latest \
    &&  go install github.com/wealdtech/ethdo@latest \
    && go install github.com/protolambda/eth2-val-tools@latest \
    && cp /root/go/bin/ethereal /git/bin/ \
    && cp /root/go/bin/ethdo /git/bin/ \
    && cp /root/go/bin/eth2-val-tools /git/bin/

RUN git clone --depth 500 --no-single-branch --no-tags "${TX_FUZZ_REPO}" && \
    cd tx-fuzz && \
    git checkout "${TX_FUZZ_BRANCH}" && \
    go build -o /git/bin/livefuzzer ./cmd/livefuzzer 

RUN git clone --depth 500 --no-single-branch --no-tags "${BEACON_METRICS_GAZER_REPO}" && \
    cd beacon-metrics-gazer && \
    git checkout "${BEACON_METRICS_GAZER_BRANCH}" && \
    cargo update -p proc-macro2 && \
    cargo build --release --bin beacon-metrics-gazer && \
    cp /git/beacon-metrics-gazer/target/release/beacon-metrics-gazer /git/bin/beacon-metrics-gazer

# jwt-cli to interact with the execution client
RUN cargo install --root /git/bin jwt-cli

ARG MOCK_BUILDER_REPO
ARG MOCK_BUILDER_BRANCH
RUN git clone --depth 500 --no-single-branch --branch "${MOCK_BUILDER_BRANCH}" "${MOCK_BUILDER_REPO}" && \
    cd mock-builder && \
    go build -o /git/bin/mock-builder ./main.go

########################### etb-all-clients runner  ###########################
FROM debian:bullseye-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libgflags-dev \
    libsnappy-dev \
    zlib1g-dev \
    libbz2-dev \
    liblz4-dev \
    libzstd-dev \
    openjdk-17-jdk \
    python3-dev \
    python3-pip \
    jq \
    xxd \
    ca-certificates \
    curl \
    gnupg \
    wget \ 
    lsb-release \ 
    software-properties-common 


# Antithesis instrumentation files
COPY instrumentation/lib/libvoidstar.so /usr/lib/libvoidstar.so
RUN mkdir -p /opt/antithesis/
COPY instrumentation/go_instrumentation /opt/antithesis/go_instrumentation
RUN /opt/antithesis/go_instrumentation/bin/goinstrumentor -version

RUN mkdir -p /opt/bin
RUN mkdir -p /opt/lib
RUN mkdir -p /opt/race/bin
RUN mkdir -p /opt/inst/bin

RUN wget https://dot.net/v1/dotnet-install.sh -O dotnet-install.sh && \
    chmod +x dotnet-install.sh && \
    ./dotnet-install.sh --channel 8.0

ENV PATH="$PATH:/root/.dotnet/:/opt/bin"
ENV DOTNET_ROOT=/root/.dotnet

# install node to run lodestar
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_18.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list && \
    apt update && \
    apt install --no-install-recommends nodejs -y

RUN pip3 install ruamel.yaml web3 pydantic

# for coverage artifacts and runtime libraries.
RUN wget --no-check-certificate https://apt.llvm.org/llvm.sh && \
    chmod +x llvm.sh && \
    ./llvm.sh 15

ENV LLVM_CONFIG=llvm-config-15

COPY --from=etb-client-builder /git/lib/* /opt/lib
COPY --from=etb-client-builder /git/bin/* /opt/bin
COPY --from=etb-client-builder /git/race/bin/* /opt/race/bin
COPY --from=etb-client-builder /git/inst/bin/* /opt/inst/bin



