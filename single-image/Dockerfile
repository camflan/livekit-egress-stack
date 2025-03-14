FROM livekit/egress:v1.9

USER root

RUN apt-get update && apt-get -y install lsb-release curl gpg jq \
    && curl -fsSL https://packages.redis.io/gpg | gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg \
    && chmod 644 /usr/share/keyrings/redis-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/redis.list \
    && apt-get update \
    && apt-get install -y redis


# install livekit server
RUN curl -sSL https://get.livekit.io | bash

# install livekit-cli
RUN curl -sSL https://get.livekit.io/cli | bash

ADD ./egress-config.yaml ./server-config.yaml ./docker-entrypoint.sh ./start-web-stream.sh /

USER egress
ENTRYPOINT ["/docker-entrypoint.sh"]
