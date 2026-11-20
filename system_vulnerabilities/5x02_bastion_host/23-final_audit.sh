#!/bin/bash
# Compare l’audit Lynis final à la baseline enregistrée.

set -o pipefail

if [ "$(id -u)" -ne 0 ]; then
    printf '[ERROR] Exécute cet audit avec sudo dans la VM.\n' >&2
    exit 1
fi

for command_name in lynis awk find sort mktemp tail tee install date; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf '[ERROR] Commande requise introuvable: %s\n' \
            "$command_name" >&2
        exit 1
    fi
done

report_directory=/var/log/hardening
lynis_report=/var/log/lynis-report.dat
temporary_directory=$(mktemp -d) || {
    printf '[ERROR] Impossible de créer un dossier temporaire.\n' >&2
    exit 1
}
trap 'rm -rf -- "$temporary_directory"' EXIT

lynis_output=$temporary_directory/lynis-output.txt
baseline_file=$(find "$report_directory" -maxdepth 1 -type f \
    -name 'baseline-*.txt' -print 2>/dev/null | sort | tail -n 1)

if [ -z "$baseline_file" ] || [ ! -r "$baseline_file" ]; then
    printf '[ERROR] Baseline Lynis introuvable dans %s.\n' \
        "$report_directory" >&2
    printf 'Lance d’abord 0-lynis_baseline.sh dans la VM.\n' >&2
    exit 1
fi

if ! mkdir -p -- "$report_directory"; then
    printf '[ERROR] Impossible d’accéder à %s.\n' "$report_directory" >&2
    exit 1
fi

printf '=== Final Security Audit ===\n\n'
printf 'Running Lynis audit...\n\n'
if ! lynis audit system --nocolors --quick >"$lynis_output" 2>&1; then
    printf '[ERROR] Lynis a échoué. Dernières lignes du journal:\n' >&2
    tail -n 20 "$lynis_output" >&2
    exit 1
fi

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

baseline_score=$(awk -F': ' '/^Hardening Index:/ { print $2; exit }' \
    "$baseline_file" | awk '{ print $1 }')
baseline_warnings=$(awk -F': ' '/^Warnings:/ { print $2; exit }' \
    "$baseline_file" | awk '{ print $1 }')
baseline_suggestions=$(awk -F': ' '/^Suggestions:/ { print $2; exit }' \
    "$baseline_file" | awk '{ print $1 }')

for metric_name in baseline_score baseline_warnings baseline_suggestions; do
    if ! [[ ${!metric_name} =~ ^[0-9]+$ ]]; then
        printf '[ERROR] La métrique %s est absente ou invalide dans %s.\n' \
            "$metric_name" "$baseline_file" >&2
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
score_difference=$((hardening_index - baseline_score))
warning_difference=$((baseline_warnings - warning_count))
suggestion_difference=$((baseline_suggestions - suggestion_count))

format_change()
{
    local difference=$1
    local label=$2

    if [ "$difference" -gt 0 ]; then
        printf '+%s %s' "$difference" "$label"
    elif [ "$difference" -lt 0 ]; then
        printf '%s %s' "$difference" "$label"
    else
        printf 'no change'
    fi
}

{
    printf 'Results:\n'
    printf '  Hardening Index: %s [%s]\n' "$hardening_index" "$progress"
    printf '  Tests Performed: %s\n' "$tests_performed"
    printf '  Warnings: %s\n' "$warning_count"
    printf '  Suggestions: %s\n\n' "$suggestion_count"
    printf 'Comparison with baseline:\n'
    printf '  Hardening Index: %s -> %s (%s)\n' \
        "$baseline_score" "$hardening_index" \
        "$(format_change "$score_difference" points)"
    printf '  Warnings: %s -> %s (%s)\n' \
        "$baseline_warnings" "$warning_count" \
        "$(format_change "$warning_difference" resolved)"
    printf '  Suggestions: %s -> %s (%s)\n\n' \
        "$baseline_suggestions" "$suggestion_count" \
        "$(format_change "$suggestion_difference" resolved)"
    printf 'Remaining items:\n'
    awk -F= '
        /^warning\[\]=/ {
            finding = substr($0, index($0, "=") + 1)
            if (finding != "") {
                printf "  [WARNING] %s\n", finding
                found = 1
            }
        }
        /^suggestion\[\]=/ {
            finding = substr($0, index($0, "=") + 1)
            if (finding != "") {
                printf "  [SUGGESTION] %s\n", finding
                found = 1
            }
        }
        END {
            if (!found) print "  None reported by Lynis."
        }
    ' "$lynis_report"
    if [ "$score_difference" -gt 0 ] &&
        [ "$warning_difference" -gt 0 ]; then
        printf '\nSummary: System hardened significantly.\n'
    else
        printf '\nSummary: Review the remaining findings and remediation progress.\n'
    fi
    printf 'Ready for DMZ deployment pending CISO review.\n'
} | tee "$temporary_directory/final-summary.txt"

report_file="$report_directory/final-$(date '+%Y%m%d').txt"
if ! install -o root -g root -m 0640 \
    "$temporary_directory/final-summary.txt" "$report_file"; then
    printf '[ERROR] Impossible d’enregistrer le rapport %s.\n' \
        "$report_file" >&2
    exit 1
fi
printf '\nFinal report saved to: %s\n' "$report_file"
