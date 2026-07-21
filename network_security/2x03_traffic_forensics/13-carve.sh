#!/bin/bash
TMPDIR=$(mktemp -d)
tshark -r "$1" --export-objects http,$TMPDIR
md5sum $TMPDIR/*
