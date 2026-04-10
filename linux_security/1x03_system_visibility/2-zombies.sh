#!/bin/bash
ps -eo pid,state | grep " Z" | awk '{print $1}'
