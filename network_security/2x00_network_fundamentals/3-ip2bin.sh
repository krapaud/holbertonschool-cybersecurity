#!/bin/bash
echo "$1" | awk -F'.' '{for (i=1; i<=4; i++) {"echo \"obase=2; " $i "\" | bc" | getline bin; if (i < 4) {printf "%08d.", bin} else {printf "%08d\n", bin}}}'
