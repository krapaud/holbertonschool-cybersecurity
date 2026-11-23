#!/bin/bash
# Je teste la politique avec pwscore sans changer de mot de passe système.

set -o pipefail

error()
{
    printf '[ERROR] %s\n' "$1" >&2
    exit 1
}

if ! command -v pwscore >/dev/null 2>&1; then
    error 'pwscore is not installed. Run 2-password_complexity.sh first.'
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

# Chaque cas contient le mot de passe, l'utilisateur, le résultat attendu
# et la raison pédagogique du test.
tests=(
    'password|test-user|reject|Dictionary word'
    'Password123|test-user|reject|Missing special character'
    'Ab1!|test-user|reject|Minimum length not met'
    'auditor2024|auditor|reject|Contains username'
    'Str0ng!P@ssw0rd#2024|test-user|accept|Meets all requirements'
)

printf '=== Password Complexity Testing ===\n\n'
printf 'Testing password policy enforcement...\n'
printf 'Using pwscore only; no account passwords will be changed.\n\n'
test_number=0
failed_tests=0

for test_case in "${tests[@]}"; do
    IFS='|' read -r candidate username expected_result reason <<< "$test_case"
    test_number=$((test_number + 1))

    case "$test_number" in
        1) test_description='common word' ;;
        2) test_description='no special character' ;;
        3) test_description='too short' ;;
        4) test_description='contains username' ;;
        5) test_description='valid password' ;;
    esac

    printf 'Test %s: "%s" (%s)\n' \
        "$test_number" "$candidate" "$test_description"
    if printf '%s\n' "$candidate" | LC_ALL=C pwscore "$username" \
        >/dev/null 2>&1; then
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

printf 'All complexity tests: PASSED\n'
printf 'Password policy is enforced correctly.\n'
