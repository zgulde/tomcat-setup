# variables
#	- $domain: the domain to enable ssl for
#	- $email: email address for letsencrypt

set -e
set -u

read -d '' nginx_config <<conf
# redirect non-https to https and www to non-www
server {
    listen 80;
    server_name {{domain}} www.{{domain}};
    return 301 https://{{domain}}$request_uri;
}

server {
    server_name  {{domain}};
    root /var/www/{{domain}};

    client_max_body_size 10m;

    add_header X-Codeup Rocks;

    listen       443 ssl;

    ssl on;
    ssl_certificate /etc/letsencrypt/live/{{domain}}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/{{domain}}/privkey.pem;
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2; # disable SSLv3

    # allow letsencrypt domain verification
    location ~ \.well-known {
        allow all;
    }

    location ~ ^/uploads/ {
        try_files $uri =404;
    }

    access_log off;
    # uncomment the line below to enable logging
    # access_log /var/log/nginx/{{domain}}-access.log;
    error_log /var/log/nginx/{{domain}}-error.log;

    location / {
        proxy_set_header X-Real-IP  $remote_addr;
        proxy_set_header X-Forwarded-For $remote_addr;
        proxy_set_header Host $host;
        proxy_pass_request_headers on;
        proxy_pass http://localhost:8080/;
    }
}
conf

# ensure directory exists
mkdir -p /srv/${domain}

echo "Requesting webroot verification for $domain..."
sudo letsencrypt certonly\
	--authenticator webroot\
	--webroot-path=/var/www/${domain}\
	--domain ${domain}\
	--agree-tos\
	--email $email\
	--renew-by-default >> /srv/letsencrypt.log

echo "Setting up nginx config to serve ${domain} over https..."
echo $nginx_config | sed -e s/{{domain}}/${domain}/g | sudo tee /etc/nginx/sites-available/${domain} >/dev/null
echo 'Restarting nginx...'
sudo systemctl restart nginx
