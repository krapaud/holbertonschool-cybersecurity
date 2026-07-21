#!/bin/bash
tshark -r "$1" --export-objects http,/tmp/carve && md5sum /tmp/carve/*
