#!/bin/bash
nmap -p 22,23,80 -sT $1
