#!/bin/bash
# Orchestre les modules de durcissement Ubuntu 20.04.
# L’orchestration est idempotente, conserve la baseline et journalise les
# actions dans /var/log/hardening/master_harden.log.

set -o pipefail

usage()
{
    printf 'Usage: %s --apply [--yes]\n' "${0##*/}"
    printf '  --apply  Exécute les modules de durcissement.\n'
    printf '  --yes    Confirme sans question interactive.\n'
}

error()
{
    printf '[ERROR] %s\n' "$1" >&2
    exit 1
}

apply_changes=0
assume_yes=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        --apply)
            apply_changes=1
            ;;
        --yes)
            assume_yes=1
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            usage >&2
            error "Option inconnue: $1"
            ;;
    esac
    shift
done

if [ "$apply_changes" -ne 1 ]; then
    usage
    printf '\nAucune modification effectuée. Relance avec --apply après revue.\n'
    exit 0
fi

if [ "$(id -u)" -ne 0 ]; then
    error 'Lance ce script avec sudo depuis le compte administrateur.'
fi
if [ -z "${SUDO_USER:-}" ] || [ "$SUDO_USER" = root ]; then
    error 'Utilise sudo depuis un compte administrateur non-root.'
fi
if [ ! -r /etc/os-release ]; then
    error 'Impossible de vérifier la version du système.'
fi

source /etc/os-release
if [ "${ID:-}" != ubuntu ] || [ "${VERSION_ID:-}" != 20.04 ]; then
    error 'Ce script est prévu pour Ubuntu 20.04 uniquement.'
fi

for command_name in awk bash chmod cp date dirname find install mkdir \
    mktemp pwd runuser sshd stat sysctl systemctl apt-get tee touch sudo; do
    command -v "$command_name" >/dev/null 2>&1 ||
        error "Commande requise introuvable: $command_name"
done

script_directory=$(cd -- "$(dirname -- "$0")" && pwd) ||
    error 'Impossible de déterminer le dossier des modules.'
report_directory=/var/log/hardening
log_file=$report_directory/master_harden.log
mkdir -p -- "$report_directory" ||
    error "Impossible de créer $report_directory."
touch "$log_file" || error "Impossible d’écrire dans $log_file."
chmod 0600 "$log_file" || error "Impossible de protéger $log_file."
exec > >(tee -a "$log_file") 2>&1

modules=(
    0-lynis_baseline.sh
    9-package_audit.sh
    12-lolbins_audit.sh
    13-suid_audit.sh
    2-disable_forwarding.sh
    3-block_redirects.sh
    4-rp_filter.sh
    5-syn_cookies.sh
    6-icmp_config.sh
    7-source_routing.sh
    8-verify_kernel.sh
    10-remove_compilers.sh
    11-restrict_nettools.sh
    15-remove_suid.sh
    17-harden_tmp.sh
    18-harden_other_tmp.sh
    19-verify_filesystem.sh
    20-minimize_services.sh
    21-lock_root.sh
    22-legal_banner.sh
)

for module in "${modules[@]}"; do
    [ -f "$script_directory/$module" ] ||
        error "Module manquant: $script_directory/$module"
done

if ! systemctl list-unit-files --type=service --no-legend --no-pager \
    | awk '$1 == "apache2.service" || $1 == "nginx.service" ||
        $1 == "httpd.service" { found = 1 }
        END { exit !found }'; then
    error 'Installe et configure Apache ou Nginx avant le durcissement.'
fi
systemctl is-active --quiet ssh.service ||
    systemctl is-active --quiet sshd.service ||
    error 'Le service SSH doit être actif avant le durcissement.'
active_web=0
for web_service in apache2.service nginx.service httpd.service; do
    if systemctl is-active --quiet "$web_service"; then
        active_web=1
        break
    fi
done
if [ "$active_web" -ne 1 ]; then
    error 'Le serveur Web doit être actif avant le durcissement.'
fi

if [ "$assume_yes" -ne 1 ]; then
    printf 'Ce script va modifier le noyau, les paquets, les montages, '
    printf 'les services, les permissions et le compte root.\n'
    printf 'Un accès administratif opérationnel et une sauvegarde sont '
    printf 'nécessaires. Continuer ? [y/N] '
    read -r confirmation
    case "$confirmation" in
        y|Y|yes|YES)
            ;;
        *)
            printf 'Opération annulée, aucune mesure appliquée.\n'
            exit 0
            ;;
    esac
fi

if ! command -v lynis >/dev/null 2>&1; then
    printf '[INFO] Lynis absent, installation depuis les dépôts Ubuntu.\n'
    apt-get update || error 'Mise à jour des index APT échouée.'
    DEBIAN_FRONTEND=noninteractive apt-get install -y lynis ||
        error 'Installation de Lynis échouée.'
fi

run_module()
{
    local module=$1
    local result

    printf '\n[%s] Début du module %s\n' \
        "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$module"
    if bash "$script_directory/$module"; then
        printf '[%s] Module terminé: %s\n' \
            "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$module"
    else
        result=$?
        printf '[%s] ÉCHEC du module %s (code %s). Arrêt.\n' \
            "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$module" "$result"
        exit "$result"
    fi
}

minimize_software()
{
    printf '\n=== Software Minimization ===\n'
    # Le module vérifie les dépendances avant apt-get remove gcc, g++ et make.
    run_module 10-remove_compilers.sh
    # Le module limite ensuite les outils réseau aux administrateurs.
    run_module 11-restrict_nettools.sh
}

hardening_temporary_filesystems()
{
    printf '\n=== Temporary Filesystem Hardening ===\n'
    # Configure /tmp et ses options persistantes noexec,nosuid,nodev.
    run_module 17-harden_tmp.sh
    # Le module met aussi à jour /etc/fstab pour /var/tmp et /dev/shm.
    run_module 18-harden_other_tmp.sh
    run_module 19-verify_filesystem.sh
}

disable_ssh_root_login()
{
    local ssh_config=/etc/ssh/sshd_config
    local ssh_backup=$report_directory/sshd_config.master-backup
    local temporary_config
    local owner
    local group
    local mode
    local current_policy

    printf '\n[%s] Désactivation de la connexion SSH directe de root\n' \
        "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    sudo -n -l -U "$SUDO_USER" >/dev/null 2>&1 ||
        error "Le compte $SUDO_USER ne dispose pas de règles sudo."
    runuser -u "$SUDO_USER" -- sudo -n -u root /usr/bin/true ||
        error "La vérification sudo a échoué pour $SUDO_USER."
    [ -f "$ssh_config" ] || error "Configuration SSH absente: $ssh_config"
    systemctl is-active --quiet ssh.service ||
        systemctl is-active --quiet sshd.service ||
        error 'Aucun service SSH actif, arrêt avant modification.'

    current_policy=$(sshd -T 2>/dev/null |
        awk '$1 == "permitrootlogin" { print $2; exit }') || current_policy=
    if [ "$current_policy" = no ]; then
        printf '[INFO] PermitRootLogin est déjà désactivé.\n'
        return 0
    fi

    if [ ! -f "$ssh_backup" ]; then
        cp -a -- "$ssh_config" "$ssh_backup" ||
            error 'Impossible de sauvegarder sshd_config.'
    fi
    temporary_config=$(mktemp /etc/ssh/sshd_config.XXXXXX) ||
        error 'Impossible de préparer la configuration SSH.'
    if ! awk '
        BEGIN { print "PermitRootLogin no"; in_match = 0 }
        /^[[:space:]]*Match[[:space:]]/ { in_match = 1 }
        !in_match && /^[[:space:]]*PermitRootLogin[[:space:]]/ { next }
        { print }
    ' "$ssh_config" > "$temporary_config"; then
        rm -f -- "$temporary_config"
        error 'Impossible de préparer la règle PermitRootLogin.'
    fi

    owner=$(stat -c '%U' "$ssh_config") || owner=root
    group=$(stat -c '%G' "$ssh_config") || group=root
    mode=$(stat -c '%a' "$ssh_config") || mode=0644
    if ! install -o "$owner" -g "$group" -m "$mode" \
        "$temporary_config" "$ssh_config"; then
        rm -f -- "$temporary_config"
        error 'Impossible d’installer la configuration SSH.'
    fi
    rm -f -- "$temporary_config"

    if ! sshd -t ||
        [ "$(sshd -T 2>/dev/null | awk '$1 == "permitrootlogin" {
            print $2; exit
        }')" != no ]; then
        cp -a -- "$ssh_backup" "$ssh_config"
        error 'Configuration SSH invalide ou PermitRootLogin non désactivé.'
    fi

    if systemctl is-active --quiet ssh.service; then
        systemctl reload ssh.service || error 'Rechargement de SSH échoué.'
    else
        systemctl reload sshd.service || error 'Rechargement de SSH échoué.'
    fi
    printf '[%s] SSH root login désactivé et configuration rechargée\n' \
        "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
}

baseline_exists=$(find "$report_directory" -maxdepth 1 -type f \
    -name 'baseline-*.txt' -print -quit)
run_baseline=0
if [ -n "$baseline_exists" ]; then
    printf '[INFO] Une baseline existe déjà: %s\n' "$baseline_exists"
    printf '[INFO] Elle est conservée pour comparer l’audit final.\n'
    modules=("${modules[@]:1}")
else
    run_baseline=1
    modules=("${modules[@]:1}")
fi

printf '=== Ubuntu 20.04 Master Hardening ===\n'
printf 'Started: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
printf 'Log: %s\n' "$log_file"

if [ "$run_baseline" -eq 1 ]; then
    run_module 0-lynis_baseline.sh
fi
disable_ssh_root_login

for module in "${modules[@]}"; do
    case "$module" in
        10-remove_compilers.sh)
            minimize_software
            ;;
        11-restrict_nettools.sh)
            continue
            ;;
        17-harden_tmp.sh)
            hardening_temporary_filesystems
            ;;
        18-harden_other_tmp.sh|19-verify_filesystem.sh)
            continue
            ;;
        *)
            run_module "$module"
            ;;
    esac
done

run_module 13-suid_audit.sh
run_module 23-final_audit.sh

printf '\nAll hardening modules completed successfully.\n'
printf 'Review the final Lynis report and obtain CISO approval before DMZ use.\n'
printf 'Finished: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
