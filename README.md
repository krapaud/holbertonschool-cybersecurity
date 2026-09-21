# Holberton School : Cybersécurité

Ce dépôt regroupe les travaux pratiques du parcours cybersécurité. Les modules couvrent l'administration Linux, les réseaux, les concepts de sécurité, Python appliqué à la cybersécurité et la conception défensive.

## Structure du dépôt

```text
holbertonschool-cybersecurity/
├── linux_security/       # Fondamentaux et durcissement Linux
├── network_security/     # Réseaux, capture, périmètre et capstone
├── security_concepts/    # Concepts, contrôle d'accès, logs et défense
├── python_for_cyber/     # Python appliqué à la cybersécurité
└── strategy_layer/       # Analyse et stratégie de sécurité
```

## Linux Security

- `1x00_linux_fundamentals` : bases Linux, shell, fichiers et permissions.
- `1x01_shell_ops` : opérations shell et automatisation.
- `1x02_identity_management` : utilisateurs, groupes et droits.
- `1x03_system_visibility` : visibilité et journalisation système.
- `1x04_security_automation` : automatisation des contrôles de sécurité.
- `1x05_hardening` : durcissement d'un système Linux.

## Network Security

- `2x00_network_fundamentals` : IPv4, sous-réseaux, routage, ARP et TTL.
- `2x01_network_services` : DNS, DHCP et services réseau.
- `2x02_the_wiretap` : capture réseau, `tcpdump`, Wireshark et `nmap`.
- `2x03_traffic_forensics` : analyse forensique avec `tshark`.
- `2x04_perimeter_control` : `nftables`, NAT et WireGuard.
- `2x05_interceptor` : interception et contrôles réseau.
- `2x06_capstone` : audit, conception et implémentation du durcissement d'une passerelle réseau, avec VPN, pare-feu et validation.

## Security Concepts

- `3x00_security_core` : fondamentaux de sécurité et analyse de risques.
- `3x01_access_control_models` : DAC, ACL, RBAC, MAC et AppArmor.
- `3x03_defensive_controls` : politiques et contrôles défensifs.
- `3x04_the_watchtower` : collecte, analyse, corrélation et détection dans les logs.
- `3x05_incident_response` : premières étapes de réponse à incident.
- `3x06_defensive_architect` : architecture et automatisation des contrôles défensifs.

## Python for Cybersecurity

### [`4x00_python_security`](python_for_cyber/4x00_python_security/README.md)

Ce module applique Python à des tâches de cybersécurité. Il commence par la préparation d'un environnement virtuel, la gestion des dépendances et les contrôles de style avec `pycodestyle`.

Le premier projet contient notamment :

- `breach_check.py` : script principal.
- `requirements.txt` : dépendances Python.
- `.gitignore` : fichiers exclus du versionnement.
- `venv/` : environnement virtuel local, non versionné.

## Conventions générales

- Lire les consignes et les README avant de commencer une task.
- Utiliser un environnement virtuel pour les projets Python.
- Ne jamais versionner les environnements virtuels ni les caches générés.
- Vérifier la syntaxe et le style avant de valider un fichier.
- Documenter les choix techniques et les limites de test.
- Ne jamais exécuter une charge utile trouvée dans un fichier de logs.

## Vérifications utiles

```bash
git status
python3 -m py_compile chemin/vers/script.py
pycodestyle chemin/vers/script.py
```

Chaque module possède son propre README lorsque des consignes ou une méthode spécifique doivent être documentées.

## Auteur

**Mickael Krapaud**, étudiant Holberton School.
