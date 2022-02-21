FROM certbot/certbot

WORKDIR /opt/certbot

COPY docker-entrypoint.sh docker-entrypoint.sh
COPY check_and_renew.py /opt/certbot/tools

RUN apk add --no-cache bash && \
    addgroup -S certbot --gid 101 && \
    adduser -S -g certbot certbot -h /opt/certbot --uid 101 && \
    chmod +x /opt/certbot/docker-entrypoint.sh

ENTRYPOINT ["/opt/certbot/docker-entrypoint.sh"]

