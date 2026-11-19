#!/bin/bash
# Je vérifie les protections actives et leur configuration persistante.

set -o pipefail

if ! command -v sysctl >/dev/null 2>&1; then
    printf '[ERROR] La commande sysctl est introuvable.\n' >&2
    exit 1
fi

config_file=/etc/sysctl.d/99-hardening.conf
checks_passed=0
checks_total=0
checks_failed=0

check_parameter()
{
    local parameter=$1
    local expected=$2
    local actual

    checks_total=$((checks_total + 1))
    actual=$(sysctl -n "$parameter" 2>/dev/null) || actual=UNAVAILABLE
    if [ "$actual" = "$expected" ]; then
        printf '  [PASS] %s = %s\n' "$parameter" "$actual"
        checks_passed=$((checks_passed + 1))
    else
        printf '  [FAIL] %s = %s (expected %s)\n' \
            "$parameter" "$actual" "$expected"
        checks_failed=$((checks_failed + 1))
    fi
}

check_persisted_setting()
{
    local parameter=$1
    local expected=$2

    awk -v key="$parameter" -v wanted="$expected" '
        index($0, "=") {
            assignment = index($0, "=")
            name = substr($0, 1, assignment - 1)
            value = substr($0, assignment + 1)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", name)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
            if (name == key) last_value = value
        }
        END { if (last_value == wanted) exit 0; exit 1 }
    ' "$config_file"
}

printf '=== Kernel Hardening Verification ===\n\n'

printf 'IP Forwarding:\n'
check_parameter net.ipv4.ip_forward 0
check_parameter net.ipv6.conf.all.forwarding 0

printf '\nICMP Redirects:\n'
check_parameter net.ipv4.conf.all.accept_redirects 0
check_parameter net.ipv4.conf.default.accept_redirects 0
check_parameter net.ipv6.conf.all.accept_redirects 0
check_parameter net.ipv6.conf.default.accept_redirects 0
check_parameter net.ipv4.conf.all.send_redirects 0
check_parameter net.ipv4.conf.default.send_redirects 0

printf '\nReverse Path Filtering:\n'
check_parameter net.ipv4.conf.all.rp_filter 1
check_parameter net.ipv4.conf.default.rp_filter 1

printf '\nSYN Cookies:\n'
check_parameter net.ipv4.tcp_syncookies 1

printf '\nSource Routing:\n'
check_parameter net.ipv4.conf.all.accept_source_route 0
check_parameter net.ipv4.conf.default.accept_source_route 0
check_parameter net.ipv6.conf.all.accept_source_route 0
check_parameter net.ipv6.conf.default.accept_source_route 0

printf '\nICMP Configuration:\n'
check_parameter net.ipv4.icmp_echo_ignore_broadcasts 1
check_parameter net.ipv4.icmp_echo_ignore_all 0
check_parameter net.ipv4.icmp_ignore_bogus_error_responses 1

printf '\nPersistence Check:\n'
checks_total=$((checks_total + 1))
if [ -r "$config_file" ]; then
    persistence_ok=1
    while IFS='=' read -r parameter expected; do
        if ! check_persisted_setting "$parameter" "$expected"; then
            persistence_ok=0
            break
        fi
    done <<'EOF'
net.ipv4.ip_forward=0
net.ipv6.conf.all.forwarding=0
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv6.conf.all.accept_redirects=0
net.ipv6.conf.default.accept_redirects=0
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.default.send_redirects=0
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.default.rp_filter=1
net.ipv4.tcp_syncookies=1
net.ipv4.conf.all.accept_source_route=0
net.ipv4.conf.default.accept_source_route=0
net.ipv6.conf.all.accept_source_route=0
net.ipv6.conf.default.accept_source_route=0
net.ipv4.icmp_echo_ignore_broadcasts=1
net.ipv4.icmp_echo_ignore_all=0
net.ipv4.icmp_ignore_bogus_error_responses=1
EOF
else
    persistence_ok=0
fi

if [ "$persistence_ok" -eq 1 ]; then
    printf '  [PASS] %s exists and contains all required settings\n' \
        "$config_file"
    checks_passed=$((checks_passed + 1))
else
    printf '  [FAIL] %s is missing or has incomplete settings\n' \
        "$config_file"
    checks_failed=$((checks_failed + 1))
fi

printf '\nSummary: %s/%s checks passed\n' "$checks_passed" "$checks_total"
if [ "$checks_failed" -eq 0 ]; then
    printf 'Kernel hardening: COMPLETE\n'
    exit 0
fi

printf 'Kernel hardening: INCOMPLETE (%s checks failed)\n' "$checks_failed"
exit 1
