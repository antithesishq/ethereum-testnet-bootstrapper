FROM scratch

ADD deps deps
ADD src src
ADD data data
ADD configs configs
ADD entrypoint.sh entrypoint.sh
ADD docker-compose.yaml docker-compose.yaml
