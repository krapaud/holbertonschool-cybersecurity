#!/bin/bash
# Lance les réglages puis les services du conteneur.
set -euo pipefail

# Je lance d'abord les deux scripts de préparation.
/opt/hardened-shield/scripts/init-hardening.sh
/opt/hardened-shield/scripts/init-identity.sh

# Je prépare une page simple et le chemin utilisé par le HEALTHCHECK.
install -d -o root -g root -m 0755 /var/www/html
cat > /var/www/html/index.html <<'EOF'
<!doctype html>
<html lang="en">
<meta charset="utf-8">
<title>Hardened Shield</title>
<body>Hardened Shield is running.</body>
</html>
EOF
cat > /var/www/html/health <<'EOF'
ok
EOF

# Ces deux services peuvent ne pas démarrer dans un conteneur sans systemd.
service rsyslog start 2>/dev/null || true
service fail2ban start 2>/dev/null || true
service ssh start

# Nginx reste au premier plan pour que Docker surveille le conteneur.
exec nginx -g 'daemon off;'
