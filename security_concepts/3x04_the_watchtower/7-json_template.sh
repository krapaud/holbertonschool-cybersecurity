#!/bin/bash

# JSON format: {"time":"%timestamp%", "host":"%hostname%", "msg":"%msg%"}
echo 'template(name="json_fmt" type="string" string="{\"time\":\"%timestamp%\", \"host\":\"%hostname%\", \"msg\":\"%msg%\"}")' | sudo tee -a /etc/rsyslog.conf > /dev/null
