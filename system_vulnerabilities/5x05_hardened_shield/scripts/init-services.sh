#!/bin/bash
# Lance les services nécessaires et garde le conteneur actif avec Nginx au PID 1.
set -euo pipefail

/opt/hardened-shield/scripts/init-hardening.sh
/opt/hardened-shield/scripts/init-identity.sh

install -d -o root -g root -m 0755 /var/www/html
cat > /var/www/html/index.html <<'EOF'
<!doctype html><html lang="en"><meta charset="utf-8"><title>Hardened Shield</title><body>Hardened Shield is running.</body></html>
EOF
cat > /var/www/html/health <<'EOF'
ok
EOF

service rsyslog start 2>/dev/null || true
service fail2ban start 2>/dev/null || true
service ssh start
exec nginx -g 'daemon off;'
