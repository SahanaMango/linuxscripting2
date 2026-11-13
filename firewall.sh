#!/bin/bash
# this wall is on fire!! (configuration script for ufw firewall)
# href https://www.digitalocean.com/community/tutorials/ufw-essentials-common-firewall-rules-and-commands#how-to-allow-incoming-connections-to-a-network-interface

echo "this wall is on fire!! (configuring ufw firewall)..."

#HOW TO DO MANUALLY:
# Step 1: Ensure ufw is installed -->                                   sudo apt-get install -y ufw
# Step 2: Avoid conflicts by removing iptables-persistent -->           dpkg -s iptables-persistent; sudo apt purge -y iptables-persistent; sudo apt-get autoremove -y
# Step 3: Allow SSH before enabling the firewall to prevent lockout --> sudo ufw allow OpenSSH
# Step 4: Unmask UFW in case it's masked --> s                          sudo systemctl unmask ufw.service
# Step 5: Enable UFW service to start now and on boot -->               sudo systemctl --now enable ufw.service
# Step 6: Set default policies --> sudo ufw default deny incoming;      sudo ufw default allow outgoing
# Step 7: Configure loopback traffic -->                               sudo ufw allow in on lo; sudo ufw allow out on lo
# Step 8: Allow specific application profiles --> sudo ufw allow OpenSSH; sudo ufw allow Apache; sudo ufw allow [more services as needed, find their name in 'ufw app list']
# Step 9: Set logging level (CIS recommendation) --> sudo ufw logging low
# Step 10: Enable the firewall with current rules --> sudo ufw --force enable
# Step 11: Output Final Status to check everything --> sudo ufw status verbose

# 1. Ensure ufw installation
echo "Checking if ufw is installed..."
#Explanation: ufw is a user-friendly frontend for managing firewall rules using iptables. having it facilitates configuration and maintenance of firewall settings.
if ! command -v ufw &> /dev/null; then #note: v parameter checks if command exists, /dev/null suppresses output to only show exit status
    echo "ufw not found, installing..."
    apt-get update #already updated in previous scripts, but just in case (can be commented out if desired)
    apt-get install -y ufw
    if command -v ufw &> /dev/null; then
        echo "ufw installed successfully!!"
    else
        echo "FAILED TO INSTALL UFW. Try checking network and package sources of ufw... we installed it using apt-get install -y ufw."
        echo "...also this probably indicates a continuing issue from the 1.2 package management scripts because ufw is in default repos."
        exit 1  #exit with error (the entire script will )
    fi
else
    echo "ufw is already installed."
fi

# 2. Avoid conflicts by removing iptables-persistent
echo "Checking for conflicting iptables-persistent installation..." 
#why remove iptables-persistent? --> it can conflict with ufw managing firewall rules as ufw uses its own set of iptables rules.
if dpkg-query -s iptables-persistent &> /dev/null; then #package is installed
    echo "iptables-persistent is installed, removing it..."
    apt-get purge -y iptables-persistent #remove package
    apt-get autoremove -y #remove dependencies no longer needed
    echo "iptables-persistent removed!!"
else
    echo "iptables-persistent is not installed. no action needed :)"
fi

# 3. Enable and configure UFW
echo "Enabling UFW service..."
# 3a) Allow SSH before enabling the firewall to prevent our current connection from being blocked
    echo "Allowing SSH on port 22 to prevent lockout..."
    ufw allow proto tcp from any to any port 22 #allow protocol tcp to and from any on port 22 (*typically but NOT Always used for ssh, so refer to line 42 instead...). what is tcp --> Transmission Control Protocol, a core protocol of the Internet Protocol Suite. it ensures reliable, ordered, and error-checked delivery of data between applications running on hosts communicating via an IP network.
    ufw allow OpenSSH #alternative way to allow ssh using ufw app profile, better than hardcoding port 22 because it accounts for custom ssh ports if configured.
# 3b) Unmask UFW in case it's masked
    #what is masking? --> masking a service prevents it from being started manually or automatically, effectively disabling it regardless of other settings.
    echo "Unmasking ufw service..."
    systemctl unmask ufw.service

# 3c) Enable UFW service to start now and on boot
    echo "Enabling ufw service to start now and on boot..."
    systemctl --now enable ufw.service #--now flag starts the service immediately in addition to enabling it on boot.
# 3d) Set default policies
    #hmm, do these policies have to be set before enabling ufw? --> i think so bc setting default policies before enabling ufw ensures that the firewall starts with the desired security posture, preventing unintended access.
    echo "Setting default firewall policies..."
    ufw default deny incoming
    ufw default allow outgoing
# 3e) Configure loopback traffic
    #what is loopback traffic? --> Loopback traffic refers to network communication that a computer sends to itself, typically using the loopback interface (lo) with the IP address
    #rationale for allowing it: --> allowing loopback traffic is essential for the proper functioning of many applications and services that rely on inter-process communication within the same host.
    #it could get points because blocking loopback traffic can disrupt local services and applications.
    echo "Allowing loopback traffic..."
    ufw allow in on lo
    ufw allow out on lo

# 3e.5 ) Allow loopback traffic for specific servic
    ufw allow out to any port 53 #dns
    ufw allow out to any port 80 #http
    ufw allow out to any port 443 #https

    ufw allow http
    ufw allow dns
    ufw allow 80/tcp
    ufw allow https

# 3f) Allow specific application profiles
    echo "Allowing known services..."
    declare -a allowed_services=("OpenSSH" "Apache" "MySQL" "vsftpd")
    for service in "${allowed_services[@]}"; do
        if ufw app list | grep -qw "$service"; then #check if service is a known ufw app profile
            echo "Allowing $service..." #allow the service through ufw (so that the service can still function properly with firewall enabled)
            ufw allow "$service" #...
        else
            echo "Warning: $service is not a known UFW app profile. Skipping."
        fi
    done

# 3g) Set logging level (CIS recommendation) --> ?
    #rationale: setting logging to low balances the need for security monitoring with system performance and log manageability.
    #CIS recommendation: CIS benchmarks often recommend setting firewall logging to a level that captures essential security events without overwhelming the system with excessive log data.
    #it could get points because logging is important for monitoring and auditing firewall activity, which is a key aspect of system security.
    #also, excessive logging can lead to performance issues and make it harder to identify important security events.
    #so setting it so something ensures important events are logged, but low specifically avoids excessive log generation (which unwanted people could find and exploit)
    echo "Setting ufw logging level to low..."
    ufw logging low

# 3h) Enable the firewall with current rules
    echo "Enabling ufw firewall..."
    #why wasn't it enabled in 3c? --> because enabling the firewall after setting all rules ensures that the firewall starts with the correct configuration, preventing any unintended access during the setup process.
    #then why did we need to enable it then? --> enabling the ufw service in 3c ensures that the ufw daemon is running and will start on boot, but the firewall itself is not active until explicitly enabled here.
    #what is the ufw daemon? --> the ufw daemon is the background service that manages the firewall rules and enforces them on the system. we need it running to apply the rules we set, and starting it on boot ensures the firewall is active after a reboot.
    ufw --force enable #--force flag bypasses confirmation prompt

# 4. Output Final Status --
    echo "ufw status after changes:"
    ufw status verbose #display current ufw status with detailed information

    #output format example:
    #Status: active
    #Logging: on (low)
    #Default: deny (incoming), allow (outgoing), disabled (routed)
    #New profiles: skipped
    #To                         Action      From
    #--                         ------      ----
    #22/tcp                     ALLOW IN    Anywhere
    #OpenSSH                    ALLOW IN    Anywhere
    #Apache                     ALLOW IN    Anywhere
    #MySQL                      ALLOW IN    Anywhere
    #vsftpd                     ALLOW IN    Anywhere
    #22/tcp (v6)                ALLOW IN    Anywhere (v6)
    #OpenSSH (v6)               ALLOW IN    Anywhere (v6)
    #Apache (v6)                ALLOW IN    Anywhere (v6)
    #MySQL (v6)                 ALLOW IN    Anywhere (v6) --> actually should not have this hehe
    #vsftpd (v6)                ALLOW IN    Anywhere (v6) --> also should not have this heheeheh

    #notes to understand output:
        # active status indicates it's enabled
        # next three r intuitive, disabled (routed) means no specific rules for routed traffic (traffic passing through the system to other networks)
        #new profiles: skipped --> indicates that any new application profiles added to ufw after the last reload have not been applied yet.
        #in the To/Action/From section, apps listed here should be the same as those allowed in 3f
        #the "Anywhere" indicates that the rules apply to all IP addresses (both IPv4 and IPv6 versions shown separately). (v6 indicates IPv6 which is the newer version of the internet protocol with a larger address space)
            #is it bad that from Anywhere is shown? --> **no, because the firewall rules are designed to allow only specific services (like SSH, Apache, MySQL, vsftpd) while denying all other incoming connections by default. "From Anywhere" indicates that these allowed services can accept connections from any IP address, which is typical for services meant to be accessible over a network.

    echo "UFW configuration complete. Firewall is now up and running!"
