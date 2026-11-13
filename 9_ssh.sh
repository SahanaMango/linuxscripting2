#!/bin/bash

SSH_MAIN_CONFIG="/etc/ssh/sshd_config"
SSH_CONFIG_DIR="/etc/ssh/sshd_config.d"
CIS_CONFIG="/etc/ssh/sshd_config.d/00-cis.conf"
BACKUP_DIR="/root/ssh_backups"

secure_ssh_now() {

    echo "ssh it's time~~ :D"
    echo "...to secure the ssh server configuration files for Debian 12 (CIS Section 5.1)"

    mkdir -p "$BACKUP_DIR" "$SSH_CONFIG_DIR"
    timestamp=$(date +%Y%m%d_%H%M%S)
    cp "$SSH_MAIN_CONFIG" "$BACKUP_DIR/sshd_config.backup.$timestamp"

    # STEP 1: Audit permissions and ownership on main config and .d/*.conf files
    shopt -s nullglob
    for config_file in "$SSH_MAIN_CONFIG" "$SSH_CONFIG_DIR"/*.conf; do
        echo "Auditing file: $config_file"

        perm=$(stat -c "%a" "$config_file")
        if [ "$perm" != "600" ]; then
            echo "Setting permissions of $config_file to 600 (was $perm)"
            chmod 600 "$config_file"
        else
            echo "Permissions of $config_file are already secure: $perm"
        fi

        owner=$(stat -c "%U" "$config_file")
        group=$(stat -c "%G" "$config_file")
        if [ "$owner" != "root" ] || [ "$group" != "root" ]; then
            echo "Setting ownership of $config_file to root:root"
            chown root:root "$config_file"
        else
            echo "Ownership of $config_file is already secure: $owner:$group"
        fi
    done

    # STEP 2: Debian 12 (OpenSSH 9.2) CIS Benchmark settings
    declare -A settings_to_apply=(
        ["PermitEmptyPasswords"]="no"
        ["PermitUserEnvironment"]="no"
        ["PermitRootLogin"]="no"
        ["UsePAM"]="yes"
        ["ClientAliveInterval"]="15"
        ["ClientAliveCountMax"]="3"
        ["AllowTcpForwarding"]="no"
        ["X11Forwarding"]="no"
        ["PermitTunnel"]="no"
        ["GSSAPIAuthentication"]="no"
        ["HostbasedAuthentication"]="no"
        ["IgnoreRhosts"]="yes"
        ["LoginGraceTime"]="60"
        ["LogLevel"]="VERBOSE"
        ["MaxAuthTries"]="4"
        ["MaxSessions"]="10"
        ["MaxStartups"]="10:30:60"
        ["Ciphers"]="aes256-ctr,aes192-ctr,aes128-ctr"
        ["KexAlgorithms"]="curve25519-sha256,curve25519-sha256@libssh.org"
        ["MACs"]="hmac-sha2-512,hmac-sha2-256"
        ["StrictModes"]="yes"
        ["PubkeyAuthentication"]="yes"
        ["KbdInteractiveAuthentication"]="no"
        ["DebianBanner"]="no"
        ["PasswordAuthentication"]="yes" #dont get locked out
    )

    # Comment out conflicting settings in main config and other .conf files
    for setting in "${!settings_to_apply[@]}"; do
        for file in "$SSH_MAIN_CONFIG" "$SSH_CONFIG_DIR"/*.conf; do
            [[ "$file" == "$CIS_CONFIG" ]] && continue
            if grep -qiE "^\s*${setting}\b" "$file"; then
                sed -i -E "s/^(\s*${setting}\b)/# \1/I" "$file"
                echo "Commented out existing $setting in $file"
            fi
        done
    done

    # Backup existing 00-cis.conf if present
    if [ -f "$CIS_CONFIG" ]; then
        cp "$CIS_CONFIG" "$BACKUP_DIR/00-cis.conf.backup.$timestamp"
        echo "[*] Backed up existing $CIS_CONFIG"
    fi

    # Write new 00-cis.conf
    echo "[*] Writing new CIS SSH config to $CIS_CONFIG ..."
    > "$CIS_CONFIG"
    for key in "${!settings_to_apply[@]}"; do
        echo "$key ${settings_to_apply[$key]}" >> "$CIS_CONFIG"
    done

    chmod 600 "$CIS_CONFIG"
    chown root:root "$CIS_CONFIG"

    # Validate syntax with sshd -t before restarting
    if sshd -t; then
        echo "[+] sshd -t passed! Restarting ssh service..."
        systemctl restart ssh
    else
        echo "[!] sshd -t failed! Restoring backup..."
        cp "$BACKUP_DIR/sshd_config.backup.$timestamp" "$SSH_MAIN_CONFIG"
        rm -f "$CIS_CONFIG"
        return 1
    fi
}

secure_ssh_now
