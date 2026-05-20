#!/bin/bash
nmcli -f DHCP4 con show eth0 | grep "DHCP4.OPTION.dhcp_server_identifier" | awk '{print $4}'
