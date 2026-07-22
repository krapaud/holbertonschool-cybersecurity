#!/bin/bash
curl -x http://$1:3128 -o /dev/null -k -s -w "%{http_code}" https://malware.com # Expected: Connection refused or Error
