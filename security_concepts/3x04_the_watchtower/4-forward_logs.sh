#!/bin/bash
echo "*.* @127.0.0.1:514" | sudo tee -a /etc/rsyslog.d/50-default.conf
sudo systemctl restart rsyslog
logger "Test Log Forwarding"
