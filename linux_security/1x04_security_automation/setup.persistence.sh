#!/bin/bash
cp sentinel.service sentinel.timer /etc/systemd/system/
systemctl daemon-reload
systemctl enable sentinel.timer
systemctl start sentinel.timer
