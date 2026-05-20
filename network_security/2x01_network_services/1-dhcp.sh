#!/bin/bash
nmcli -f DHCP4 con show eth0 | grep "DHCP4.OPTION[3]" | awk '{print $4}'
