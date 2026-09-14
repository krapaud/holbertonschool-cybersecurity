#!/bin/bash
echo "/var/log/secure_remote.log {
    daily
    rotate 7
    compress
    missingok
}" | sudo tee /etc/logrotate.d/secure_remote > /dev/null
