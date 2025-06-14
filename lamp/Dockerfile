FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive

RUN ln -snf /usr/share/zoneinfo/Europe/Vienna /etc/localtime && echo Europe/Vienna > /etc/timezone
RUN dpkg --configure -a

RUN apt update && apt install -y nginx php8.1-fpm mariadb-server php-mysqli acl

RUN cat <<'EOF' > /etc/nginx/sites-available/default
server {
        listen 80 default_server;
        root /var/www/html;
        index index.php index.html index.nginx-debian.html;
        server_name _;
        location / {
                try_files $uri $uri/ =404;
        }
        location ~ \.php$ {
                include snippets/fastcgi-php.conf;
                fastcgi_pass unix:/run/php/php8.1-fpm.sock;
        }
        location ~ /\.ht {
               deny all;
        }
}
EOF

# start.sh hinzufügen
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Containerstart
CMD ["/start.sh"]
