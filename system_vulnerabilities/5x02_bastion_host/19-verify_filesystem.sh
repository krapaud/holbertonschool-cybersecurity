#!/bin/bash
# Je teste les protections réelles des trois espaces temporaires.

set -o pipefail
umask 077

if [ "$(id -u)" -ne 0 ]; then
    printf '[ERROR] Lance cette vérification avec sudo dans la VM.\n' >&2
    exit 1
fi

for command_name in chmod cp findmnt mktemp rm; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf '[ERROR] Commande requise introuvable: %s\n' \
            "$command_name" >&2
        exit 1
    fi
done

temporary_paths=()
cleanup()
{
    local temporary_path

    for temporary_path in "\${temporary_paths[@]}"; do
        rm -f -- "$temporary_path"
    done
}
trap cleanup EXIT

check_mount_options()
{
    local mount_path=$1
    local active_options
    local required_option

    active_options=$(findmnt --noheadings --target "$mount_path" \
        --output OPTIONS) || {
        printf '[FAIL] Impossible de lire les options de %s.\n' \
            "$mount_path" >&2
        return 1
    }

    for required_option in noexec nosuid nodev; do
        case ",$active_options," in
            *,"$required_option",*)
                ;;
            *)
                printf '[FAIL] %s manque l’option %s.\n' \
                    "$mount_path" "$required_option" >&2
                return 1
                ;;
        esac
    done
    printf '  %s: noexec,nosuid,nodev ✓\n' "$mount_path"
}

test_script_execution()
{
    local mount_path=$1
    local test_file
    local execution_status

    test_file=$mount_path/.filesystem-test-$$
    temporary_paths+=("$test_file")
    printf '#!/bin/sh\nexit 0\n' > "$test_file" || return 1
    chmod 0700 "$test_file" || return 1
    printf 'Done\n'

    if "$test_file" >/dev/null 2>&1; then
        printf '  Attempting execution... ALLOWED (unexpected)\n' >&2
        return 1
    else
        execution_status=$?
    fi

    if [ "$execution_status" -ne 126 ]; then
        printf '  Attempting execution... FAILED (status %s)\n' \
            "$execution_status" >&2
        return 1
    fi
    printf '  Attempting execution... BLOCKED ✓\n'
}

printf '=== Filesystem Hardening Verification ===\n\n'

printf 'Testing /tmp restrictions:\n'
printf '  Creating test script... '
test_script_execution /tmp || exit 1
printf '  Testing SUID... '
if check_mount_options /tmp >/dev/null; then
    printf 'IGNORED (nosuid active) ✓\n'
else
    exit 1
fi
printf '  Cleanup... Done\n'
rm -f -- "\${temporary_paths[0]}"
temporary_paths=()

printf '\nTesting /var/tmp restrictions:\n'
printf '  Creating test script... '
test_script_execution /var/tmp || exit 1
printf '  Cleanup... Done\n'
rm -f -- "\${temporary_paths[0]}"
temporary_paths=()

printf '\nTesting /dev/shm restrictions:\n'
printf '  Creating test binary... '
test_binary=/dev/shm/.filesystem-test-$$
temporary_paths+=("$test_binary")
true_binary=$(command -v true) || {
    printf '\n[ERROR] Binaire true introuvable.\n' >&2
    exit 1
}
cp "$true_binary" "$test_binary" || {
    printf '\n[ERROR] Copie du binaire de test impossible.\n' >&2
    exit 1
}
chmod 0700 "$test_binary" || {
    printf '\n[ERROR] Préparation du binaire de test impossible.\n' >&2
    exit 1
}
printf 'Done\n'
if "$test_binary" >/dev/null 2>&1; then
    printf '  Attempting execution... ALLOWED (unexpected)\n' >&2
    exit 1
else
    execution_status=$?
fi
if [ "$execution_status" -ne 126 ]; then
    printf '  Attempting execution... FAILED (status %s)\n' \
        "$execution_status" >&2
    exit 1
fi
printf '  Attempting execution... BLOCKED ✓\n'
printf '  Cleanup... Done\n'
rm -f -- "$test_binary"
temporary_paths=()

printf '\nMount options verified:\n'
check_mount_options /tmp || exit 1
check_mount_options /var/tmp || exit 1
check_mount_options /dev/shm || exit 1

printf '\nAll filesystem restrictions: ACTIVE\n'
