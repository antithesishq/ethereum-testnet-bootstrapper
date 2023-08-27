FROM ethereum-testnet-bootstrapper as builder

ARG CONFIG_PATH="configs/capella-testing.yaml"

RUN mkdir /data

RUN mkdir /source/data
RUN touch /source/data/testnet_bootstrapper.log

RUN ls /source
RUN ls /source/configs
RUN ls /source/configs/minimal

RUN /source/entrypoint.sh --config "/source/configs/minimal/capella-testing.yaml" --init-testnet --log-level debug

RUN ls /data
RUN ls /source/data
RUN cp /source/data/testnet_bootstrapper.log /data
RUN ls /data

FROM scratch

COPY --from=builder /source/deps /deps 
#COPY --from=builder /source/src /src 
COPY --from=builder /data /data 
COPY --from=builder /source/configs /configs 
COPY --from=builder /source/apps /apps
COPY --from=builder /source/entrypoint.sh /entrypoint.sh 
COPY --from=builder /source/docker-compose.yaml /docker-compose.yaml 

#FROM scratch

#ADD deps deps
#ADD apps apps
#ADD data data
#ADD configs configs
#ADD entrypoint.sh entrypoint.sh
#ADD docker-compose.yaml docker-compose.yaml
