FROM ethereum-testnet-bootstrapper:latest-deneb as builder

RUN mkdir /data

RUN /source/entrypoint.sh --config configs/deneb-devnet-7.yaml --init-testnet --log-level debug

FROM scratch

COPY --from=builder /source/deps /deps 
COPY --from=builder /source/src /src 
COPY --from=builder /data /data 
COPY --from=builder /source/configs /configs 
COPY --from=builder /source/entrypoint.sh /entrypoint.sh 
COPY --from=builder /source/docker-compose.yaml /docker-compose.yaml 
# ADD deps deps
# ADD src src
# ADD data data
# ADD configs configs
# ADD entrypoint.sh entrypoint.sh
# ADD docker-compose.yaml docker-compose.yaml
