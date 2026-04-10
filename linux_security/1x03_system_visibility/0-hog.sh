#!/bin/bash
ps -A -o pid,comm --sort=-%cpu | head -n 2 | tail -n 1
