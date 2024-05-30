# Create nginx reverse proxy service

I created a script to create a reverse proxy service for nginx. The script is 
based on https://docs.btcpayserver.org/Deployment/ReverseProxyToTor. The script
assumes a Debian-based system and will use certbot to obtain a certificate and
upgrade HTTP connections to HTTPS.

# Requirements

- Debian system
- Domain record configured
- Root access
- HTTP or HTTPS service to be proxied

# Usage

1. View the script, [create_nginx_service.sh](create_nginx_service.sh) and make
sure you're comfortable with what it's doing

1. Download the script

        wget https://raw.githubusercontent.com/sudocarlos/sudocarlos.com/main/create_nginx_service.sh

1. Make the script executable

        chmod +x create_nginx_service.sh

1. Run the script as root and specify the domain and address/port to proxy to

        sudo ./create_nginx_service.sh btcpayserver.mydomain.com http://localhost:80

    __More examples__

        sudo ./create_nginx_service.sh mymempooldomain.com http://start9:8080
        sudo ./create_nginx_service.sh lnd.mydomain.com https://start9:3001

# Notes

- __All issuance requests are subject to a Duplicate Certificate limit of 5 per week__
    - https://letsencrypt.org/docs/duplicate-certificate-limit/
- Use `sudo ./create_nginx_service.sh clear DOMAIN` to remove related files from your system. This will remove:
    - /etc/nginx/sites-available/DOMAIN.conf
    - /etc/nginx/sites-enabled/DOMAIN.conf
    - /etc/letsencrypt/live/DOMAIN*
    - /etc/letsencrypt/archive/DOMAIN*
    - /etc/letsencrypt/renewal/DOMAIN*
- If `nginx` or `certbot` are not installed, they are installed using `apt`
- If `/etc/ssl/certs/dhparam.pem` does not exist, a 4096 bit DH params is generated. This can take a while.
- If `/var/lib/letsencrypt/.well-known` does not exist, it is created and appropriate permissions and groups are applied
- If expected map parameters are missing from `/etc/nginx/conf.d/map.conf`, they are added
- New configs are placed in `/etc/nginx/sites-available/` and enabled in `/etc/nginx/sites-enabled`

# Resources

- https://docs.btcpayserver.org/Deployment/ReverseProxyToTor