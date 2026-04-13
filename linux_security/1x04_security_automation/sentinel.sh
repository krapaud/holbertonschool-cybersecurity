#!/bin/bash
if [ ! -f sentinel.conf ]; then
    exit 1
else
    source sentinel.conf
fi
if [ -z "$SERVICES" ]; then
    exit 1
fi
if [ -z "$FILES_TO_WATCH" ]; then
    exit 1
fi
check_services() {
    for service in "${SERVICES[@]}"; do
    if pgrep -f "$service"; then
        echo "OK: $service is running"
    else
        start_cmd="START_${service}"
        eval "${!start_cmd}"
        echo "FIXED: Restarted $service"
    fi
    done
}
check_integrity() {
    for file in "${FILES_TO_WATCH[@]}"; do
        hash_file=$(md5sum "$file" | awk '{print $1}')
        gold="/var/backups/sentinel/$(basename "$file").gold"
        hash_gold=$(md5sum "$gold" | awk '{print $1}')
        if [ $hash_file = $hash_gold ]; then
            echo "OK: $file integrity verified"
        else
            cp "$gold" "$file"
            echo "FIXED: Restored $file"
        fi
    done
}
check_services
