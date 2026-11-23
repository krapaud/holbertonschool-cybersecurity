#!/bin/bash
# Je teste PAM avec un compte temporaire supprimé après les essais.

set -o pipefail

error()
{
    printf '[ERROR] %s\n' "$1" >&2
    exit 1
}

for command_name in awk grep id passwd script useradd userdel; do
    command -v "$command_name" >/dev/null 2>&1 || \
        error "Required command not found: $command_name"
done
if [ "$(id -u)" -ne 0 ]; then
    error 'Run this script with sudo to test PAM password changes.'
fi

config_file=/etc/security/pwquality.conf
pam_file=/etc/pam.d/common-password
if [ ! -r "$config_file" ] || [ ! -r "$pam_file" ]; then
    error 'Password quality configuration is missing or unreadable.'
fi
pam_rule='^[[:space:]]*password[[:space:]]+requisite'
pam_rule+='[[:space:]]+pam_pwquality[.]so'
if ! grep -Eq "$pam_rule" "$pam_file"; then
    error 'pam_pwquality.so is not enabled in common-password.'
fi

# Je vérifie les paramètres essentiels avant de lancer les exemples.
for setting in minlen=12 dcredit=-1 ucredit=-1 lcredit=-1 \
    ocredit=-1 usercheck=1 difok=3; do
    setting_name=${setting%%=*}
    setting_value=${setting#*=}
    if ! awk -v key="$setting_name" -v expected="$setting_value" \
        '$1 == key && $2 == "=" && $3 == expected { found = 1 }
        END { exit !found }' "$config_file"; then
        error "Required setting is missing or incorrect: $setting_name"
    fi
done

echo '=== Password Complexity Testing ==='
printf '\n'
printf 'Testing password policy enforcement...\n'
printf 'Using a temporary auditor account that will be removed.\n\n'

# Je refuse de toucher à un compte auditor qui existerait déjà.
if id auditor >/dev/null 2>&1; then
    error 'The auditor account already exists. No account was changed.'
fi
if ! useradd --no-create-home --shell /usr/sbin/nologin auditor; then
    error 'Could not create the temporary auditor account.'
fi
test_account_created=1
cleanup()
{
    if [ "$test_account_created" -eq 1 ] && \
        ! userdel auditor >/dev/null 2>&1; then
        printf '[ERROR] Could not remove the temporary auditor account.\n' >&2
    fi
}
trap cleanup EXIT

test_number=0
failed_tests=0

for test_pass in 'password' 'Password123' 'Ab1!' 'auditor2024' 'Str0ng!P@ssw0rd#2024'; do
    test_number=$((test_number + 1))

    case "$test_number" in
        1)
            expected_result=reject
            reason='Dictionary word'
            test_description='common word'
            ;;
        2)
            expected_result=reject
            reason='Missing special character'
            test_description='no special character'
            ;;
        3)
            expected_result=reject
            reason='Minimum length not met'
            test_description='too short'
            ;;
        4)
            expected_result=reject
            reason='Contains username'
            test_description='contains username'
            ;;
        5)
            expected_result=accept
            reason='Meets all requirements'
            test_description='valid password'
            ;;
    esac

    printf 'Test %s: "%s" (%s)\n' \
        "$test_number" "$test_pass" "$test_description"
    # Le compte de test est temporaire: echo '$test_pass' | passwd auditor
    if printf '%s\n%s\n' "$test_pass" "$test_pass" | \
        script -q -e -c 'passwd auditor' /dev/null >/dev/null 2>&1; then
        actual_result=accept
    else
        actual_result=reject
    fi

    if [ "$actual_result" = "$expected_result" ]; then
        if [ "$actual_result" = accept ]; then
            result_label=ACCEPTED
        else
            result_label=REJECTED
        fi
        printf '  Result: %s ✓\n' "$result_label"
    else
        if [ "$actual_result" = accept ]; then
            result_label=ACCEPTED
        else
            result_label=REJECTED
        fi
        printf '  Result: %s (expected %s)\n' \
            "$result_label" "$expected_result"
        failed_tests=$((failed_tests + 1))
    fi
    printf '  Reason: %s\n\n' "$reason"
done

if [ "$failed_tests" -gt 0 ]; then
    printf 'All complexity tests: FAILED (%s test(s) did not match)\n' \
        "$failed_tests"
    error 'Password policy did not produce the expected results.'
fi

if ! userdel auditor >/dev/null 2>&1; then
    error 'Could not remove the temporary auditor account.'
fi
test_account_created=0
trap - EXIT

printf 'All complexity tests: PASSED\n'
printf 'Password policy is enforced correctly.\n'
