#!/bin/bash
ps -eo pid,stat | grep " Z" | awk '{print $1}'
