#!/bin/bash
# Title: GATEKEEPER SCRIPT – CIS 7.2 Custom User Enforcement

echo "MANGO: Running 'GATEKEEPER SCRIPT' – Custom User Enforcement"

#note: this will enforce the user/group/administrator stuff which is more personalized to cypat and less to the cis benchmarks

#find all necessary files and variables
CURRENT_DIR=$(dirname "$0")
USERLIST_FILE="$CURRENT_DIR/userlist.txt"
if [ ! -f "$USERLIST_FILE" ]; then
    echo "Error: user list file '$USERLIST_FILE' not found."
    exit 1
fi
authorized_admins=()
authorized_users=()
exempt_user=""

#parse userlist.txt --> GUYS this is super cool!!
while IFS= read -r line; do
    if [[ "$line" =~ ^[[:space:]]*([a-zA-Z0-9]+)[[:space:]]*\(you\) ]]; then
        #auto detect exempt user based on (you) line in userlist.txt --> should be 1
        exempt_user="${BASH_REMATCH[1]}"
        authorized_admins+=("$exempt_user") #c'est tres important!!
    #if there's a username then add it to the right spot
    elif [[ "$line" =~ ^[[:space:]]*([a-zA-Z0-9]+)[[:space:]]*$ ]]; then
        user="${BASH_REMATCH[1]}"
        if [[ "$section" == "admins" ]]; then
            authorized_admins+=("$user")
        elif [[ "$section" == "users" ]]; then
            authorized_users+=("$user")
        fi
    #if the line redefines the right section then update it
    elif [[ "$line" =~ ^Authorized\ Administrators ]]; then
        section="admins"
    elif [[ "$line" =~ ^Authorized\ Users ]]; then
        section="users"
    fi
done < "$USERLIST_FILE"
#should now have a list of all authorized users and admins!...
#and one exempt user who willl be immediately categorized as an admin bc no risks
all_authorized=("${authorized_admins[@]}" "${authorized_users[@]}")
echo "Exempt user: $exempt_user"
echo "Authorized admins: ${authorized_admins[*]}"
echo "Authorized users: ${authorized_users[*]}"

echo "1. Checking for unauthorized users..."

#/etc/passwd format (for reference!!): [username] : [password_placeholder] : [uid] : [gid] : [gecos] : [home_directory] : [shell]
#(loop thru  usernames with uid >= 1000)
for user in $(awk -F: '$3 >= 1000 {print $1}' /etc/passwd); do
    is_authorized=false
    #compare user to all authorized users
    for auth_user in "${all_authorized[@]}"; do
        if [[ "$user" == "$auth_user" ]]; then
            is_authorized=true
            break
        fi
    done
    #if not authorized, PROMPT FIRST then remove
    if ! $is_authorized; then
        read -p "User '$user' is not authorized. Remove this user? (y/n): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            userdel -r "$user" && echo "Ok, removed user: $user"
        else
            echo "Ok, skipped user: $user"
        fi
    fi
done

echo "2. Checking for unauthorized sudo/admin access"
#although admin group will probably not be exist bc
#"In Ubuntu 12.04, administrator access will be granted via the sudo group"

for group in sudo admin; do
    #current members of group
    members=$(getent group "$group" | cut -d: -f4 | tr ',' ' ')
    for user in $members; do
        is_admin=false
        for auth_admin in "${authorized_admins[@]}"; do
            if [[ "$user" == "$auth_admin" ]]; then
                is_admin=true
                break
            fi
        done
        if ! $is_admin && [[ "$user" != "$exempt_user" ]]; then
            read -p "User '$user' is in '$group' but not authorized. Remove from group? (y/n): " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                deluser "$user" "$group" && echo "Ok, removed $user from $group"
            else
                echo "Ok, skipped $user in $group"
            fi
        fi
    done
done

# Step 3: Confirm before adding missing authorized users
echo "Step 3: Checking for missing authorized users"
for user in "${all_authorized[@]}"; do
    if ! id "$user" &>/dev/null; then
        read -p "User '$user' is authorized but missing. Add this user? (y/n): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            useradd -m "$user" && echo "Added user: $user"
            if [[ "$user" != "$exempt_user" ]]; then
                password=$(awk -v u="$user" '
                    $0 ~ u && $0 ~ "\\(you\\)" {next}
                    $0 ~ u {found=1; next}
                    found && /password:/ {gsub(/^[[:space:]]*password:[[:space:]]*/, "", $0); print; exit}
                ' "$USERLIST_FILE")
                if [ -n "$password" ]; then
                    echo "$user:$password" | chpasswd
                    echo "Set password for $user"
                fi
            fi
        else
            echo "Skipped adding user: $user"
        fi
    fi
done

# Step 4: Confirm before adding missing sudo/admin access
echo "Step 4: Checking for missing sudo/admin access among authorized admins"
for admin in "${authorized_admins[@]}"; do
    [ "$admin" = "$exempt_user" ] && continue
    if id "$admin" &>/dev/null; then
        in_sudo=$(id -nG "$admin" | grep -E '\bsudo\b')
        in_admin=$(id -nG "$admin" | grep -E '\badmin\b')
        if [ -z "$in_sudo" ] && [ -z "$in_admin" ]; then
            read -p "User '$admin' is authorized but not in sudo/admin. Add to sudo group? (y/n): " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                usermod -aG sudo "$admin" && echo "Added $admin to sudo group"
            else
                echo "Skipped adding $admin to sudo group"
            fi
        fi
    else
        echo "Warning: authorized admin '$admin' does not exist on system"
    fi
done

echo "changing insecure password of hulk hogan....and all other users....as observed in readme"

echo "hhogan:Fr13ndlyN31ghb0r!" | chpasswd
echo "tstark:Fr13ndlyN31ghb0r!" | chpasswd
echo "ppotts:Fr13ndlyN31ghb0r!" | chpasswd
echo "nfury:Fr13ndlyN31ghb0r!" | chpasswd
echo "mhill:Fr13ndlyN31ghb0r!" | chpasswd
echo "pcoulson:Fr13ndlyN31ghb0r!" | chpasswd

echo "user verification complete!!"
