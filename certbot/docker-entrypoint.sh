#!/bin/bash

set -e

trap exit INT TERM

if [ -e /etc/config.env ]; then
  . /etc/config.env
fi


if [ -z "$DOMAINS" ]; then
  echo "DOMAINS environment variable is not set"
  exit 1;
fi

until nc -z nginx 80; do
  echo "Waiting for nginx to start..."
  sleep 5s & wait ${!}
done

if [ "$CERTBOT_TEST_CERT" != "0" ]; then
  test_cert_arg="--test-cert"
fi


domain_list=($DOMAINS)
for i in "${!domain_list[@]}"; do

  domain="${domain_list[i]}"
  cert_dir="/etc/letsencrypt/live/$domain"
  full_cert_chain="${cert_dir}/fullchain.pem"
  if [ -L ${full_cert_chain} ] && [ -e ${full_cert_chain} ]; then
    continue
  else
    echo ">>>>>>> will issue a certificate"	  
  fi

  mkdir -p "${cert_dir}"
  echo "Obtaining the certificate for $domain"

  if [ -z "${emails_list[i]}" ]; then
    email_arg="--register-unsafely-without-email"
  else
    email_arg="--email ${CERTBOT_EMAIL}"
  fi

  echo "------------------- trying get cert now ...."
  certbot certonly \
    --webroot \
    -w "/etc/letsencrypt/live/$domain" -d "$domain" \
    $test_cert_arg \
    $email_arg \
    --rsa-key-size "${CERTBOT_RSA_KEY_SIZE:-4096}" \
    --agree-tos \
    --noninteractive || true
done


last_date=$(date +%Y%m%d)
while true; do
  curr_date=$(date +%Y%m%d)
  diff=$[ $curr_date - $last_date ]
  if [ "${diff}" -gt 10 ]; then
    certbot renew --dry-run 
    last_date=$curr_date
  fi
  sleep 30s
done

