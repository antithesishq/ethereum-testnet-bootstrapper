FROM ethereum-testnet-bootstrapper as builder

ARG CONFIG_PATH=""

RUN mkdir -p /data

COPY ./configs /configs

RUN /source/entrypoint.sh --config ${CONFIG_PATH} --init-testnet --log-level debug

FROM scratch

COPY --from=builder /source/deps /deps 
COPY --from=builder /source/src /src 
COPY --from=builder /data /data
COPY --from=builder /source/configs /configs 
COPY --from=builder /source/entrypoint.sh /entrypoint.sh 
COPY --from=builder /source/docker-compose.yaml /docker-compose.yaml 
