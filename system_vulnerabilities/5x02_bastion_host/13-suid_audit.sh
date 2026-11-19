#!/bin/bash
# Je recense les binaires SUID et SGID sans modifier leurs permissions.

set -o pipefail

if [ "$(id -u)" -ne 0 ]; then
    printf '[ERROR] Lance cet audit avec sudo dans la VM de laboratoire.\n' >&2
    exit 1
fi

for command_name in find stat install mktemp; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf '[ERROR] Commande requise introuvable: %s\n' \
            "$command_name" >&2
        exit 1
    fi
done

report_directory=/var/log/hardening
report_file=$report_directory/suid_audit.txt
temporary_directory=$(mktemp -d) || {
    printf '[ERROR] Impossible de créer un dossier temporaire.\n' >&2
    exit 1
}
trap 'rm -rf -- "$temporary_directory"' EXIT

binary_list=$temporary_directory/binaries
find_errors=$temporary_directory/find-errors
report_content=$temporary_directory/report

if ! find / -xdev \( -path /proc -o -path /sys -o -path /dev \
    -o -path /run \) -prune -o -type f \
    \( -perm -4000 -o -perm -2000 \) -print0 \
    > "$binary_list" 2> "$find_errors"; then
    printf '[ERROR] La recherche des binaires SUID/SGID a échoué.\n' >&2
    exit 1
fi

report()
{
    printf '%s\n' "$*" >> "$report_content"
}

get_risk_label()
{
    local binary_path=$1
    local binary_name=${binary_path##*/}

    case "$binary_path" in
        /usr/local/*|/opt/*)
            printf 'UNKNOWN - HIGH RISK'
            ;;
        *)
            case "$binary_name" in
                sudo|passwd|chsh|ssh-agent)
                    printf 'KNOWN SAFE'
                    ;;
                *)
                    printf 'REVIEW NEEDED'
                    ;;
            esac
            ;;
    esac
}

: > "$report_content"
report '=== SUID/SGID Binary Audit ==='
report ''
report 'SUID binaries (run as owner):'
suid_total=0
sgid_total=0
unknown_total=0

while IFS= read -r -d '' binary_path; do
    mode=$(stat -c '%a' "$binary_path" 2>/dev/null) || {
        printf '[ERROR] Impossible de lire les permissions: %s\n' \
            "$binary_path" >&2
        exit 1
    }
    owner=$(stat -c '%U' "$binary_path" 2>/dev/null) || owner=unknown
    group=$(stat -c '%G' "$binary_path" 2>/dev/null) || group=unknown
    [[ "$mode" =~ ^[0-7]+$ ]] || continue
    mode_number=$((8#$mode))
    risk_label=$(get_risk_label "$binary_path")

    if (( mode_number & 04000 )); then
        printf -v report_line '  %-30s %-10s %s' \
            "$binary_path" "$owner" "$risk_label"
        report "$report_line"
        suid_total=$((suid_total + 1))
    fi
    if [[ "$risk_label" == 'UNKNOWN - HIGH RISK' ]]; then
        unknown_total=$((unknown_total + 1))
    fi
done < "$binary_list"

report ''
report 'SGID binaries (run as group):'
while IFS= read -r -d '' binary_path; do
    mode=$(stat -c '%a' "$binary_path" 2>/dev/null) || continue
    [[ "$mode" =~ ^[0-7]+$ ]] || continue
    mode_number=$((8#$mode))
    (( mode_number & 02000 )) || continue
    group=$(stat -c '%G' "$binary_path" 2>/dev/null) || group=unknown
    risk_label=$(get_risk_label "$binary_path")
    printf -v report_line '  %-30s %-10s %s' \
        "$binary_path" "$group" "$risk_label"
    report "$report_line"
    sgid_total=$((sgid_total + 1))
done < "$binary_list"

report ''
report 'Summary:'
report "  Total SUID: $suid_total"
report "  Total SGID: $sgid_total"
report "  Unknown/Custom: $unknown_total (requires investigation)"
report ''
report "Full report saved to: $report_file"

if ! mkdir -p "$report_directory" ||
    ! install -o root -g root -m 0640 "$report_content" "$report_file"; then
    printf '[ERROR] Impossible d’enregistrer le rapport %s.\n' \
        "$report_file" >&2
    exit 1
fi

cat "$report_content"
