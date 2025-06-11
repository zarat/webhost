FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

# Installiere Apache, PHP, MariaDB
RUN apt update && apt install -y apache2 php libapache2-mod-php mariadb-server php-mysql && \
    apt clean

# Setze MariaDB root Passwort & sichere Installation
COPY init.sql /init.sql
RUN service mysql start && \
    mysql < /init.sql

# Aktiviere Apache bei Start
EXPOSE 80
CMD service mysql start && apachectl -D FOREGROUND
