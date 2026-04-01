#!/bin/bash
chown root:$2 $1
chmod 2750 $1
cat > /etc/logrotate.d/app << 'EOF'
/var/log/app/*.log {
    create 0640 root www-data
}
EOF
