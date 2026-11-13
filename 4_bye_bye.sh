#!/bin/bash

PROHIBITED_FILE_TYPES=("*.exe" "*.torrent" "*.appimage" "*.bat" "*.msi" "*.mp3" "*.mp4" "*.mkv" "*.avi" "*.mov" "*.wmv" "*.webm" "*.flv" "*.m4v" "*.mpg" "*.mpeg" "*.3gp" "*.vob" "*.ts" "*.ogv" "*.aac" "*.ogg" "*.wma" "*.m4a" "*.opus" • "*.wav" "*.flac" "*.alac" "*.aiff")
SEARCH_DIRS=("/home" "/opt" "/var" "/tmp")
LOG_FILE="/var/log/application_policy.log"

SERVICES=(
  telnet.socket autofs cups apache2 avahi-daemon isc-dhcp-server
  bind9 named dnsmasq vsftpd slapd dovecot nfs-kernel-server
  nis rpcbind rsync tftpd-hpa smbd nmbd snmpd squid
  webmin xinetd postgresql freeciv-server
)

PACKAGES=(
  # Services & Daemons
  autofs cups cups-daemon nfs-kernel-server nfs-common samba samba-common-bin
  vsftpd tftpd-hpa tftp rsync apache2 apache2-utils dovecot-core dovecot-imapd
  dovecot-pop3d squid postgresql postgresql-common webmin avahi-daemon
  isc-dhcp-server bind9 bind9-utils dnsutils dnsmasq ldap-utils slapd nis
  rpcbind snmp snmpd snmp-mibs-downloader xinetd telnetd inetutils-telnetd

  # Security, Scanning & Cracking Tools
  wireshark wireshark-qt wireshark-gtk wireshark-common wireshark-doc tshark
  libwireshark-data nmap zenmap aircrack-ng hydra nikto ophcrack john john-data
  hashcat kismet

  # Games & Launchers
  steam steam-installer lutris wine wine64 playonlinux retroarch aisleriot
  gnome-games gnome-mahjongg gnome-mines gnome-sudoku quadrapassel swell-foop
  tali iagno lightsoff four-in-a-row five-or-more hitori klotski nibbles
  robots tetravex freeciv-server freeciv-data

  # P2P, Chat & Media
  transmission-gtk transmission-common qbittorrent deluge vuze discord
  telegram-desktop hexchat pidgin rhythmbox cheese
)

# ==============================================================================
# 2. HELPER FUNCTIONS
# ==============================================================================
ask() {
  read -rp "$1 (y/N): " ans
  [[ "$ans" =~ ^[Yy]$ ]]
}

scrub_wireshark() {
  echo " -> Deep-scrubbing Wireshark system and user traces..."
  groupdel wireshark 2>/dev/null
  rm -rf /etc/wireshark /usr/share/wireshark /usr/lib/*/wireshark
  
  awk -F: '$3 >= 1000 && $1 != "nobody" {print $6}' /etc/passwd | while read -r home; do
    rm -rf "$home/.config/wireshark" "$home/.wireshark"
  done
}

# ==============================================================================
# 3. EXECUTION
# ==============================================================================
echo "--- Checking Services ---"
for svc in "${SERVICES[@]}"; do
  if systemctl list-unit-files "$svc" &>/dev/null; then
    if ask "[SERVICE] Stop, disable, and mask '$svc'?"; then
      systemctl disable --now --quiet "$svc"
      systemctl mask --quiet "$svc"
      echo " -> Masked $svc."
    fi
  fi
done

echo -e "\n--- Checking Packages ---"
TO_PURGE=()
for pkg in "${PACKAGES[@]}"; do
  # dpkg-query is faster and cleaner than parsing 'dpkg -l' with grep
  status=$(dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null)
  if [[ "$status" == *"installed"* || "$status" == *"config-files"* ]]; then
    if ask "[PACKAGE] Purge '$pkg' and its configs?"; then
      TO_PURGE+=("$pkg")
    fi
  fi
done

if (( ${#TO_PURGE[@]} > 0 )); then
  echo -e "\n--- Purging Approved Packages ---"
  DEBIAN_FRONTEND=noninteractive apt-get purge -y "${TO_PURGE[@]}"
  
  # Trigger deep scrub only if a wireshark package was in the approved list
  [[ " ${TO_PURGE[*]} " =~ (wireshark|tshark) ]] && scrub_wireshark
fi

echo -e "\n--- Final Cleanup ---"
if ask "Run autoremove and purge all leftover residual configs?"; then
  apt-get autoremove --purge -y
  apt-get autoclean -y
  dpkg -l | awk '/^rc/ {print $2}' | xargs -r dpkg --purge
fi

echo -e "\nDone."


touch "$LOG_FILE"

echo "--- Checking Files ---"

for ext in "${PROHIBITED_FILE_TYPES[@]}"; do
    for dir in "${SEARCH_DIRS[@]}"; do
        # Use find and store results in an array first to avoid subshell issues
        mapfile -t files < <(find "$dir" -type f -iname "$ext" 2>/dev/null)
        for file in "${files[@]}"; do
            echo "Found file: $file"
            while true; do
                read -p "Delete this file? (y/n): " answer
                answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]' | xargs)
                if [[ "$answer" == "y" ]]; then
                    chmod u+w "$file" 2>/dev/null
                    rm -f "$file" && echo "Deleted file: $file" | tee -a "$LOG_FILE"
                    break
                elif [[ "$answer" == "n" ]]; then
                    echo "Skipped file: $file" | tee -a "$LOG_FILE"
                    break
                else
                    echo "Please enter y or n."
                fi
            done
        done
    done
done

echo "Scan complete." | tee -a "$LOG_FILE"
