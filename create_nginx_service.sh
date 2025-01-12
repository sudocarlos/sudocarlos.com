#!/usr/bin/env bash

# check if script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root: sudo -i"
  exit 1
fi

if [[ "$1" == "clear" && ! -z $2 ]]; then
  echo "Deleting $2 files..."
  rm -rfv /etc/nginx/sites-available/$2.conf /etc/nginx/sites-enabled/$2.conf /etc/letsencrypt/live/$2* /etc/letsencrypt/archive/$2* /etc/letsencrypt/renewal/$2*
  exit 2
fi

# read command line arguments and warn if missing
if [[ -z $1 || -z $2 ]]; then
  echo "WARNING! Please pass URL and SERVICE_ADDRESS as arguments, for example:
./create_nginx_service.sh btcpayserver.mydomain.com http://localhost:8081"
  exit 1
fi
URL=$1
SERVICE_ADDRESS=$2

# check if certbot is installed
if ! which certbot > /dev/null 2>&1 ; then
  echo "installing certbot..."
  apt install certbot -y
fi

# check if nginx is installed
if ! which nginx > /dev/null 2>&1 ; then
  echo "installing nginx..."
  apt install nginx -y
fi

# generate 4096 bit DH params to strengthen the security, may take a while
if [ ! -f '/etc/ssl/certs/dhparam.pem' ]; then
  echo "generate 4096 bit DH params..."
  openssl dhparam -out /etc/ssl/certs/dhparam.pem 4096
fi

# create directory for Let's Encrypt files
if [ ! -d '/var/lib/letsencrypt/.well-known' ]; then
  echo "create directory for Let's Encrypt files..."
  mkdir -p /var/lib/letsencrypt/.well-known
  chgrp www-data /var/lib/letsencrypt
  chmod g+s /var/lib/letsencrypt
fi

# Create a variable mapping to forward the correct protocol setting and check 
# if the Upgrade header is sent by the client
if ! grep -q "map \$http_x_forwarded_proto \$proxy_x_forwarded_proto" /etc/nginx/conf.d/map.conf; then
echo "Create a variable mapping to forward the correct protocol setting..."
cat << EOF >> /etc/nginx/conf.d/map.conf
map \$http_x_forwarded_proto \$proxy_x_forwarded_proto {
  default \$http_x_forwarded_proto;
  ''      \$scheme;
}
EOF
fi

if ! grep -q "map \$http_upgrade \$connection_upgrade" /etc/nginx/conf.d/map.conf; then
echo "check if the Upgrade header is sent by the client..."
cat << EOF >> /etc/nginx/conf.d/map.conf
map \$http_upgrade \$connection_upgrade {
  default upgrade;
  ''      close;
}
EOF
fi

# Exit if a config file for the domain already exists
check_if_file_exists() {
  if [ -f $1 ]; then
    echo "WARNING! The following files exist and will not be modified"
    for i in /etc/nginx/sites-available/$URL.conf /etc/nginx/sites-enabled/$URL.conf /etc/letsencrypt/live/$URL/fullchain.pem /etc/letsencrypt/live/$URL/privkey.pem; do
      if [ -f $i ]; then
        echo $i
      fi
    done
    exit 1
  fi
}

# Create a config file for the domain
check_if_file_exists /etc/nginx/sites-available/$URL.conf
echo "creating a nginx conf: /etc/nginx/sites-available/$URL.conf..."
cat << EOF > /etc/nginx/sites-available/$URL.conf
server {
  listen 80;
  server_name $URL;

  # Let's Encrypt verification requests
  location ^~ /.well-known/acme-challenge/ {
    allow all;
    root /var/lib/letsencrypt/;
    default_type "text/plain";
    try_files \$uri =404;
  }

  # Redirect everything else to https
  location / {
    return 301 https://\$server_name\$request_uri;
  }
}
EOF

# Enable the web server config by creating a symlink and restarting nginx
echo "Enable the web server config by creating a symlink: /etc/nginx/sites-enabled/$URL.conf..."
ln -s /etc/nginx/sites-available/$URL.conf /etc/nginx/sites-enabled/$URL.conf
echo "restarting nginx..."
systemctl restart nginx

# Obtain SSL certificate via Let's Encrypt
check_if_file_exists /etc/letsencrypt/live/$URL/fullchain.pem
check_if_file_exists /etc/letsencrypt/live/$URL/privkey.pem
echo "Obtain SSL certificate via Let's Encrypt..."
if ! certbot certonly --agree-tos --email admin@$URL --webroot -w /var/lib/letsencrypt/ -d $URL; then
  echo "Failed to obtain certificate, removing /etc/nginx/sites-available/$URL.conf and /etc/nginx/sites-enabled/$URL.conf and restarting nginx..."
  rm /etc/nginx/sites-available/$URL.conf /etc/nginx/sites-enabled/$URL.conf
  systemctl restart nginx
  exit 1
fi

# Now that we have a valid SSL certificate, add the https server part at the
# end of /etc/nginx/sites-available/$URL.conf
echo "add the https server part at the end of /etc/nginx/sites-available/$URL.conf..."
cat << EOF >> /etc/nginx/sites-available/$URL.conf
server {
  listen 443 ssl;
  listen [::]:443 ssl;
  http2 on;

  server_name $URL;

  # SSL settings
  ssl_stapling on;
  ssl_stapling_verify on;

  ssl_session_timeout 1d;
  ssl_session_cache shared:SSL:10m;
  ssl_session_tickets off;

  # Update this with the path of your certificate files
  ssl_certificate /etc/letsencrypt/live/$URL/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/$URL/privkey.pem;

  ssl_dhparam /etc/ssl/certs/dhparam.pem;
  ssl_protocols TLSv1.2 TLSv1.3;
  ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
  ssl_prefer_server_ciphers off;

  resolver 8.8.8.8 8.8.4.4 valid=300s;
  resolver_timeout 30s;

  # Security / XSS Mitigation Headers
  # NOTE: X-Frame-Options may cause issues with the webOS app
  add_header X-Frame-Options "SAMEORIGIN";
  add_header X-Content-Type-Options "nosniff";

  # Permissions policy. May cause issues with some clients
  add_header Permissions-Policy "accelerometer=(), ambient-light-sensor=(), battery=(), bluetooth=(), camera=(), clipboard-read=(), display-capture=(), document-domain=(), encrypted-media=(), gamepad=(), geolocation=(), gyroscope=(), hid=(), idle-detection=(), interest-cohort=(), keyboard-map=(), local-fonts=(), magnetometer=(), microphone=(), payment=(), publickey-credentials-get=(), serial=(), sync-xhr=(), usb=(), xr-spatial-tracking=()" always;

  # Content Security Policy
  # See: https://developer.mozilla.org/en-US/docs/Web/HTTP/CSP
  # Enforces https content and restricts JS/CSS to origin
  # External Javascript (such as cast_sender.js for Chromecast) must be whitelisted.
  # NOTE: The default CSP headers may cause issues with the webOS app
  add_header Content-Security-Policy "default-src https: data: blob: ; img-src 'self' https://* ; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline' https://www.gstatic.com https://www.youtube.com blob:; worker-src 'self' blob:; connect-src 'self'; object-src 'none'; frame-ancestors 'self'";

  location / {
    # Proxy main Jellyfin traffic
    proxy_pass $SERVICE_ADDRESS;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Forwarded-Protocol \$scheme;
    proxy_set_header X-Forwarded-Host \$http_host;

    # Disable buffering when the nginx proxy gets very resource heavy upon streaming
    proxy_buffering off;
  }

  location /socket {
      # Proxy Jellyfin Websockets traffic
      proxy_pass $SERVICE_ADDRESS;
      proxy_http_version 1.1;
      proxy_set_header Upgrade \$http_upgrade;
      proxy_set_header Connection "upgrade";
      proxy_set_header Host \$host;
      proxy_set_header X-Real-IP \$remote_addr;
      proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto \$scheme;
      proxy_set_header X-Forwarded-Protocol \$scheme;
      proxy_set_header X-Forwarded-Host \$http_host;
  }
}
EOF

# Restart nginx once more
echo "Restart nginx once more..."
systemctl restart nginx
echo "Try it: https://$URL"
