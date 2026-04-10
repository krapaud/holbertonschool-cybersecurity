#!/bin/bash
ps -eo pid,comm --sort=-%cpu | head -n 2 | tail -n 1
