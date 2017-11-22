# variables:
#	- $domain: name of the domain we are setting up

set -e
set -u

read -d '' template <<'nginx_config'
# redirect www to non-www
server {
    listen 80;
    server_name www.{{domain}};
    return 301 http://{{domain}}$request_uri;
}

server {
    listen 80;
    server_name {{domain}};
    root /var/www/{{domain}};

    client_max_body_size 10m;

    add_header X-Codeup Rocks;

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
nginx_config

# make the necessary directories
sudo mkdir -p /var/www/${domain}/uploads
sudo chmod g+rw /var/www/${domain}/uploads
sudo chown -R tomcat:tomcat /var/www/${domain}/uploads

echo "Creating nginx configuration for $domain"
echo $template | sed -e s/{{domain}}/$domain/g | sudo tee /etc/nginx/sites-available/${domain} >/dev/null
sudo ln -sf /etc/nginx/sites-available/${domain} /etc/nginx/sites-enabled/${domain}

echo 'Restarting nginx...'
sudo systemctl restart nginx
