#!/bin/bash
{
    echo "<html>"
    echo "<head><title>Security Report</title></head>"
    echo "<body>"
    echo "<h1>Security Report</h1>"
    echo "<table>"
    echo "<tr><th>Attempts</th><th>IP Address</th></tr>"

    awk '/Failed password/ {
        for (field = 1; field <= NF; field++)
            if ($field == "from")
                print $(field + 1)
    }' "$1" | sort | uniq -c | sort -nr | head -5 |
    while read -r count ip
    do
        echo "<tr><td>$count</td><td>$ip</td></tr>"
    done

    echo "</table>"
    echo "</body>"
    echo "</html>"
} > "$2"
