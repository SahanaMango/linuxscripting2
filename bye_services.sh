#!/bin/bash
# 1. Stop and mask systemd sockets/services first (if present)
SERVICES_TO_DISABLE=(
  "telnet.socket"
  "autofs"
  "cups"
  "apache2"
  "avahi-daemon"
  "isc-dhcp-server"
  "bind9"
  "named"
  "dnsmasq"
  "vsftpd"
  "slapd"
  "dovecot"
  "nfs-kernel-server"
  "nis"
  "rpcbind"
  "rsync"
  "tftpd-hpa"
  "smbd"
  "nmbd"
  "snmpd"
  "squid"
  "webmin"
  "xinetd"
  "postgresql"
  "freeciv-server"
)

echo "--- 1. Stopping and Disabling Services ---"
for svc in "${SERVICES_TO_DISABLE[@]}"; do
  if systemctl list-unit-files | grep -qw "^$svc"; then
    echo "Stopping and masking $svc..."
    systemctl stop "$svc" 2>/dev/null
    systemctl disable "$svc" 2>/dev/null
    systemctl mask "$svc" 2>/dev/null
  fi
done

# 2. Debian 12 Package Equivalents for your list
# Includes Debian mappings for RHEL/CentOS names (e.g., nfs-utils -> nfs-common, bind-utils -> dnsutils)
DEBIAN_PACKAGES=(
  # File & Print Services
  "autofs"
  "cups"
  "cups-daemon"
  "nfs-kernel-server"
  "nfs-common"
  "samba"
  "samba-common-bin"
  "vsftpd"
  "tftpd-hpa"
  "tftp"
  "rsync"

  # Web, Mail & Databases
  "apache2"
  "apache2-utils"
  "dovecot-core"
  "dovecot-imapd"
  "dovecot-pop3d"
  "squid"
  "postgresql"
  "postgresql-common"
  "webmin"

  # Networking, DNS, DHCP & Directory Services
  "avahi-daemon"
  "isc-dhcp-server"
  "bind9"
  "bind9-utils"
  "dnsutils"
  "dnsmasq"
  "ldap-utils"
  "slapd"
  "nis"
  "rpcbind"
  "snmp"
  "snmpd"
  "snmp-mibs-downloader"
  "xinetd"
  "telnetd"
  "inetutils-telnetd"

  # Security / Cracking / Scanning Tools
  "wireshark"
  "wireshark-common"
  "tshark"
  "nmap"
  "zenmap"
  "aircrack-ng"
  "hydra"
  "nikto"
  "ophcrack"
  "john"
  "john-data"
  "hashcat"
  "kismet"

  # Games & Launchers
  "steam"
  "steam-installer"
  "lutris"
  "wine"
  "wine64"
  "playonlinux"
  "retroarch"
  "aisleriot"
  "gnome-games"
  "gnome-mahjongg"
  "gnome-mines"
  "gnome-sudoku"
  "quadrapassel"
  "swell-foop"
  "tali"
  "iagno"
  "lightsoff"
  "four-in-a-row"
  "five-or-more"
  "hitori"
  "klotski"
  "nibbles"
  "robots"
  "tetravex"
  "freeciv-server"
  "freeciv-data"

  # Torrents, P2P & Unauthorized Chat/Media Apps
  "transmission-gtk"
  "transmission-common"
  "qbittorrent"
  "deluge"
  "vuze"
  "discord"
  "telegram-desktop"
  "hexchat"
  "pidgin"
  "rhythmbox"
  "cheese"
)

echo "--- 2. Purging Packages ---"
for pkg in "${DEBIAN_PACKAGES[@]}"; do
  if dpkg -l "$pkg" 2>/dev/null | grep -qw "^ii"; then
    echo "Purging package: $pkg..."
    DEBIAN_FRONTEND=noninteractive apt-get purge -y "$pkg"
  fi
done

echo "--- 3. Cleaning Up Unused Dependencies ---"
apt-get autoremove --purge -y
apt-get autoclean -y

echo "Hardening and service removal complete."
