#!/bin/bash
# Je protège /var/tmp et /dev/shm des exécutions et privilèges SUID.

set -o pipefail

if [ "$(id -u)" -ne 0 ]; then
    printf '[ERROR] Lance ce script avec sudo dans la VM de laboratoire.\n' \
        >&2
    exit 1
fi

required_commands=(
    awk cp date findmnt grep install mkdir mktemp mount mountpoint rm
)
for command_name in "\${required_commands[@]}"; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf '[ERROR] Commande requise introuvable: %s\n' \
            "$command_name" >&2
        exit 1
    fi
done

fstab_file=/etc/fstab
backup_directory=/var/backups/hardening
timestamp=$(date -u '+%Y%m%dT%H%M%SZ')
mount_options=defaults,noexec,nosuid,nodev

if [ ! -f "$fstab_file" ] || [ ! -w "$fstab_file" ]; then
    printf '[ERROR] %s est absent ou non modifiable.\n' "$fstab_file" >&2
    exit 1
fi

if [ ! -d /tmp ] || [ ! -d /var/tmp ] || [ ! -d /dev/shm ]; then
    printf '[ERROR] Un des répertoires temporaires est absent.\n' >&2
    exit 1
fi

# /var/tmp est lié à /tmp, donc il hérite de ses protections.
verify_mount_options()
{
    local mount_path=$1
    local active_options
    local required_option

    active_options=$(findmnt --noheadings --target "$mount_path" \
        --output OPTIONS) || return 1

    for required_option in noexec nosuid nodev; do
        case ",$active_options," in
            *,"$required_option",*)
                ;;
            *)
                printf '[ERROR] %s ne possède pas %s.\n' \
                    "$mount_path" "$required_option" >&2
                return 1
                ;;
        esac
    done
    printf '  %s: noexec,nosuid,nodev ✓\n' "$mount_path"
}

if ! verify_mount_options /tmp >/dev/null; then
    printf '[ERROR] Durcis /tmp avant de lancer ce script.\n' >&2
    exit 1
fi

temporary_directory=$(mktemp -d) || {
    printf '[ERROR] Impossible de créer un dossier temporaire.\n' >&2
    exit 1
}
trap 'rm -rf -- "$temporary_directory"' EXIT

new_fstab=$temporary_directory/fstab

printf '=== Hardening /var/tmp and /dev/shm ===\n\n'
printf 'Hardening /var/tmp...\n'
printf '  Bind mount to /tmp (inherits restrictions)\n'

printf 'Hardening /dev/shm...\n'
findmnt --target /dev/shm --output SOURCE,FSTYPE,OPTIONS \
    --noheadings 2>/dev/null |
    while IFS= read -r mount_details; do
        printf '  Current: %s\n' "$mount_details"
    done
printf '  Adding: noexec,nosuid,nodev\n'

# Je retire les anciennes entrées actives de ces points de montage.
if ! awk '
    /^[[:space:]]*#/ || NF == 0 { print; next }
    $2 != "/var/tmp" && $2 != "/dev/shm" { print }
' "$fstab_file" > "$new_fstab"; then
    printf '[ERROR] Préparation de la configuration fstab impossible.\n' >&2
    exit 1
fi

printf '/tmp /var/tmp none bind 0 0\n' >> "$new_fstab"
printf 'tmpfs /dev/shm tmpfs %s 0 0\n' "$mount_options" >> "$new_fstab"

if ! mkdir -p "$backup_directory" ||
    ! cp -a -- "$fstab_file" "$backup_directory/fstab.$timestamp"; then
    printf '[ERROR] Sauvegarde de %s impossible.\n' "$fstab_file" >&2
    exit 1
fi

if ! install -o root -g root -m 0644 "$new_fstab" "$fstab_file"; then
    printf '[ERROR] Mise à jour de %s impossible.\n' "$fstab_file" >&2
    exit 1
fi

printf '  Added to %s\n' "$fstab_file"

printf '\nRemounting...\n'
if mountpoint -q /var/tmp; then
    if ! mount -o remount,bind,noexec,nosuid,nodev /tmp /var/tmp; then
        printf '[ERROR] Remontage bind de /var/tmp impossible.\n' >&2
        exit 1
    fi
else
    if ! mount --bind /tmp /var/tmp ||
        ! mount -o remount,bind,noexec,nosuid,nodev /tmp /var/tmp; then
        printf '[ERROR] Montage protégé de /var/tmp impossible.\n' >&2
        exit 1
    fi
fi

if mountpoint -q /dev/shm; then
    if ! mount -o "remount,$mount_options" /dev/shm; then
        printf '[ERROR] Remontage protégé de /dev/shm impossible.\n' >&2
        exit 1
    fi
else
    if ! mount -t tmpfs -o "$mount_options" tmpfs /dev/shm; then
        printf '[ERROR] Montage tmpfs protégé de /dev/shm impossible.\n' >&2
        exit 1
    fi
fi

printf '\nVerification:\n'
verify_mount_options /var/tmp || exit 1
verify_mount_options /dev/shm || exit 1

if ! awk '
    /^[[:space:]]*#/ || NF == 0 { next }
    $2 == "/var/tmp" && $1 == "/tmp" && $4 ~ /bind/ {
        var_tmp = 1
    }
    $2 == "/dev/shm" && $1 == "tmpfs" &&
        $4 ~ /noexec/ && $4 ~ /nosuid/ && $4 ~ /nodev/ {
        dev_shm = 1
    }
    END { if (var_tmp && dev_shm) exit 0; exit 1 }
' "$fstab_file"; then
    printf '[ERROR] Les entrées persistantes de fstab sont absentes.\n' >&2
    exit 1
fi

printf '\nAll temporary directories hardened.\n'
