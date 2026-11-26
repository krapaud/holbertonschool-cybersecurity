#!/bin/bash
# Applique uniquement les réglages noyau que le conteneur est autorisé à modifier.
set -euo pipefail

printf '[hardening] Vérification des paramètres réseau du conteneur.\n'
if command -v sysctl >/dev/null 2>&1; then
    # Docker peut interdire sysctl dans son namespace. On journalise le refus,
    # le réglage équivalent doit alors être appliqué au niveau de l'hôte.
    sysctl -w net.ipv4.ip_forward=0 2>/dev/null || \
        printf '[hardening] ip_forward reste géré par la configuration Docker de l’hôte.\n'
    sysctl -w net.ipv4.conf.all.accept_redirects=0 2>/dev/null || \
        printf '[hardening] accept_redirects reste géré par l’hôte.\n'
fi

# Les options noexec, nosuid et nodev s'appliquent aux montages Docker, pas
# au système de fichiers partagé avec l'hôte depuis l'image.
printf '[hardening] Initialisation terminée; appliquer les options de montage avec Docker.\n'
