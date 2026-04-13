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
check_ports(){
    for port in $(ss -lntp | awk 'NR>1{split($4, a, ":"); print a[2]}'); do
        allowed=false
        for allowed_port in "${ALLOWED_PORTS[@]}"; do
            if [ "$port" = "$allowed_port" ]; then
                allowed=true
            fi
        done
        if [ "$allowed" = false ]; then
            ss -K dport = :$port
            echo "ALERT: Killed rogue process on port $port"
        fi
    done
}
check_services
check_integrity
check_ports
