#!/bin/bash
# Je réduis les services actifs sans toucher à SSH ni au serveur web.

set -o pipefail

if [ "$(id -u)" -ne 0 ]; then
    printf '[ERROR] Lance ce script avec sudo dans la VM de laboratoire.\n' \
        >&2
    exit 1
fi

if ! command -v systemctl >/dev/null 2>&1; then
    printf '[ERROR] systemctl est introuvable sur ce système.\n' >&2
    exit 1
fi

system_state=$(systemctl is-system-running 2>&1) || true
case "$system_state" in
    running|degraded|starting)
        ;;
    *)
        printf '[ERROR] systemd ne semble pas gérer ce système: %s\n' \
            "$system_state" >&2
        exit 1
        ;;
esac

unit_is_installed()
{
    local unit_name=$1

    systemctl list-unit-files --type=service --no-legend --no-pager \
        "$unit_name" 2>/dev/null |
        awk -v wanted="$unit_name" '$1 == wanted { found = 1 }
            END { exit !found }'
}

find_active_service()
{
    local service_name

    for service_name in "$@"; do
        if systemctl is-active --quiet "$service_name"; then
            printf '%s\n' "$service_name"
            return 0
        fi
    done
    return 1
}

ssh_service=$(find_active_service sshd.service ssh.service) || {
    printf '[ERROR] Aucun service SSH actif. Je ne modifie rien.\n' >&2
    exit 1
}
web_service=$(find_active_service \
    apache2.service nginx.service httpd.service) || {
    printf '[ERROR] Aucun serveur web actif. Je ne modifie rien.\n' >&2
    exit 1
}

optional_units=(
    'cups.service|Printing|Not needed on web server'
    'avahi-daemon.service|mDNS|Not needed on web server'
    'bluetooth.service|Bluetooth|Not needed on server'
)
found_units=()
failed=0

printf '=== Service Minimization ===\n\n'
printf 'Checking for unnecessary services...\n\n'
printf 'Unnecessary services found:\n'
for unit_entry in "${optional_units[@]}"; do
    IFS='|' read -r unit_name unit_kind reason <<< "$unit_entry"
    if unit_is_installed "$unit_name"; then
        found_units+=("$unit_name")
        printf '  %s (%s) - %s\n' "$unit_name" "$unit_kind" "$reason"
    fi
done
if [ "${#found_units[@]}" -eq 0 ]; then
    printf '  None found\n'
fi

printf '\nDisabling services...\n'
for unit_name in "${found_units[@]}"; do
    enabled_state=$(systemctl is-enabled "$unit_name" 2>/dev/null) ||
        enabled_state=disabled
    active_state=$(systemctl is-active "$unit_name" 2>/dev/null) ||
        active_state=inactive

    if [[ "$enabled_state" == enabled ||
        "$enabled_state" == enabled-runtime ||
        "$enabled_state" == linked ||
        "$enabled_state" == linked-runtime ]]; then
        if systemctl disable --now "$unit_name" >/dev/null; then
            printf '  %s: Disabled and stopped\n' "$unit_name"
        else
            printf '[ERROR] Désactivation de %s échouée.\n' \
                "$unit_name" >&2
            failed=1
        fi
    elif [ "$active_state" = active ]; then
        if systemctl stop "$unit_name"; then
            printf '  %s: Stopped (already disabled)\n' "$unit_name"
        else
            printf '[ERROR] Arrêt de %s échoué.\n' "$unit_name" >&2
            failed=1
        fi
    else
        printf '  %s: Already disabled and stopped\n' "$unit_name"
    fi

    active_state=$(systemctl is-active "$unit_name" 2>/dev/null) ||
        active_state=inactive
    enabled_state=$(systemctl is-enabled "$unit_name" 2>/dev/null) ||
        enabled_state=disabled
    if [ "$active_state" = active ] ||
        [[ "$enabled_state" == enabled ||
            "$enabled_state" == enabled-runtime ||
            "$enabled_state" == linked ||
            "$enabled_state" == linked-runtime ]]; then
        printf '[ERROR] %s est encore actif ou activé au démarrage.\n' \
            "$unit_name" >&2
        failed=1
    fi
done

printf '\nEssential services preserved:\n'
if systemctl is-active --quiet "$ssh_service"; then
    printf '  %s: Running ✓\n' "$ssh_service"
else
    printf '[ERROR] Le service SSH n’est plus actif.\n' >&2
    failed=1
fi
if systemctl is-active --quiet "$web_service"; then
    printf '  %s: Running ✓\n' "$web_service"
else
    printf '[ERROR] Le serveur web n’est plus actif.\n' >&2
    failed=1
fi

if [ "$failed" -ne 0 ]; then
    printf '\n[ERROR] Certaines vérifications ont échoué.\n' >&2
    exit 1
fi

printf '\nServices reduced. Attack surface minimized.\n'
