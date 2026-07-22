#!/bin/bash
mkdir -p /etc/squid/ssl_cert && openssl req -newkey rsa:2048 -x509 -days 365 -nodes -keyout /etc/squid/ssl_cert/myCA.pem -out /etc/squid/ssl_cert/myCA.pem -subj "/CN=Squid CA" && /usr/lib/squid/ssl_crtd -c -s /var/lib/ssl_db
