#!/bin/bash
set -euo pipefail

read -rp "Enter exempt admin username: " EXEMPT_USER
if ! id "$EXEMPT_USER" &>/dev/null; then
    echo "User '$EXEMPT_USER' does not exist."
    exit 1
fi

echo "MANGO: Backing up config files..."
BACKUP_DIR="/root/shadow-backup-$(date +%F_%H-%M-%S)"
mkdir -p "$BACKUP_DIR"
cp /etc/login.defs /etc/default/useradd /etc/shadow "$BACKUP_DIR/"

LOGIN_DEFS="/etc/login.defs"
USERADD_DEFAULT="/etc/default/useradd"

# Updates key-value pairs separated by whitespace (for /etc/login.defs)
set_login_def() {
    local key="$1" value="$2"
    if grep -qE "^[[:space:]]*#?[[:space:]]*${key}[[:space:]]+" "$LOGIN_DEFS"; then
        sed -i -E "s|^[[:space:]]*#?[[:space:]]*${key}[[:space:]]+.*|${key}\t${value}|" "$LOGIN_DEFS"
    else
        echo -e "${key}\t${value}" >> "$LOGIN_DEFS"
    fi
}

# Updates KEY=VALUE pairs (for /etc/default/useradd)
set_useradd_default() {
    local key="$1" value="$2"
    if grep -qE "^[[:space:]]*#?[[:space:]]*${key}=" "$USERADD_DEFAULT"; then
        sed -i -E "s|^[[:space:]]*#?[[:space:]]*${key}=.*|${key}=${value}|" "$USERADD_DEFAULT"
    else
        echo "${key}=${value}" >> "$USERADD_DEFAULT"
    fi
}

echo "1. Updating $LOGIN_DEFS..."
set_login_def "PASS_MAX_DAYS" "30"
set_login_def "PASS_MIN_DAYS" "7"
set_login_def "PASS_WARN_AGE" "7"
set_login_def "UMASK" "077"
set_login_def "ENCRYPT_METHOD" "SHA512"
set_login_def "FAILLOG_ENAB" "yes"
set_login_def "LOG_UNKFAIL_ENAB" "yes"
set_login_def "SYSLOG_SU_ENAB" "yes"
set_login_def "SYSLOG_SG_ENAB" "yes"

echo "2. Updating $USERADD_DEFAULT..."
set_useradd_default "INACTIVE" "30"

echo "3. Applying aging rules to existing human users (excluding $EXEMPT_USER)..."
# Loop through users with UID >= 1000 (standard human accounts), excluding 'nobody' (65534)
awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' /etc/passwd | while read -r user; do
    if [[ "$user" == "$EXEMPT_USER" ]]; then
        echo "Skipping exempt user: $user"
        continue
    fi
    chage --maxdays 30 --mindays 7 --warndays 7 --inactive 30 "$user"
    echo "Applied password aging to: $user"
done

echo "4. Ensuring $EXEMPT_USER has no password expiration..."
chage --maxdays -1 --mindays 0 --warndays 7 --inactive -1 "$EXEMPT_USER"

echo "MANGO: Finished password aging and shadow suite hardening."
