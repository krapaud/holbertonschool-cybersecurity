#!/bin/bash
# Je retire les compilateurs ou limite leur exécution à root si nécessaire.

set -o pipefail

if [ "$(id -u)" -ne 0 ]; then
    printf '[ERROR] %s %s.\n' \
        'Exécute ce script avec sudo' 'dans la VM de laboratoire' >&2
    exit 1
fi

for command_name in apt-get dpkg-query chmod readlink mktemp stat; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf '[ERROR] Commande requise introuvable: %s\n' \
            "$command_name" >&2
        exit 1
    fi
done

temporary_directory=$(mktemp -d) || {
    printf '[ERROR] Impossible de créer un dossier temporaire.\n' >&2
    exit 1
}
trap 'rm -rf -- "$temporary_directory"' EXIT

target_packages=(gcc g++ make)
installed_packages=()
removal_is_safe=0
restriction_succeeded=0
for package_name in "${target_packages[@]}"; do
    package_status=$(dpkg-query -W -f='${db:Status-Status}' \
        "$package_name" 2>/dev/null) || package_status=missing
    if [ "$package_status" = installed ]; then
        installed_packages+=("$package_name")
    fi
done

printf '=== Development Tools Removal ===\n\n'
printf 'Checking dependencies before removal...\n'

if [ "${#installed_packages[@]}" -eq 0 ]; then
    printf '  gcc: Not installed\n'
    printf '  g++: Not installed\n'
    printf '  make: Not installed\n'
else
    if ! apt-get -s remove --no-auto-remove "${installed_packages[@]}" \
        > "$temporary_directory/removal-plan" 2>&1; then
        printf '[ERROR] Simulation APT échouée.\n' >&2
        cat "$temporary_directory/removal-plan" >&2
        exit 1
    fi

    planned_removals=$(awk '$1 == "Remv" { print $2 }' \
        "$temporary_directory/removal-plan")
    removal_is_safe=1
    for planned_package in $planned_removals; do
        package_is_target=0
        for package_name in "${installed_packages[@]}"; do
            if [ "$planned_package" = "$package_name" ]; then
                package_is_target=1
                break
            fi
        done
        if [ "$package_is_target" -eq 0 ]; then
            removal_is_safe=0
        fi
    done

    if [ "$removal_is_safe" -eq 1 ]; then
        for package_name in "${target_packages[@]}"; do
            package_status=$(dpkg-query -W -f='${db:Status-Status}' \
                "$package_name" 2>/dev/null) || package_status=missing
            if [ "$package_status" = installed ]; then
                printf '  %s: Can be safely removed\n' "$package_name"
            else
                printf '  %s: Not installed\n' "$package_name"
            fi
        done
        printf '\nRemoving packages...\n'
        if ! DEBIAN_FRONTEND=noninteractive apt-get remove -y \
            --no-auto-remove "${installed_packages[@]}"; then
            printf '[ERROR] Suppression des paquets échouée.\n' >&2
            exit 1
        fi
        for package_name in "${installed_packages[@]}"; do
            package_status=$(dpkg-query -W -f='${db:Status-Status}' \
                "$package_name" 2>/dev/null) || package_status=missing
            if [ "$package_status" = installed ]; then
                printf '  %s: Still installed\n' "$package_name"
            else
                printf '  %s: Removed\n' "$package_name"
            fi
        done
        printf '\nCleanup...\n'
        printf '  Orphaned dependencies left for administrator review.\n'
    else
        printf '  Dependencies require additional packages; removal skipped.\n'
        printf '  Compilers will be restricted to root only.\n'
        restriction_succeeded=1
    fi
fi

compiler_paths=()
for compiler_command in gcc g++ make; do
    compiler_path=$(command -v "$compiler_command" 2>/dev/null) || continue
    resolved_path=$(readlink -f -- "$compiler_path" 2>/dev/null) || continue
    [ -f "$resolved_path" ] || continue
    path_is_listed=0
    for existing_path in "${compiler_paths[@]}"; do
        if [ "$existing_path" = "$resolved_path" ]; then
            path_is_listed=1
            break
        fi
    done
    if [ "$path_is_listed" -eq 0 ]; then
        compiler_paths+=("$resolved_path")
    fi
done

if [ "$removal_is_safe" -eq 0 ]; then
    restriction_succeeded=1
    restriction_failed=0
    if [ "${#compiler_paths[@]}" -eq 0 ]; then
        restriction_failed=1
    fi
    for compiler_path in "${compiler_paths[@]}"; do
        if ! chmod 0700 "$compiler_path"; then
            printf '[ERROR] Restriction impossible: %s\n' \
                "$compiler_path" >&2
            restriction_failed=1
        else
            permissions=$(stat -c '%a' "$compiler_path" 2>/dev/null) ||
                permissions=unknown
            if [ "$permissions" != 700 ]; then
                restriction_failed=1
            fi
        fi
        printf '  Restricted to root: %s\n' "$compiler_path"
    done
    if [ "$restriction_failed" -ne 0 ]; then
        restriction_succeeded=0
    fi
fi

printf '\nVerification:\n'
verification_failed=0
for package_name in "${target_packages[@]}"; do
    package_status=$(dpkg-query -W -f='${db:Status-Status}' \
        "$package_name" 2>/dev/null) || package_status=missing
    if [ "$package_status" = installed ]; then
        if [ "$restriction_succeeded" -eq 1 ]; then
            printf '  %s: Restricted to root only\n' "$package_name"
        else
            printf '  %s: Still installed or not restricted\n' \
                "$package_name"
            verification_failed=1
        fi
    else
        printf '  %s: Not found\n' "$package_name"
    fi
done

if [ "$verification_failed" -eq 0 ]; then
    printf '\nDevelopment tools removed or access restricted successfully.\n'
else
    printf '\n[ERROR] Some development tools still need attention.\n' >&2
    exit 1
fi
