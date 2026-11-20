#!/bin/bash
# Je protège /tmp de l’exécution et des fichiers spéciaux privilégiés.

set -o pipefail

if [ "$(id -u)" -ne 0 ]; then
    printf '[ERROR] Lance ce script avec sudo dans la VM de laboratoire.\n' \
        >&2
    exit 1
fi

required_commands=(
    awk chmod cp date find findmnt grep install mkdir mktemp mount
    mountpoint rm
)
for command_name in "${required_commands[@]}"; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf '[ERROR] Commande requise introuvable: %s\n' \
            "$command_name" >&2
        exit 1
    fi
done

fstab_file=/etc/fstab
backup_directory=/var/backups/hardening
timestamp=$(date -u '+%Y%m%dT%H%M%SZ')

if [ ! -f "$fstab_file" ] || [ ! -w "$fstab_file" ]; then
    printf '[ERROR] %s est absent ou non modifiable.\n' "$fstab_file" >&2
    exit 1
fi

temporary_directory=$(mktemp -d) || {
    printf '[ERROR] Impossible de créer un dossier temporaire.\n' >&2
    exit 1
}
trap 'rm -rf -- "$temporary_directory"' EXIT

new_fstab=$temporary_directory/fstab
mount_options=defaults,noexec,nosuid,nodev

printf '=== Hardening /tmp ===\n\n'
printf 'Current /tmp mount:\n'
findmnt --target /tmp --output SOURCE,TARGET,FSTYPE,OPTIONS \
    --noheadings 2>/dev/null || printf '  /tmp is not a separate mount\n'

printf '\nApplying hardening options...\n'
printf 'Method: dedicated tmpfs mount\n'

# Je remplace une éventuelle entrée active de /tmp pour éviter les doublons.
if ! awk '
    /^[[:space:]]*#/ || NF == 0 { print; next }
    $2 != "/tmp" { print }
' "$fstab_file" > "$new_fstab"; then
    printf '[ERROR] Préparation de %s impossible.\n' \
        'la nouvelle configuration fstab' >&2
    exit 1
fi

printf 'tmpfs /tmp tmpfs %s 0 0\n' "$mount_options" >> "$new_fstab"

if ! mkdir -p "$backup_directory" ||
    ! cp -a -- "$fstab_file" "$backup_directory/fstab.$timestamp"; then
    printf '[ERROR] Sauvegarde de %s impossible.\n' "$fstab_file" >&2
    exit 1
fi

if ! install -o root -g root -m 0644 "$new_fstab" "$fstab_file"; then
    printf '[ERROR] Mise à jour de %s impossible.\n' "$fstab_file" >&2
    exit 1
fi

printf 'Adding to %s:\n' "$fstab_file"
printf '  tmpfs /tmp tmpfs %s 0 0\n' "$mount_options"

printf '\nRemounting /tmp...\n'
if mountpoint -q /tmp; then
    if ! mount -o "remount,$mount_options" /tmp; then
        printf '[ERROR] Remontage de /tmp impossible.\n' >&2
        exit 1
    fi
else
    if ! mount -t tmpfs -o "$mount_options" tmpfs /tmp; then
        printf '[ERROR] Montage tmpfs sur /tmp impossible.\n' >&2
        exit 1
    fi
fi

printf '\nVerification:\n'
active_options=$(findmnt --noheadings --target /tmp --output OPTIONS) || {
    printf '[ERROR] Impossible de vérifier les options de /tmp.\n' >&2
    exit 1
}
printf '  /tmp mount options: %s\n' "$active_options"

for required_option in noexec nosuid nodev; do
    case ",$active_options," in
        *,"$required_option",*)
            ;;
        *)
            printf '[ERROR] Option de montage absente: %s\n' \
                "$required_option" >&2
            exit 1
            ;;
    esac
done

printf '  SUID test: BLOCKED (nosuid active)\n'

# Je vérifie noexec sans lancer de contenu potentiellement dangereux.
test_script=/tmp/.hardening-exec-test-$$
printf '#!/bin/sh\nexit 0\n' > "$test_script" || {
    printf '[ERROR] Création du fichier de vérification impossible.\n' >&2
    exit 1
}
chmod 0700 "$test_script" || {
    rm -f -- "$test_script"
    printf '[ERROR] Préparation du test noexec impossible.\n' >&2
    exit 1
}
if "$test_script" >/dev/null 2>&1; then
    rm -f -- "$test_script"
    printf '  Execute test: FAILED (execution was allowed)\n' >&2
    exit 1
else
    printf '  Execute test: BLOCKED (noexec active)\n'
fi
rm -f -- "$test_script"

fstab_pattern='^[[:space:]]*tmpfs[[:space:]]+/tmp[[:space:]]+tmpfs'
fstab_pattern+='[[:space:]]+[^[:space:]]*noexec[^[:space:]]*nosuid'
fstab_pattern+='[^[:space:]]*nodev'
if grep -Eq "$fstab_pattern" \
    "$fstab_file"; then
    printf '  Persistent fstab entry: VERIFIED\n'
else
    printf '[ERROR] Entrée persistante de /tmp non vérifiée.\n' >&2
    exit 1
fi

printf '\n/tmp hardened successfully.\n'
