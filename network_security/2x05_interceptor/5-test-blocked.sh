#!/bin/bash
curl -x http://$1:3128 -o /dev/null -s -w "%{http_code}" http://malware.com
