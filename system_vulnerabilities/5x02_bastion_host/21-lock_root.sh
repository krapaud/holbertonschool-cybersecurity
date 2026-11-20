#!/bin/bash
# Je verrouille le mot de passe root après avoir vérifié sudo et SSH.

set -o pipefail

if [ "$(id -u)" -ne 0 ]; then
    printf '[ERROR] Lance ce script avec sudo depuis le compte admin.\n' >&2
    exit 1
fi

for command_name in awk getent passwd runuser sshd sudo visudo; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf '[ERROR] Commande requise introuvable: %s\n' \
            "$command_name" >&2
        exit 1
    fi
done

admin_user=$SUDO_USER
if [ -z "$admin_user" ] || [ "$admin_user" = root ]; then
    printf '[ERROR] Relance le script avec sudo depuis un compte admin.\n' >&2
    exit 1
fi
if ! getent passwd "$admin_user" >/dev/null; then
    printf '[ERROR] Le compte d’origine %s est introuvable.\n' \
        "$admin_user" >&2
    exit 1
fi

printf '=== Root Account Lockdown ===\n\n'
printf 'Pre-flight checks:\n'
if sudo -n -l -U "$admin_user" >/dev/null 2>&1; then
    printf '  Current user has sudo: YES ✓\n'
else
    printf '[ERROR] %s ne dispose pas de règles sudo.\n' \
        "$admin_user" >&2
    exit 1
fi

if ! visudo -c >/dev/null 2>&1; then
    printf '[ERROR] La configuration sudo est invalide.\n' >&2
    exit 1
fi
printf '  Sudo configuration valid: YES ✓\n'

if ! runuser -u "$admin_user" -- sudo -n -u root /usr/bin/true; then
    printf '[ERROR] Le compte %s ne peut pas obtenir les droits root\n' \
        "$admin_user" >&2
    exit 1
fi

ssh_policy=$(sshd -T 2>/dev/null |
    awk '$1 == "permitrootlogin" { print $2; exit }') || ssh_policy=
if [ "$ssh_policy" != no ]; then
    printf '[ERROR] PermitRootLogin doit déjà être défini à no.\n' >&2
    exit 1
fi

root_status=$(passwd -S root 2>/dev/null | awk '{ print $2 }') || {
    printf '[ERROR] Impossible de vérifier le compte root.\n' >&2
    exit 1
}

printf '\nLocking root account...\n'
if [ "$root_status" = L ]; then
    printf '  passwd -l root: Already locked\n'
elif passwd -l root >/dev/null; then
    printf '  passwd -l root: Done\n'
else
    printf '[ERROR] Verrouillage du compte root échoué.\n' >&2
    exit 1
fi

printf '\nVerification:\n'
root_status=$(passwd -S root 2>/dev/null | awk '{ print $2 }') || {
    printf '[ERROR] Vérification du compte root échouée.\n' >&2
    exit 1
}
if [ "$root_status" != L ]; then
    printf '[ERROR] Le mot de passe root n’est pas verrouillé.\n' >&2
    exit 1
fi
printf '  Root password: LOCKED (!)\n'

ssh_policy=$(sshd -T 2>/dev/null |
    awk '$1 == "permitrootlogin" { print $2; exit }') || ssh_policy=
if [ "$ssh_policy" != no ]; then
    printf '[ERROR] L’accès SSH root n’est pas désactivé.\n' >&2
    exit 1
fi
printf '  Root SSH login: Disabled (PermitRootLogin no)\n'

if runuser -u "$admin_user" -- sudo -n -u root /usr/bin/true; then
    printf '  Sudo to root: WORKING ✓\n'
else
    printf '[ERROR] Vérification sudo après verrouillage échouée.\n' >&2
    exit 1
fi

printf '\nWARNING: Direct root login is now impossible.\n'
printf 'All administrative tasks must use sudo.\n'
