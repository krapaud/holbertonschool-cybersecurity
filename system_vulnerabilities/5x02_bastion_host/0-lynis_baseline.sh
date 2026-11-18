#!/bin/bash
# Établit une référence de sécurité avec Lynis et archive son rapport.

set -o pipefail

if [ "$(id -u)" -ne 0 ]; then
    printf '[ERROR] Exécute cet audit avec sudo.\n' >&2
    exit 1
fi

if ! command -v lynis >/dev/null 2>&1; then
    printf '[ERROR] Lynis est introuvable. Installe-le avant de continuer.\n' \
        >&2
    exit 1
fi

if ! command -v install >/dev/null 2>&1 ||
    ! command -v awk >/dev/null 2>&1; then
    printf '[ERROR] Commandes requises absentes: install ou awk.\n' >&2
    exit 1
fi

report_directory=/var/log/hardening
report_date=$(date '+%Y%m%d')
report_file="$report_directory/baseline-$report_date.txt"
temporary_directory=$(mktemp -d) || {
    printf '[ERROR] Impossible de créer un dossier temporaire.\n' >&2
    exit 1
}
trap 'rm -rf -- "$temporary_directory"' EXIT

lynis_output="$temporary_directory/lynis-output.txt"
summary_file="$temporary_directory/baseline.txt"

mkdir -p -- "$report_directory" || {
    printf '[ERROR] Impossible de créer %s.\n' "$report_directory" >&2
    exit 1
}

printf 'Running Lynis audit...\n\n'
if ! lynis audit system --nocolors --quick >"$lynis_output" 2>&1; then
    printf '[ERROR] Lynis a échoué. Dernières lignes du journal:\n' >&2
    tail -n 20 "$lynis_output" >&2
    exit 1
fi

lynis_report=/var/log/lynis-report.dat
if [ ! -r "$lynis_report" ]; then
    printf '[ERROR] Lynis n’a pas produit de rapport exploitable.\n' >&2
    exit 1
fi

hardening_index=$(awk '
    tolower($0) ~ /hardening index/ {
        for (field = 1; field <= NF; field++) {
            if ($field ~ /^[0-9]+$/) {
                print $field
                exit
            }
        }
    }
' "$lynis_output")
tests_performed=$(awk '
    tolower($0) ~ /tests performed/ {
        for (field = 1; field <= NF; field++) {
            if ($field ~ /^[0-9]+$/) {
                print $field
                exit
            }
        }
    }
' "$lynis_output")
warning_count=$(awk -F= '$1 == "warning[]" { count++ }
    END { print count + 0 }' "$lynis_report")
suggestion_count=$(awk -F= '$1 == "suggestion[]" { count++ }
    END { print count + 0 }' "$lynis_report")

for metric_name in hardening_index tests_performed \
    warning_count suggestion_count; do
    if ! [[ ${!metric_name} =~ ^[0-9]+$ ]]; then
        printf '[ERROR] La métrique Lynis %s est absente ou invalide.\n' \
            "$metric_name" >&2
        exit 1
    fi
done

progress=$(awk -v score="$hardening_index" '
    BEGIN {
        bars = int((score * 20 / 100) + 0.5)
        for (i = 0; i < bars; i++) printf "#"
        for (; i < 20; i++) printf "."
    }
')

{
    printf 'Hardening Index: %s [%s]\n' "$hardening_index" "$progress"
    printf 'Tests Performed: %s\n' "$tests_performed"
    printf 'Warnings: %s\n' "$warning_count"
    printf 'Suggestions: %s\n\n' "$suggestion_count"
    printf 'Critical Findings:\n'
    awk -F= '
        /^warning\[\]=/ {
            finding = substr($0, index($0, "=") + 1)
            if (finding != "") {
                printf "  [WARNING] %s\n", finding
                found = 1
            }
        }
        END {
            if (!found) print "  None reported by Lynis."
        }
    ' "$lynis_report"
    printf '\nBaseline saved to: %s\n' "$report_file"
} > "$summary_file"

if ! install -o root -g root -m 0640 "$summary_file" "$report_file"; then
    printf '[ERROR] Impossible d’enregistrer le rapport %s.\n' \
        "$report_file" >&2
    exit 1
fi

cat "$summary_file"
