#!/bin/bash
dpkg -l | grep -q "libpam-pwquality" || apt-get install -y $1
if grep -qE "^#?pam_pwquality.so" $2; then
    sed -i -E 's/.*pam_pwquality.so.*/password requisite pam_pwquality.so retry=3 minlen=12 minclass=3/' $2
else
    echo "password requisite pam_pwquality.so retry=3 minlen=12 minclass=3" >> $2
fi
