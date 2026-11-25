#!/bin/bash
# Je configure Fail2ban pour limiter les tentatives répétées sur SSH.

set -o pipefail

error()
{
    printf '[ERROR] %s\n' "$1" >&2
    exit 1
}

if [ "$(id -u)" -ne 0 ]; then
    error 'Run this script with sudo to configure Fail2ban.'
fi

for command_name in awk apt-get cp dpkg-query fail2ban-client \
    grep install mktemp rm systemctl; do
    command -v "$command_name" >/dev/null 2>&1 || \
        error "Required command not found: $command_name"
done

config_directory=/etc/fail2ban
config_file=$config_directory/jail.local
backup_file=$config_file.backup
temporary_directory=$(mktemp -d) || \
    error 'Could not create a temporary directory.'
trap 'rm -rf -- "$temporary_directory"' EXIT
new_config=$temporary_directory/jail.local

printf '=== fail2ban Configuration ===\n\n'
printf 'Installing fail2ban...\n'
if dpkg-query -W -f='${db:Status-Status}' fail2ban 2>/dev/null | \
    grep -q '^installed$'; then
    printf '  fail2ban: Already installed\n'
else
    if ! DEBIAN_FRONTEND=noninteractive apt-get install -y fail2ban; then
        error 'Could not install fail2ban.'
    fi
    printf '  fail2ban: Installed\n'
fi

if [ ! -d "$config_directory" ]; then
    error "Fail2ban configuration directory not found: $config_directory"
fi

# Je garde une copie initiale et les autres jails déjà configurés.
if [ -e "$config_file" ] && [ ! -e "$backup_file" ]; then
    cp -a -- "$config_file" "$backup_file" || \
        error "Could not back up $config_file."
fi

if [ -e "$config_file" ]; then
    if ! awk '
        /^[[:space:]]*\[sshd\][[:space:]]*$/ { skip = 1; next }
        /^[[:space:]]*\[[^]]+\][[:space:]]*$/ { skip = 0 }
        !skip { print }
    ' "$config_file" > "$new_config"; then
        error "Could not prepare $config_file."
    fi
else
    : > "$new_config"
fi

cat >> "$new_config" <<'EOF'

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
findtime = 600
bantime = 3600
EOF

if ! install -o root -g root -m 0644 "$new_config" "$config_file"; then
    error "Could not write $config_file."
fi

printf '\nCreating %s...\n\n' "$config_file"
printf '[sshd] configuration:\n'
printf '  enabled = true\n'
printf '  port = ssh\n'
printf '  filter = sshd\n'
printf '  logpath = /var/log/auth.log\n'
printf '  maxretry = 5\n'
printf '  findtime = 600 (10 minutes)\n'
printf '  bantime = 3600 (1 hour)\n'

if ! fail2ban-client -t; then
    if [ -e "$backup_file" ]; then
        cp -a -- "$backup_file" "$config_file"
    else
        rm -f -- "$config_file"
    fi
    error 'Fail2ban configuration validation failed; previous config restored.'
fi

printf '\nStarting fail2ban...\n'
if ! systemctl enable --now fail2ban.service; then
    error 'Could not enable and start fail2ban.service.'
fi
if ! systemctl is-active --quiet fail2ban.service; then
    error 'fail2ban.service is not active.'
fi
printf '  fail2ban.service: Active\n'

status_file=$temporary_directory/status
if ! fail2ban-client status sshd > "$status_file"; then
    error 'Could not read the sshd jail status.'
fi
currently_banned=$(awk -F': *' \
    '/Currently banned:/ { print $2; exit }' "$status_file")
total_banned=$(awk -F': *' \
    '/Total banned:/ { print $2; exit }' "$status_file")
currently_banned=${currently_banned:-0}
total_banned=${total_banned:-0}

printf '\nCurrent status:\n'
printf '  Jail: sshd\n'
printf '  Currently banned: %s\n' "$currently_banned"
printf '  Total banned: %s\n' "$total_banned"
printf '\nfail2ban: ACTIVE\n'
printf 'IP addresses with 5+ failures in 10 min will be banned for 1 hour.\n'
