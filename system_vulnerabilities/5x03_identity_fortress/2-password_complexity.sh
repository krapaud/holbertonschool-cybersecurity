#!/bin/bash
# Je configure la qualité des mots de passe et je vérifie les règles.

set -o pipefail

error()
{
    printf '[ERROR] %s\n' "$1" >&2
    exit 1
}

if [ "$(id -u)" -ne 0 ]; then
    error 'Lance ce script avec sudo pour modifier PAM.'
fi

for command_name in awk apt-get cp dirname dpkg dpkg-query grep install \
    mktemp rm stat; do
    command -v "$command_name" >/dev/null 2>&1 || \
        error "Commande requise introuvable: $command_name"
done

config_file=/etc/security/pwquality.conf
pam_file=/etc/pam.d/common-password

if [ ! -r "$pam_file" ] || [ ! -w "$(dirname "$pam_file")" ]; then
    error "Fichier PAM absent ou dossier non modifiable: $pam_file"
fi
if ! grep -Eq '^[[:space:]]*password[[:space:]]+.*pam_unix[.]so' \
    "$pam_file"; then
    error 'La ligne active pam_unix.so est introuvable dans common-password.'
fi

printf '=== Password Complexity Configuration ===\n\n'
printf 'Checking interrupted package configuration...\n'
if ! dpkg --configure -a; then
    error 'La configuration des paquets interrompus a échoué.'
fi

printf 'Checking package dependencies...\n'
if ! apt-get check; then
    printf 'Repairing broken dependencies...\n'
    if ! DEBIAN_FRONTEND=noninteractive apt-get install -f -y; then
        error 'La réparation des dépendances cassées a échoué.'
    fi
    if ! apt-get check; then
        error 'Des dépendances restent cassées après la réparation.'
    fi
fi

printf 'Installing libpam-pwquality...\n'
packages_to_install=()
if dpkg-query -W -f='${db:Status-Status}' libpam-pwquality \
    2>/dev/null | grep -q '^installed$'; then
    printf '  Already installed: libpam-pwquality\n'
else
    packages_to_install+=(libpam-pwquality)
fi
if ! command -v pwscore >/dev/null 2>&1; then
    packages_to_install+=(libpwquality-tools)
fi
if [ "${#packages_to_install[@]}" -gt 0 ]; then
    if ! DEBIAN_FRONTEND=noninteractive apt-get install -y \
        "${packages_to_install[@]}"; then
        error 'Installation des outils de vérification pwquality impossible.'
    fi
fi
if ! command -v pwscore >/dev/null 2>&1; then
    error 'pwscore reste introuvable après installation.'
fi

# Je garde une copie initiale pour pouvoir revenir en arrière.
printf '\nBacking up configuration...\n'
if [ -e "$config_file" ]; then
    if [ ! -e "$config_file.backup" ] && \
        ! cp -a -- "$config_file" "$config_file.backup"; then
        error "Sauvegarde impossible: $config_file.backup"
    fi
elif [ ! -e "$config_file.backup" ]; then
    if ! install -o root -g root -m 0600 /dev/null \
        "$config_file.backup"; then
        error "Création de la sauvegarde impossible: $config_file.backup"
    fi
fi
if [ ! -e "$pam_file.backup" ] && \
    ! cp -a -- "$pam_file" "$pam_file.backup"; then
    error "Sauvegarde impossible: $pam_file.backup"
fi
printf '  %s.backup created\n' "$config_file"

temporary_directory=$(mktemp -d) || \
    error 'Impossible de créer un dossier temporaire.'
trap 'rm -rf -- "$temporary_directory"' EXIT
new_quality=$temporary_directory/pwquality.conf
new_pam=$temporary_directory/common-password

# Je garde les autres réglages et commentaires du fichier existant.
if [ -e "$config_file" ]; then
    if ! awk '
        BEGIN {
            managed["minlen"] = 1
            managed["dcredit"] = 1
            managed["ucredit"] = 1
            managed["lcredit"] = 1
            managed["ocredit"] = 1
            managed["usercheck"] = 1
            managed["difok"] = 1
        }
        {
            key = $1
            sub(/=.*/, "", key)
            if (key in managed) next
        }
        { print }
    ' "$config_file" > "$new_quality"; then
        error 'Lecture de pwquality.conf impossible.'
    fi
else
    : > "$new_quality"
fi
cat >> "$new_quality" <<'EOF'
minlen = 12
dcredit = -1
ucredit = -1
lcredit = -1
ocredit = -1
usercheck = 1
difok = 3
EOF

# pam_pwquality passe avant pam_unix pour contrôler le nouveau mot.
if ! awk '
    /^[[:space:]]*password[[:space:]]+.*pam_pwquality[.]so/ { next }
    !inserted && /^[[:space:]]*password[[:space:]]+.*pam_unix[.]so/ {
        print "password requisite pam_pwquality.so retry=3"
        inserted = 1
    }
    { print }
' "$pam_file" > "$new_pam"; then
    error 'Préparation de common-password impossible.'
fi

pam_owner=$(stat -c '%U' "$pam_file") || pam_owner=root
pam_group=$(stat -c '%G' "$pam_file") || pam_group=root
pam_mode=$(stat -c '%a' "$pam_file") || pam_mode=0644
if ! install -o root -g root -m 0644 "$new_quality" "$config_file" || \
    ! install -o "$pam_owner" -g "$pam_group" -m "$pam_mode" \
        "$new_pam" "$pam_file"; then
    cp -a -- "$config_file.backup" "$config_file" 2>/dev/null || true
    cp -a -- "$pam_file.backup" "$pam_file" 2>/dev/null || true
    error 'Écriture de la configuration de qualité ou PAM impossible.'
fi

printf '\nConfiguring %s:\n' "$config_file"
printf '  minlen = 12\n'
printf '  dcredit = -1 (require digit)\n'
printf '  ucredit = -1 (require uppercase)\n'
printf '  lcredit = -1 (require lowercase)\n'
printf '  ocredit = -1 (require special)\n'
printf '  usercheck = 1 (reject username in password)\n'
printf '  difok = 3 (must differ from old password)\n'
printf '\nUpdating %s...\n' "$pam_file"
pwquality_rule='^[[:space:]]*password[[:space:]]+requisite'
pwquality_rule+='[[:space:]]+pam_pwquality[.]so'
if grep -Eq "$pwquality_rule" "$pam_file"; then
    printf '  pam_pwquality.so: Configured\n'
else
    error 'La règle pam_pwquality.so n’a pas été activée.'
fi
for setting in minlen=12 dcredit=-1 ucredit=-1 lcredit=-1 \
    ocredit=-1 usercheck=1 difok=3; do
    setting_name=${setting%%=*}
    setting_value=${setting#*=}
    if ! awk -v key="$setting_name" -v expected="$setting_value" \
        '$1 == key && $2 == "=" && $3 == expected { found = 1 }
        END { exit !found }' "$config_file"; then
        error "Vérification échouée pour $setting_name."
    fi
done

# Je teste la bibliothèque avec des exemples faibles, sans changer de compte.
printf '\nTesting enforcement...\n'
for weak_password in weak Password123; do
    if printf '%s\n' "$weak_password" | pwscore test-user \
        >/dev/null 2>&1; then
        printf "  Attempt '%s': ACCEPTED\n" "$weak_password"
        error 'Un mot de passe faible a été accepté par pwscore.'
    else
        printf "  Attempt '%s': REJECTED ✓\n" "$weak_password"
    fi
done

printf '\nPassword complexity enforcement: ACTIVE\n'
