#!/bin/bash
tshark -r "$1" --export-objects http,$(mktemp -d) ; md5sum /tmp/carve/*
