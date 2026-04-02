#!/bin/bash
find $1 -name "*.log" -maxdepth 1 | xargs -I{} mv {} {}.old
