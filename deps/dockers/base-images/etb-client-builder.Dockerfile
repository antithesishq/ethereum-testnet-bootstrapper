FROM debian:bullseye-slim
# We use clang as the compiler
# we build a nodejs+go+rust+dotnet env
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    libpcre3-dev \
    lsb-release \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    wget \
    tzdata \
    bash \
    python3-dev \
    gnupg \
    cmake \
    libc6 \
    libc6-dev \
    libsnappy-dev \
    git

RUN apt-get install -y --no-install-recommends \
    openjdk-17-jdk

# set up dotnet
RUN wget https://packages.microsoft.com/config/debian/11/packages-microsoft-prod.deb -O packages-microsoft-prod.deb && dpkg -i packages-microsoft-prod.deb && rm packages-microsoft-prod.deb
RUN apt update && apt install -y dotnet-sdk-7.0

WORKDIR /git

# set up clang 14
RUN wget --no-check-certificate https://apt.llvm.org/llvm.sh && chmod +x llvm.sh && ./llvm.sh 15
ENV LLVM_CONFIG=llvm-config-15

# set up go
RUN wget https://go.dev/dl/go1.19.6.linux-amd64.tar.gz
RUN tar -zxvf go1.19.6.linux-amd64.tar.gz -C /usr/local/
RUN ln -s /usr/local/go/bin/go /usr/local/bin/go
RUN ln -s /usr/local/go/bin/gofmt /usr/local/bin/gofmt

# set up nodejs
# Install nodejs
run apt update \
    && apt install curl ca-certificates -y --no-install-recommends \
    && curl -sL https://deb.nodesource.com/setup_18.x | bash -
run apt-get update && apt-get install -y --no-install-recommends nodejs 

# set up cargo/rustc
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- --default-toolchain stable -y
ENV PATH="$PATH:/root/.cargo/bin"

# Build rocksdb 
RUN git clone --depth=1 https://github.com/facebook/rocksdb.git
RUN cd rocksdb && make -j4 install

# Antithesis instrumentation resources
COPY lib/libvoidstar.so /usr/lib/libvoidstar.so
RUN mkdir -p /opt/antithesis/
COPY go_instrumentation /opt/antithesis/go_instrumentation
RUN /opt/antithesis/go_instrumentation/bin/goinstrumentor -version

RUN npm install -g npm@latest
RUN npm install -g @bazel/bazelisk

ENTRYPOINT ["/bin/bash"]
