#!/bin/bash
ps -p $1 -o ppid= | tr -d ' '
