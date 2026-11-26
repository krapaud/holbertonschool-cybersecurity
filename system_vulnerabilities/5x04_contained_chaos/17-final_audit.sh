#!/bin/bash

# Je lance Docker Bench et résume les résultats réellement retournés.
set -euo pipefail

error()
{
    printf '[ERROR] %s\n' "$1" >&2
    exit 1
}

for command_name in awk cat cp docker grep; do
    command -v "$command_name" >/dev/null 2>&1 || \
        error "Required command not found: $command_name"
done

script_directory=$(cd -- "$(dirname -- "$0")" && pwd) || \
    error 'Could not find the exercise directory.'
baseline_image=devstream-vulnerable:latest
secure_image=secure-python-dev:v1
report_file=$script_directory/17-final-audit-report.txt
raw_report=$script_directory/.17-final-audit-raw.txt
trap 'rm -f -- "$raw_report"' EXIT

docker info >/dev/null 2>&1 || \
    error 'Docker daemon is unavailable. Start Docker and retry.'
for image_name in "$baseline_image" "$secure_image"; do
    docker image inspect "$image_name" >/dev/null 2>&1 || \
        error "Required image is missing: $image_name. Build it before auditing."
done

printf '=== Final Container Security Audit ===\n\n'
printf 'Vulnerable Image: %s\n' "$baseline_image"
printf 'Secure Image: %s\n\n' "$secure_image"
printf 'Running docker-bench-security...\n'
printf 'Docker Bench examines the host and local image/container inventory.\n'

# Le benchmark requiert l'accès au daemon pour inspecter l'hôte et les images.
if ! docker run --rm \
    --net host \
    --pid host \
    --userns host \
    --cap-add audit_control \
    -v /etc:/etc:ro \
    -v /usr/bin/containerd:/usr/bin/containerd:ro \
    -v /usr/bin/runc:/usr/bin/runc:ro \
    -v /usr/lib/systemd:/usr/lib/systemd:ro \
    -v /var/lib:/var/lib:ro \
    -v /var/run/docker.sock:/var/run/docker.sock:ro \
    docker/docker-bench-security > "$raw_report" 2>&1; then
    cat "$raw_report" >&2
    error 'Docker Bench failed. Review its output above.'
fi

cp "$raw_report" "$report_file" || \
    error "Could not save the report to $report_file."

# Je compte les résultats observés dans la sortie Docker Bench.
pass_count=$(grep -Eic '\[PASS\]|\[INFO\].*PASS' "$raw_report" || true)
warn_count=$(grep -Eic '\[WARN\]' "$raw_report" || true)
info_count=$(grep -Eic '\[INFO\]' "$raw_report" || true)
note_count=$(grep -Eic '\[NOTE\]' "$raw_report" || true)
scored_checks=$((pass_count + warn_count))
if [ "$scored_checks" -gt 0 ]; then
    score=$((pass_count * 100 / scored_checks))
else
    error 'Docker Bench output contained no PASS or WARN checks.'
fi

baseline_report=$script_directory/docker-bench-report.txt
baseline_available=0
if [ -r "$baseline_report" ]; then
    baseline_pass=$(grep -Eic '\[PASS\]|\[INFO\].*PASS' "$baseline_report" || true)
    baseline_warn=$(grep -Eic '\[WARN\]' "$baseline_report" || true)
    baseline_scored=$((baseline_pass + baseline_warn))
    if [ "$baseline_scored" -gt 0 ]; then
        baseline_available=1
        baseline_score=$((baseline_pass * 100 / baseline_scored))
    fi
fi

printf '\nDocker Bench results (host and local inventory):\n'
printf '  PASS: %s\n' "$pass_count"
printf '  WARN: %s\n' "$warn_count"
printf '  INFO: %s\n' "$info_count"
printf '  NOTE: %s\n' "$note_count"
printf '  Score: %s%%\n' "$score"
printf '\nReport saved to: %s\n' "$report_file"
printf '\nImage comparison:\n'
if [ "$baseline_available" -eq 1 ]; then
    printf '  Vulnerable baseline (%s): %s%% (%s PASS, %s WARN)\n' \
        "$baseline_image" "$baseline_score" "$baseline_pass" "$baseline_warn"
    printf '  Current inventory (%s): %s%% (%s PASS, %s WARN)\n' \
        "$secure_image" "$score" "$pass_count" "$warn_count"
    improvement=$((score - baseline_score))
    printf '  Change: %+d percentage points\n' "$improvement"
else
    printf '  No baseline report found at %s.\n' "$baseline_report"
    printf '  Run 3-docker_bench.sh against the vulnerable image first.\n'
fi
printf '  Note: Docker Bench audits the host and local inventory, not one image\n'
printf '  in isolation. For strict attribution, compare runs on isolated hosts.\n'

if [ "$score" -ge 85 ]; then
    printf '\nContainer Security: STRONG (review remaining warnings before deployment)\n'
else
    printf '\nContainer Security: IMPROVEMENTS REQUIRED\n'
fi
