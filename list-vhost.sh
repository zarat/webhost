#!/bin/bash

# Farben definieren
RED="\e[31m"
GREEN="\e[32m"
RESET="\e[0m"

# Alle Container-Namen (auch gestoppte Container, falls gewünscht)
containers=$(docker ps -a --format '{{.Names}}')

# Durchlaufe alle Container
for name in $containers; do
    conf_file="/etc/nginx/sites-available/$name.conf"
    if [[ -f "$conf_file" ]]; then
        echo -e "${GREEN}[$name] $conf_file${RESET}"
    else
        echo -e "${RED}[$name] Keine Konfigurationsdatei gefunden${RESET}"
    fi
done
