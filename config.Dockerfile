FROM ethereum-testnet-bootstrapper as builder

ARG CONFIG_PATH="configs/capella-testing.yaml.yaml"

RUN mkdir /data

RUN /source/entrypoint.sh --config ${CONFIG_PATH} --init-testnet --log-level debug

FROM scratch

COPY --from=builder /source/deps /deps 
COPY --from=builder /source/src /src 
COPY --from=builder /data /data 
COPY --from=builder /source/configs /configs 
COPY --from=builder /source/entrypoint.sh /entrypoint.sh 
COPY --from=builder /source/docker-compose.yaml /docker-compose.yaml 

//FROM scratch

//ADD deps deps
//ADD apps apps
//ADD data data
//ADD configs configs
//ADD entrypoint.sh entrypoint.sh
//ADD docker-compose.yaml docker-compose.yaml
