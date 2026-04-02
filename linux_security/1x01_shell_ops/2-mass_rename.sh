#!/bin/bash
find $1 -name "*.log" | xargs -I{} mv {} {}.old
