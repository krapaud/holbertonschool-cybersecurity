#!/bin/bash
tshark -z io,phs -r $1 -q