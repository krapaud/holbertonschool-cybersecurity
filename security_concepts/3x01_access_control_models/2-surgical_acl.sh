#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 FILE" >&2
    exit 1
fi

setfacl -m u:auditor_hipaa:r "$1"
