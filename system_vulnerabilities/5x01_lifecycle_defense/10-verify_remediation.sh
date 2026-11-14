#!/bin/bash

# Je contrôle les remédiations du rapport initial sans modifier le système.

set -o pipefail

if [ "$(id -u)" -ne 0 ]; then
    printf '[ERROR] Exécute ce script avec sudo pour inspecter tous les éléments.\n' >&2
    exit 1
fi
for command_name in dpkg-query sshd ss stat; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf '[ERROR] Commande requise absente: %s\n' "$command_name" >&2
        exit 1
    fi
done

failures=0
report_status()
{
    local severity="$1"
    local finding="$2"
    local result="$3"
    local detail="$4"
    printf '[%s] %s Status: %s (%s)\n\n' \
        "$severity" "$finding" "$result" "$detail"
    [ "$result" = REMEDIATED ] || failures=$((failures + 1))
}

printf '=== Remediation Verification ===\n'
printf 'Checking vulnerabilities from assessment report...\n\n'
if dpkg-query -W -f='${db:Status-Status}' vsftpd 2>/dev/null | grep -q installed; then
    report_status CRITICAL 'CVE-2011-2523 vsftpd backdoor' PRESENT 'vsftpd package installed'
else
    report_status CRITICAL 'CVE-2011-2523 vsftpd backdoor' REMEDIATED 'service removed'
fi

apache_version=$(dpkg-query -W -f='${Version}' apache2 2>/dev/null || true)
if [ -n "$apache_version" ] && dpkg --compare-versions "$apache_version" ge \
    '2.4.41-4ubuntu3.14'; then
    report_status HIGH 'Apache outdated (CVE-2021-*)' REMEDIATED \
        "version $apache_version"
else
    report_status HIGH 'Apache outdated (CVE-2021-*)' PRESENT \
        "version ${apache_version:-not installed}"
fi

effective_ssh=$(sshd -T 2>/dev/null || true)
for setting in permitrootlogin passwordauthentication; do
    value=$(printf '%s\n' "$effective_ssh" | awk -v key="$setting" \
        '$1 == key { print $2; exit }')
    if [ "$value" = no ]; then
        report_status HIGH "SSH $setting enabled" REMEDIATED "set to no"
    else
        report_status HIGH "SSH $setting enabled" PRESENT "effective value ${value:-unknown}"
    fi
done

secret_file=/root/.mysql_secret
client_file=''
if [ -s "$secret_file" ] && [ "$(stat -c '%a' "$secret_file")" = 600 ]; then
    password=$(cat "$secret_file")
    client_file=$(mktemp /root/mysql-verify.XXXXXX) || exit 1
    chmod 600 "$client_file"
    printf '[client]\nuser=root\npassword=%s\nprotocol=socket\n' \
        "$password" > "$client_file"
    unset password
    if mysql --defaults-extra-file="$client_file" -NBe 'SELECT 1' \
        >/dev/null 2>&1; then
        report_status HIGH 'MySQL root no password' REMEDIATED 'password set'
    else
        report_status HIGH 'MySQL root no password' PRESENT 'local authentication failed'
    fi
else
    report_status HIGH 'MySQL root no password' PRESENT 'protected secret file missing'
fi

mysql_bind=''
if [ -n "$client_file" ]; then
    mysql_bind=$(mysql --defaults-extra-file="$client_file" -NBe \
        'SELECT @@global.bind_address' 2>/dev/null || true)
    rm -f -- "$client_file"
fi
if [ "$mysql_bind" = 127.0.0.1 ] || [ "$mysql_bind" = localhost ]; then
    report_status HIGH 'MySQL exposed to network' REMEDIATED 'localhost only'
else
    report_status HIGH 'MySQL exposed to network' PRESENT \
        "bind address ${mysql_bind:-unknown}"
fi

if [ -e /usr/local/bin/backup ] &&
    ! find /usr/local/bin/backup -maxdepth 0 -perm -4000 -print -quit | grep -q .; then
    report_status MEDIUM 'SUID binary /usr/local/bin/backup' REMEDIATED 'SUID removed'
else
    report_status MEDIUM 'SUID binary /usr/local/bin/backup' PRESENT 'still SUID or missing'
fi
if [ -f /etc/cron.daily/backup.sh ] &&
    ! find /etc/cron.daily/backup.sh -maxdepth 0 -perm -0002 -print -quit | grep -q .; then
    report_status MEDIUM 'World-writable cron script' REMEDIATED 'permissions fixed'
else
    report_status MEDIUM 'World-writable cron script' PRESENT 'still writable or missing'
fi
if [ -L /var/www/html/.env ] &&
    [ "$(readlink /var/www/html/.env)" = /etc/novatech/app.env ] &&
    [ -f /etc/novatech/app.env ]; then
    report_status MEDIUM 'Exposed credentials in webroot' REMEDIATED 'moved to /etc'
else
    report_status MEDIUM 'Exposed credentials in webroot' PRESENT 'not moved to protected path'
fi

printf 'Remediation checks failed: %s\n' "$failures"
[ "$failures" -eq 0 ]
