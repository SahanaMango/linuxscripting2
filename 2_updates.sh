#!/bin/bash

set -e

# backup the current sources.list very importante
BACKUP_FILE="/etc/apt/sources.list.bak.$(date +%F_%T)"
cp /etc/apt/sources.list "$BACKUP_FILE"
echo "Backed up existing sources.list to $BACKUP_FILE"

# overwrite /etc/apt/sources.list with official Debian Bookworm repositories

cat <<EOF > /etc/apt/sources.list
deb https://deb.debian.org/debian bookworm main
deb https://deb.debian.org/debian bookworm-updates main
deb https://security.debian.org/debian-security bookworm-security main
EOF
echo "Updated /etc/apt/sources.list with official repositories."

# check /etc/apt/sources.list.d/ for third-party files

THIRD_PARTY_FILES=$(ls -A /etc/apt/sources.list.d/)

if [ -n "$THIRD_PARTY_FILES" ]; then
    echo "------------------------------------------------------------"
    echo "WARNING: /etc/apt/sources.list.d/ is NOT empty!"
    echo "The following third-party source files were found:"
    echo "$THIRD_PARTY_FILES"
    echo "Review or remove these files to ensure only official sources are used."
    echo "------------------------------------------------------------"
else
    echo "Verified: /etc/apt/sources.list.d/ is empty of third-party sources."
fi

# update package lists to apply changes
echo "Refreshing APT package lists..."
apt-get update

DEBIAN_FRONTEND=noninteractive apt-get install -y unattended-upgrades

tee /etc/apt/apt.conf.d/20auto-upgrades > /dev/null << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

# Ensure both systemd timers are enabled and started
systemctl enable --now apt-daily.timer
systemctl enable --now apt-daily-upgrade.timer

# now FINALLY run updates!!
echo "getting upgrades now" 
apt-get update && apt-get upgrade && apt-get dist-upgrade
