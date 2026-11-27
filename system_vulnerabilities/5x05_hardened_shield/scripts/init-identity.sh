#!/bin/bash
# Je règle les mots de passe, les connexions SSH et le compte root.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo '[ERREUR] Lance ce script en root dans le conteneur.' >&2
    exit 1
fi

for tool in awk cp find grep install mktemp passwd rm sshd; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "[ERREUR] Commande manquante : $tool" >&2
        exit 1
    fi
done

pam_password=/etc/pam.d/common-password
pam_auth=/etc/pam.d/common-auth
pam_account=/etc/pam.d/common-account
quality_config=/etc/security/pwquality.conf
lock_config=/etc/security/faillock.conf
ssh_config=/etc/ssh/sshd_config
authorized_keys=/home/shieldadmin/.ssh/authorized_keys

# Je charge la clé fournie au démarrage, sans la mettre dans l'image.
if [ -r /run/secrets/authorized_keys ] && [ -s /run/secrets/authorized_keys ]; then
    if ! install -d -o shieldadmin -g shieldadmin -m 0700 \
        /home/shieldadmin/.ssh || \
        ! install -o shieldadmin -g shieldadmin -m 0600 \
            /run/secrets/authorized_keys "$authorized_keys"; then
        echo '[ERREUR] Impossible d’installer la clé SSH.' >&2
        exit 3
    fi
else
    echo '[INFO] Aucune clé fournie. La connexion SSH ne sera pas possible.'
fi

# Je vérifie les fichiers nécessaires avant de les modifier.
for file in "$pam_password" "$pam_auth" "$pam_account" "$ssh_config"; do
    if [ ! -r "$file" ]; then
        echo "[ERREUR] Fichier de configuration introuvable : $file" >&2
        exit 2
    fi
done
if ! find /lib /usr/lib -type f -name pam_faillock.so \
    -print -quit 2>/dev/null | grep -q .; then
    echo '[ERREUR] Le module pam_faillock.so est introuvable.' >&2
    exit 2
fi

# Je garde une copie initiale pour pouvoir revenir en arrière.
for file in "$pam_password" "$pam_auth" "$pam_account" "$ssh_config"; do
    if [ ! -e "$file.backup" ]; then
        if ! cp -a "$file" "$file.backup"; then
            echo "[ERREUR] Impossible de sauvegarder $file." >&2
            exit 3
        fi
    fi
done
for file in "$quality_config" "$lock_config"; do
    if [ -e "$file" ] && [ ! -e "$file.backup" ]; then
        if ! cp -a "$file" "$file.backup"; then
            echo "[ERREUR] Impossible de sauvegarder $file." >&2
            exit 3
        fi
    fi
done

work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT
new_quality=$work_dir/pwquality.conf
new_password=$work_dir/common-password
new_auth=$work_dir/common-auth
new_account=$work_dir/common-account
new_lock=$work_dir/faillock.conf
new_ssh=$work_dir/sshd_config

# Je garde les autres options pwquality et remplace seulement celles-ci.
if [ -r "$quality_config" ]; then
    awk '
        /^[[:space:]]*(minlen|dcredit|ucredit|lcredit|ocredit|usercheck|difok)[[:space:]]*=/ { next }
        { print }
    ' "$quality_config" > "$new_quality"
else
    : > "$new_quality"
fi
cat >> "$new_quality" <<'EOF_CONFIG'
minlen = 12
dcredit = -1
ucredit = -1
lcredit = -1
ocredit = -1
usercheck = 1
difok = 3
EOF_CONFIG

# Je place la vérification du mot de passe avant pam_unix.
if ! awk '
    /^[[:space:]]*password[[:space:]]+[^#].*pam_pwquality[.]so/ { next }
    /^[[:space:]]*password[[:space:]]+[^#].*pam_pwhistory[.]so/ { next }
    !added && /^[[:space:]]*password[[:space:]]+[^#].*pam_unix[.]so/ {
        print "password requisite pam_pwquality.so retry=3"
        print "password required pam_pwhistory.so remember=5 use_authtok"
        added = 1
    }
    { print }
    END { if (!added) exit 1 }
' "$pam_password" > "$new_password"; then
    echo '[ERREUR] Impossible de trouver pam_unix dans common-password.' >&2
    exit 3
fi

# Je compte les échecs avant et après la vérification du mot de passe.
if ! awk '
    /^[[:space:]]*auth[[:space:]]+[^#].*pam_faillock[.]so/ { next }
    !added && /^[[:space:]]*auth[[:space:]]+[^#].*pam_unix[.]so/ {
        print "auth required pam_faillock.so preauth"
        added = 1
    }
    { print }
    !added_fail && /^[[:space:]]*auth[[:space:]]+[^#].*pam_unix[.]so/ {
        print "auth [default=die] pam_faillock.so authfail"
        print "auth sufficient pam_faillock.so authsucc"
        added_fail = 1
    }
    END { if (!added) exit 1 }
' "$pam_auth" > "$new_auth"; then
    echo '[ERREUR] Impossible de trouver pam_unix dans common-auth.' >&2
    exit 3
fi

# Je vérifie aussi le compteur faillock au moment du contrôle de compte.
if ! awk '
    /^[[:space:]]*account[[:space:]]+[^#].*pam_faillock[.]so/ { next }
    !added && /^[[:space:]]*account[[:space:]]+[^#].*pam_unix[.]so/ {
        print "account required pam_faillock.so"
        added = 1
    }
    { print }
    END { if (!added) exit 1 }
' "$pam_account" > "$new_account"; then
    echo '[ERREUR] Impossible de trouver pam_unix dans common-account.' >&2
    exit 3
fi

# Je conserve les autres règles de faillock.conf.
if [ -r "$lock_config" ]; then
    awk '
        /^[[:space:]]*(deny|unlock_time|fail_interval)[[:space:]]*=/ { next }
        { print }
    ' "$lock_config" > "$new_lock"
else
    : > "$new_lock"
fi
cat >> "$new_lock" <<'EOF_LOCK'
deny = 5
unlock_time = 900
fail_interval = 900
EOF_LOCK

# Je mets les options importantes au début pour éviter les anciennes valeurs.
if ! awk '
    BEGIN {
        print "PermitRootLogin no"
        print "PasswordAuthentication no"
        print "PubkeyAuthentication yes"
        print "KbdInteractiveAuthentication no"
        print "ChallengeResponseAuthentication no"
        print "UsePAM yes"
        print "MaxAuthTries 3"
        print "X11Forwarding no"
        print "AllowTcpForwarding no"
        print "AllowUsers shieldadmin"
        print "Banner /etc/issue.net"
        managed["permitrootlogin"] = 1
        managed["passwordauthentication"] = 1
        managed["pubkeyauthentication"] = 1
        managed["kbdinteractiveauthentication"] = 1
        managed["challengeresponseauthentication"] = 1
        managed["usepam"] = 1
        managed["maxauthtries"] = 1
        managed["x11forwarding"] = 1
        managed["allowtcpforwarding"] = 1
        managed["allowusers"] = 1
        managed["banner"] = 1
    }
    /^[[:space:]]*#/ { print; next }
    tolower($1) in managed { next }
    { print }
' "$ssh_config" > "$new_ssh"; then
    echo '[ERREUR] Impossible de préparer sshd_config.' >&2
    exit 3
fi

# J'installe les réglages. Les commandes peuvent être relancées sans doublons.
if ! install -o root -g root -m 0644 "$new_quality" "$quality_config" || \
    ! install -o root -g root -m 0644 "$new_password" "$pam_password" || \
    ! install -o root -g root -m 0644 "$new_auth" "$pam_auth" || \
    ! install -o root -g root -m 0644 "$new_account" "$pam_account" || \
    ! install -o root -g root -m 0644 "$new_lock" "$lock_config" || \
    ! install -o root -g root -m 0644 "$new_ssh" "$ssh_config"; then
    echo '[ERREUR] Impossible d’installer les réglages d’identité.' >&2
    exit 3
fi

# Je désactive le mot de passe root, mais je ne supprime pas le compte.
root_status=$(passwd -S root | awk '{ print $2 }')
if [ "$root_status" != L ] && [ "$root_status" != LK ]; then
    if ! passwd -l root >/dev/null 2>&1; then
        echo '[ERREUR] Impossible de verrouiller le compte root.' >&2
        exit 3
    fi
fi

# Je vérifie les lignes principales avant de valider le script.
if ! grep -Eq '^[[:space:]]*password[[:space:]]+requisite[[:space:]]+pam_pwquality[.]so' "$pam_password" || \
    ! grep -Eq '^[[:space:]]*password[[:space:]]+required[[:space:]]+pam_pwhistory[.]so.*remember=5.*use_authtok' "$pam_password" || \
    ! grep -Eq '^[[:space:]]*auth[[:space:]]+required[[:space:]]+pam_faillock[.]so[[:space:]]+preauth' "$pam_auth" || \
    ! grep -Eq '^[[:space:]]*auth[[:space:]]+\[default=die\][[:space:]]+pam_faillock[.]so[[:space:]]+authfail' "$pam_auth" || \
    ! grep -Eq '^[[:space:]]*account[[:space:]]+required[[:space:]]+pam_faillock[.]so' "$pam_account" || \
    ! grep -Eq '^[[:space:]]*minlen[[:space:]]*=[[:space:]]*12' "$quality_config" || \
    ! grep -Eq '^[[:space:]]*dcredit[[:space:]]*=[[:space:]]*-1' "$quality_config" || \
    ! grep -Eq '^[[:space:]]*ucredit[[:space:]]*=[[:space:]]*-1' "$quality_config" || \
    ! grep -Eq '^[[:space:]]*lcredit[[:space:]]*=[[:space:]]*-1' "$quality_config" || \
    ! grep -Eq '^[[:space:]]*ocredit[[:space:]]*=[[:space:]]*-1' "$quality_config" || \
    ! grep -Eq '^[[:space:]]*deny[[:space:]]*=[[:space:]]*5' "$lock_config" || \
    ! grep -Eq '^[[:space:]]*unlock_time[[:space:]]*=[[:space:]]*900' "$lock_config" || \
    ! grep -Eq '^[[:space:]]*fail_interval[[:space:]]*=[[:space:]]*900' "$lock_config" || \
    ! grep -Eq '^PermitRootLogin no$' "$ssh_config" || \
    ! grep -Eq '^PasswordAuthentication no$' "$ssh_config" || \
    ! grep -Eq '^PubkeyAuthentication yes$' "$ssh_config" || \
    ! grep -Eq '^AllowUsers shieldadmin$' "$ssh_config"; then
    echo '[ERREUR] La vérification des réglages d’identité a échoué.' >&2
    exit 4
fi

root_status=$(passwd -S root | awk '{ print $2 }')
if [ "$root_status" != L ] && [ "$root_status" != LK ]; then
    echo '[ERREUR] Le compte root n’est pas verrouillé.' >&2
    exit 4
fi

if ! sshd -t >/dev/null 2>&1; then
    echo '[ERREUR] sshd_config est invalide.' >&2
    exit 4
fi

echo '[RÉUSSI] Politique PAM, verrouillage, SSH et compte root configurés.'
exit 0
