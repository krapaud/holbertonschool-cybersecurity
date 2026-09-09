#!/bin/bash

grep "sqlmap" "$1" |
awk -F'"' ' {
    split($1, infos, " ")
    ip = infos[1]

    split($2, requete, " ")
    methode = requete[1]

    chemin = $2
    sub(methode " ", "", chemin)
    sub(/ HTTP\/[^ ]+$/, "", chemin)

    printf "%s,%s,%s\n", ip, methode, chemin
}'
