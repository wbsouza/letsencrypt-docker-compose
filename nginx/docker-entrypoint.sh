#!/bin/sh

set -e

if [ -z "$DOMAINS" ]; then
  echo "DOMAINS environment variable is not set"
  exit 1;
fi

NGINX_CONF="/etc/nginx/conf.d/default.conf"

if [ ! -f "${NGINX_CONF}" ]; then

  echo "Generating the initial configuration [${NGINX_CONF}]..."
  printf "server_names_hash_bucket_size 64;\n" > "${NGINX_CONF}"

  for domain in $DOMAINS; do

    if [ ! -d "/var/www/html/${domain}" ]; then
      mkdir -p "/var/www/html/${domain}"
      mkdir -p "/etc/nginx/ssl/dummy/${domain}"
      cp -fR /usr/share/nginx/html/*  "/var/www/html/${domain}"
    fi
    cat << EOF >> "${NGINX_CONF}"

server {
    listen 80;
    server_name ${domain};

    location /.well-known/acme-challenge/ {
        root /etc/letsencrypt/live/${domain};
    }

    location / {
        return 301 https://\$host\$request_uri;
    }
}


server {
    listen       443 ssl;
    server_name  ${domain};
    ssl_certificate      /etc/nginx/ssl/dummy/${domain}/fullchain.pem;
    ssl_certificate_key  /etc/nginx/ssl/dummy/${domain}/privkey.pem;
    include     /etc/nginx/options-ssl-nginx.conf;
    ssl_dhparam /etc/nginx/ssl/ssl-dhparams.pem;
    location / {
        root     /var/www/html/${domain};
    }
}

EOF

  done
fi


for domain in $DOMAINS; do
  if [ ! -f "/etc/nginx/ssl/dummy/$domain/fullchain.pem" ]; then
    echo "Generating dummy ceritificate for $domain"
    mkdir -p "/etc/nginx/ssl/dummy/$domain"
    printf "[dn]\nCN=${domain}\n[req]\ndistinguished_name = dn\n[EXT]\nsubjectAltName=DNS:${domain}, DNS:${domain}\nkeyUsage=digitalSignature\nextendedKeyUsage=serverAuth" > openssl.cnf
    openssl req -x509 -out "/etc/nginx/ssl/dummy/$domain/fullchain.pem" -keyout "/etc/nginx/ssl/dummy/${domain}/privkey.pem" \
      -newkey rsa:2048 -nodes -sha256 \
      -subj "/CN=${domain}" -extensions EXT -config openssl.cnf
    rm -f openssl.cnf
  fi
done

if [ ! -f /etc/nginx/ssl/ssl-dhparams.pem ]; then
  openssl dhparam -out /etc/nginx/ssl/ssl-dhparams.pem 2048
fi

use_lets_encrypt_certificates() {
  domain=$1
  echo "Switching Nginx to use Let's Encrypt certificate for $domain"
  sed -i "s|/etc/nginx/ssl/dummy/$domain|/etc/letsencrypt/live/$domain|g" /etc/nginx/conf.d/default.conf
}

reload_nginx() {
  echo "Reloading Nginx configuration"
  nginx -s reload
}

wait_for_lets_encrypt() {
  domain=$1
  cert_filename="/etc/letsencrypt/live/${domain}/fullchain.pem"
  until [ -f $cert_filename ]; do
    echo "Waiting for Let's Encrypt certificates for $domain"
    sleep 5s & wait ${!}
  done
  use_lets_encrypt_certificates "$domain"
  reload_nginx
}


for domain in $DOMAINS; do
  if [ ! -f "/etc/letsencrypt/live/$domain/fullchain.pem" ]; then
    wait_for_lets_encrypt "$domain" &
  else
    use_lets_encrypt_certificates "$domain"
  fi
done

exec nginx  -g "daemon off;"


