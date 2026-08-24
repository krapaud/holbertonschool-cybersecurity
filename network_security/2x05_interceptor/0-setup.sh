#!/bin/bash
sudo apt-get install squid -y && systemctl enable squid && cp /etc/squid/squid.conf /etc/squid/squid.conf.bak
