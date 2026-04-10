#!/bin/bash
ps -eo pid,state | grep $2=="Z" | awk '{print $1}'
