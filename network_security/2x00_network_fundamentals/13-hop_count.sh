#!/bin/bash
traceroute $1 | tail -n 1 | awk '{print$1}'
