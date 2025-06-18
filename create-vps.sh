#!/bin/bash

# ===== KONFIGURATION =====
PVE_HOST="192.168.0.100"         # IP oder Hostname deines Proxmox-Servers
PVE_USER="root@pam"             # API-Benutzer (z. B. root@pam oder apiuser@pve)
PVE_PASS="deinPasswort"        # Passwort oder API-Token
PVE_NODE="pve"                  # Name des Proxmox-Nodes (z. B. pve)

# VMID=150
HOSTNAME=$1
TEMPLATE="local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
MEMORY=512                     # MB
CORES=1
DISK_SIZE=1                    # GB
ROOT_PASS=$(openssl rand -base64 8)

EMAIL="$2"

# ===== LOGIN (Ticket holen) =====
echo "[*] Authentifiziere bei Proxmox API..."
AUTH_RESPONSE=$(curl -sk -d "username=$PVE_USER&password=$PVE_PASS" https://$PVE_HOST:8006/api2/json/access/ticket)

TICKET=$(echo "$AUTH_RESPONSE" | jq -r '.data.ticket')
CSRF=$(echo "$AUTH_RESPONSE" | jq -r '.data.CSRFPreventionToken')

if [[ -z "$TICKET" || -z "$CSRF" ]]; then
  echo "[!] Fehler: Authentifizierung fehlgeschlagen."
  exit 1
fi

echo "[*] Suche nach erster freier VMID auf Node $PVE_NODE..."
USED_VMIDS=$(curl -sk -b "PVEAuthCookie=$TICKET" https://$PVE_HOST:8006/api2/json/nodes/$PVE_NODE/lxc | jq '.data[].vmid')

USED_ARRAY=($(echo "$USED_VMIDS"))

VMID=150
while [[ " ${USED_ARRAY[@]} " =~ " $VMID " ]]; do
  ((VMID++))
done

echo "[+] Verwende VMID $VMID"

IPCONFIG_INTERFACE="name=eth0"
IPCONFIG_BRIDGE="bridge=vmbr0"
IPCONFIG="ip=192.168.0.$VMID/24,gw=192.168.0.1"


# ===== LXC erstellen =====
echo "[*] Erstelle LXC-Container $VMID auf Node $PVE_NODE..."

CREATE_RESPONSE=$(curl -sk -X POST https://$PVE_HOST:8006/api2/json/nodes/$PVE_NODE/lxc \
  -H "CSRFPreventionToken: $CSRF" \
  -b "PVEAuthCookie=$TICKET" \
  -d vmid=$VMID \
  -d hostname=$HOSTNAME \
  -d ostemplate=$TEMPLATE \
  -d memory=$MEMORY \
  -d cores=$CORES \
  -d rootfs="local-lvm:${DISK_SIZE}" \
  -d unprivileged=1)

echo "$CREATE_RESPONSE" | jq


# ===== Container starten =====
echo "[*] Starte Container $VMID..."
answer=$(curl -sk -X POST https://$PVE_HOST:8006/api2/json/nodes/$PVE_NODE/lxc/$VMID/status/start \
  -H "CSRFPreventionToken: $CSRF" \
  -b "PVEAuthCookie=$TICKET" | jq)

sleep 15

ssh root@$PVE_HOST "pct exec $VMID -- bash -c 'useradd -m $HOSTNAME -G sudo -s /bin/bash'"
ssh root@$PVE_HOST "pct exec $VMID -- bash -c 'echo $HOSTNAME:$ROOT_PASS | chpasswd'"
ssh root@$PVE_HOST "pct set $VMID -net0 $IPCONFIG_INTERFACE,$IPCONFIG_BRIDGE,$IPCONFIG"

useradd -m $HOSTNAME
echo "$HOSTNAME:$ROOT_PASS" | chpasswd

# generate key
sudo -u $HOSTNAME ssh-keygen -t rsa -b 4096 -f /home/$HOSTNAME/.ssh/id_rsa -N "" -q

# copy key to container
ssh-copy-id -i /home/$HOSTNAME/.ssh/id_rsa.pub -o StrictHostKeyChecking=no $HOSTNAME@192.168.0.120 > /dev/null 2>&1

# add to sshd_config
cat >> "/etc/ssh/sshd_config.d/$HOSTNAME.conf" <<EOF
Match User $HOSTNAME
    AllowTcpForwarding no
    PermitTunnel no
    PermitTTY yes
    X11Forwarding no
    ForceCommand /usr/bin/ssh -i /home/$HOSTNAME/.ssh/id_rsa -o StrictHostKeyChecking=no $HOSTNAME@192.168.0.$VMID
EOF
systemctl restart ssh

echo "[✓] Container $VMID wurde erstellt und gestartet."

user=$HOSTNAME
password=$ROOT_PASS
email=$EMAIL

TO="$email"
SUBJECT="Dein VPS ist bereit ($user.zarat.at)"
BODY=$(cat <<EOF
Hallo $user, dein VPS wurde eingerichtet.

SSH:
    Host: $user.zarat.at
    User: $user
    Password: $password

Hinweis: Da die SSH Verbindung über einen Jump-Host geleitet wird, musst du das Passwort beim Login 2mal eingeben.
EOF
)
echo -e "Subject: $SUBJECT\nFrom: manuel@zarat.at\nTo: $TO\n\n$BODY" | msmtp "$TO" > /dev/null 2>&1

TO="manuel.zarat@gmail.com"
SUBJECT="Ein neuer VPS ($user) wurde eingerichtet"
BODY=$(cat <<EOF
Ein kostenloser Webserver wurde eingerichtet.

Email: $email

SSH:
    Host: $user.zarat.at
    User: $user
    Password: $password
EOF
)

echo -e "Subject: $SUBJECT\nFrom: manuel@zarat.at\nTo: $TO\n\n$BODY" | msmtp "$TO" > /dev/null 2>&1
