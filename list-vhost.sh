#!/bin/bash

# Farben definieren
RED="\e[31m"
GREEN="\e[32m"
RESET="\e[0m"

# Alle Container-Namen (auch gestoppte Container)
containers=$(docker ps -a --format '{{.Names}}')

# Durchlaufe alle Container
for name in $containers; do
    conf_file="/etc/nginx/sites-available/$name.conf"
    cert_dir="/etc/letsencrypt/live/$name.zarat.at"

    if [[ -f "$conf_file" ]]; then
        echo -e "${GREEN}[$name] vHost configuration found${RESET}"
    else
        echo -e "${RED}[$name] vHost configuration NOT FOUND${RESET}"
    fi

    if [[ -d $cert_dir ]]; then
        echo -e "${GREEN}[$name] Certificate OK${RESET}"
    else
        echo -e "${RED}[$name] Certificate NOT FOUND${RESET}"
    fi

    echo ""
done
