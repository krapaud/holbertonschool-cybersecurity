#!/bin/bash
echo "authpriv.info    /var/log/secure_remote.log" | sudo tee /etc/rsyslog.d/60-auth.conf > /dev/null
sudo systemctl restart rsyslog
