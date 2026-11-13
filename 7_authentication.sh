#!/bin/bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
   echo "Please run as root (use sudo)."
   exit 1
fi

echo "1. Backing up existing PAM configs..."
BACKUP_DIR="/root/pam-backup-$(date +%F_%H-%M-%S)"
mkdir -p "$BACKUP_DIR"
cp -r /etc/pam.d /etc/security "$BACKUP_DIR/"

echo "2. Installing required PAM packages..."
apt-get update -qq
apt-get install -y -qq libpam-pwquality

echo "3. Configuring /etc/security/faillock.conf..."
cat << 'EOF' > /etc/security/faillock.conf
deny = 5
unlock_time = 900
even_deny_root
root_unlock_time = 900
silent
EOF

echo "4. Configuring /etc/security/pwquality.conf..."
cat << 'EOF' > /etc/security/pwquality.conf
minlen = 14
minclass = 3
ucredit = -1
lcredit = -1
dcredit = -1
ocredit = -1
difok = 4
maxrepeat = 3
maxsequence = 3
dictcheck = 1
EOF

echo "5. Creating pam-auth-update profiles..."

# Profile 1: Faillock (Account Lockout)
cat << 'EOF' > /usr/share/pam-configs/faillock
Name: Lockout on failed logins
Default: yes
Priority: 0
Auth-Type: Primary
Auth:
	[default=die]	pam_faillock.so authfail
Auth-Initial:
	required	pam_faillock.so preauth
Account-Type: Primary
Account:
	required	pam_faillock.so
EOF

# Profile 2: Password History (Remember last 5 passwords)
cat << 'EOF' > /usr/share/pam-configs/pwhistory
Name: Enforce password history
Default: yes
Priority: 1024
Conflicts: pwhistory
Password-Type: Primary
Password:
	requisite	pam_pwhistory.so remember=5 use_authtok enforce_for_root
EOF

echo "6. Applying PAM configuration..."
DEBIAN_FRONTEND=noninteractive pam-auth-update --enable faillock pwquality pwhistory

echo "Done! Backup saved to $BACKUP_DIR."
