FROM nginx:1.21-alpine

RUN apk add --no-cache openssl bash

RUN mkdir -p /etc/nginx/ssl/dummy /var/www

COPY nginx.conf /etc/nginx/
COPY options-ssl-nginx.conf /etc/nginx/
COPY docker-entrypoint.sh /docker-entrypoint.sh

RUN chmod +x /docker-entrypoint.sh

EXPOSE 8080
EXPOSE 8443

