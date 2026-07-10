#!/bin/bash
# je demande à tshark les statistiques de hiérarchie des protocoles
# tshark a un mode natif pour ça avec l'option -z
# le fichier pcap c'est $1
tshark -z io,phs $1