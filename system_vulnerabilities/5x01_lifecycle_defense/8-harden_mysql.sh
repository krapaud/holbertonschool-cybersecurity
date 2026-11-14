#!/bin/bash

# Je limite MySQL au localhost et protège le nouveau secret root.

set -o pipefail
umask 077

if [ "$(id -u)" -ne 0 ]; then
    printf '[ERROR] Exécute ce script avec sudo.\n' >&2
    exit 1
fi
for command_name in mysql mysqld systemctl openssl; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf '[ERROR] Commande requise absente: %s\n' "$command_name" >&2
        exit 1
    fi
done

config_file=/etc/mysql/mysql.conf.d/mysqld.cnf
secret_file=/root/.mysql_secret
backup_directory=/var/backups/lifecycle-defense
temporary_directory=$(mktemp -d /root/mysql-hardening.XXXXXX) || {
    printf '[ERROR] Impossible de créer un dossier temporaire sécurisé.\n' >&2
    exit 1
}
cleanup()
{
    rm -rf -- "$temporary_directory"
}
trap cleanup EXIT
mkdir -p "$backup_directory" || {
    printf '[ERROR] Impossible de créer %s.\n' "$backup_directory" >&2
    exit 1
}
if ! mysql --protocol=socket -NBe 'SELECT 1' >/dev/null 2>&1; then
    printf '[ERROR] Accès MySQL local via sudo/socket indisponible.\n' >&2
    exit 1
fi

timestamp=$(date -u '+%Y%m%dT%H%M%SZ')
backup_file="$config_file.backup.$timestamp"
if [ ! -f "$config_file" ] || ! cp -a -- "$config_file" "$backup_file"; then
    printf '[ERROR] Sauvegarde de la configuration MySQL impossible.\n' >&2
    exit 1
fi
printf 'Backup created: %s\n' "$backup_file"

password=$(openssl rand -hex 32) || {
    printf '[ERROR] Génération du secret MySQL échouée.\n' >&2
    exit 1
}
secret_temporary="$temporary_directory/mysql_secret"
printf '%s\n' "$password" > "$secret_temporary"
chmod 600 "$secret_temporary"
awk '
    function add_missing_settings() {
        if (!bind_seen) print "bind-address = 127.0.0.1"
        if (!local_seen) print "local-infile = 0"
    }
    /^\[mysqld\][[:space:]]*$/ {
        if (in_mysqld) add_missing_settings()
        in_mysqld = 1
        found_mysqld = 1
        bind_seen = 0
        local_seen = 0
        print
        next
    }
    /^\[/ {
        if (in_mysqld) add_missing_settings()
        in_mysqld = 0
    }
    in_mysqld && /^[[:space:]]*bind-address[[:space:]]*=/ {
        print "bind-address = 127.0.0.1"
        bind_seen = 1
        next
    }
    in_mysqld && /^[[:space:]]*local-infile[[:space:]]*=/ {
        print "local-infile = 0"
        local_seen = 1
        next
    }
    { print }
    END {
        if (in_mysqld) add_missing_settings()
        if (!found_mysqld) exit 1
    }
' "$config_file" > "$temporary_directory/mysqld.cnf" || {
    cp -a -- "$backup_file" "$config_file"
    printf '[ERROR] Section [mysqld] absente, configuration restaurée.\n' >&2
    exit 1
}
cat "$temporary_directory/mysqld.cnf" > "$config_file"

if ! mysqld --validate-config >/dev/null 2>&1; then
    cp -a -- "$backup_file" "$config_file"
    printf '[ERROR] Configuration MySQL invalide, copie restaurée.\n' >&2
    exit 1
fi
if ! systemctl restart mysql; then
    cp -a -- "$backup_file" "$config_file"
    systemctl restart mysql || true
    printf '[ERROR] Redémarrage MySQL échoué, configuration restaurée.\n' >&2
    exit 1
fi

previous_secret_backup=''
if [ -e "$secret_file" ]; then
    previous_secret_backup="$backup_directory/mysql-secret-$timestamp"
    if ! cp -a -- "$secret_file" "$previous_secret_backup"; then
        cp -a -- "$backup_file" "$config_file"
        systemctl restart mysql || true
        printf '[ERROR] Sauvegarde du secret MySQL existant impossible.\n' >&2
        exit 1
    fi
fi
if ! cp -- "$secret_temporary" "$secret_file"; then
    cp -a -- "$backup_file" "$config_file"
    systemctl restart mysql || true
    if [ -n "$previous_secret_backup" ]; then
        cp -a -- "$previous_secret_backup" "$secret_file"
    else
        rm -f -- "$secret_file"
    fi
    printf '[ERROR] Impossible de préparer le fichier secret root.\n' >&2
    exit 1
fi
if ! chmod 600 "$secret_file"; then
    cp -a -- "$backup_file" "$config_file"
    systemctl restart mysql || true
    if [ -n "$previous_secret_backup" ]; then
        cp -a -- "$previous_secret_backup" "$secret_file"
    else
        rm -f -- "$secret_file"
    fi
    printf '[ERROR] Permissions du secret root impossibles à sécuriser.\n' >&2
    exit 1
fi

sql_file="$temporary_directory/hardening.sql"
anonymous_accounts=$(mysql --protocol=socket -NBe \
    "SELECT CONCAT('DROP USER IF EXISTS ', QUOTE(User), '@', QUOTE(Host), ';') FROM mysql.user WHERE User = ''" \
    2>/dev/null)
remote_root_accounts=$(mysql --protocol=socket -NBe \
    "SELECT CONCAT('DROP USER IF EXISTS ', QUOTE(User), '@', QUOTE(Host), ';') FROM mysql.user WHERE User = 'root' AND Host <> 'localhost'" \
    2>/dev/null)
cat > "$sql_file" <<SQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '$password';
$anonymous_accounts
$remote_root_accounts
DROP DATABASE IF EXISTS test;
FLUSH PRIVILEGES;
SQL
chmod 600 "$sql_file"
if ! mysql --protocol=socket < "$sql_file"; then
    cp -a -- "$backup_file" "$config_file"
    systemctl restart mysql || true
    if [ -n "$previous_secret_backup" ]; then
        cp -a -- "$previous_secret_backup" "$secret_file"
    else
        rm -f -- "$secret_file"
    fi
    printf '[ERROR] Application SQL échouée. La configuration a été restaurée.\n' >&2
    exit 1
fi

client_file="$temporary_directory/client.cnf"
cat > "$client_file" <<EOF
[client]
user=root
password=$password
protocol=socket
EOF
chmod 600 "$client_file"
unset password
if ! mysql --defaults-extra-file="$client_file" -NBe \
    "SELECT @@global.bind_address = '127.0.0.1', @@global.local_infile = 0" \
    | awk '$1 == 1 && $2 == 1 { ok = 1 } END { exit !ok }'; then
    cp -a -- "$backup_file" "$config_file"
    systemctl restart mysql || true
    if [ -n "$previous_secret_backup" ]; then
        cp -a -- "$previous_secret_backup" "$secret_file"
    else
        rm -f -- "$secret_file"
    fi
    printf '[ERROR] Vérification finale MySQL échouée.\n' >&2
    exit 1
fi
printf 'Root password: Set and stored in %s (mode 0600)\n' "$secret_file"
printf 'Anonymous users: Removed\nRemote root login: Disabled\nTest database: Removed\n'
printf 'Bind address: 127.0.0.1\nMySQL hardened successfully.\n'
