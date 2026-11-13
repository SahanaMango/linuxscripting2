#!/bin/bash

set -e

sudo passwd -l root
echo "locked root account"

sudo tee -a /etc/lightdm/lightdm.conf > /dev/null << 'EOF'
[Seat:*]
allow-guest=false
greeter-hide-users=true
greeter-show-manual-login=true
autologin-user=none
EOF

echo "disabled guest account"
