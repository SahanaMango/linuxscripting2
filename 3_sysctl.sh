#!/bin/bash

echo "Configuring network kernel parameters..."


declare -A sysctl_settings=(
    #disable ip forwarding
    [net.ipv4.tcp_syncookies]=1
    [net.ipv4.ip_forward]=0
    [net.ipv6.conf.all.forwarding]=0
    #disable icmp redirects (used to optimize routing but not necessary from security standpoint)
    [net.ipv4.conf.all.send_redirects]=0
    [net.ipv4.conf.default.send_redirects]=0
    #[net.ipv4.route.flush]=1 

    [net.ipv4.icmp_ignore_bogus_error_responses]=1
    [net.ipv4.icmp_echo_ignore_broadcasts]=1

    [net.ipv4.conf.all.accept_redirects]=0
    [net.ipv4.conf.default.accept_redirects]=0
    [net.ipv6.conf.all.accept_redirects]=0
    [net.ipv6.conf.default.accept_redirects]=0

    [net.ipv4.conf.all.secure_redirects]=0
    [net.ipv4.conf.default.secure_redirects]=0
    [net.ipv4.conf.all.accept_source_route]=0
    [net.ipv4.conf.default.accept_source_route]=0

    [net.ipv4.conf.all.log_martians]=1
    [net.ipv4.conf.default.log_martians]=1

    [net.ipv6.conf.all.accept_source_route]=0
    [net.ipv6.conf.default.accept_source_route]=0
    [net.ipv4.conf.all.rp_filter]=1
    [net.ipv4.conf.default.rp_filter]=1

    [net.ipv4.tcp_syncookies]=2
    [kernel.randomize_va_space]=2

    [net.ipv6.conf.all.accept_ra]=0
    [net.ipv6.conf.default.accept_ra]=0
)

for key in "${!sysctl_settings[@]}"; do
    value="${sysctl_settings[$key]}"
    echo "Setting $key = $value"
    sysctl -w "$key=$value"
    grep -q "^$key" /etc/sysctl.conf && \
        sed -i "s|^$key.*|$key = $value|" /etc/sysctl.conf || \
        echo "$key = $value" >> /etc/sysctl.conf
done

#reload sysctl
sysctl -p

echo "Network kernel parameters configured."
