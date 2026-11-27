# Holberton School : Cybersécurité

Ce dépôt regroupe les travaux pratiques du parcours cybersécurité. Les modules couvrent l'administration Linux, les réseaux, les concepts de sécurité, Python appliqué à la cybersécurité et la conception défensive.

## Structure du dépôt

```text
holbertonschool-cybersecurity/
├── linux_security/          # Fondamentaux, identité et durcissement Linux
├── network_security/        # Réseaux, capture, périmètre et capstone
├── security_concepts/       # Contrôle d'accès, logs et défense
├── python_for_cyber/        # Python appliqué à la cybersécurité
├── system_vulnerabilities/  # Vulnérabilités, correctifs, identité et conteneurs
└── strategy_layer/          # Analyse métier et stratégie de sécurité
```

## Linux Security

- `1x00_linux_fundamentals` : bases Linux, shell, fichiers et permissions.
- `1x01_shell_ops` : opérations shell et automatisation.
- `1x02_identity_management` : utilisateurs, groupes et droits.
- `1x03_system_visibility` : visibilité et journalisation système.
- `1x04_security_automation` : automatisation des contrôles de sécurité.
- `1x05_hardening` : durcissement d'un système Linux.
- `1x06_vulnerability_analysis` : évaluation de vulnérabilités et analyse de risques.

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

## System Vulnerabilities

Les projets couvrent l'analyse de vulnérabilités, la gestion des correctifs,
le durcissement Linux, l'identité et la sécurisation des conteneurs.

- `0x00_vulnerability_ecosystem` : dossier d'analyse de vulnérabilités présent dans le dépôt.
- [`5x00_vulnerability_ecosystem`](system_vulnerabilities/5x00_vulnerability_ecosystem/README.md) : inventaire et analyse de vulnérabilités.
- [`5x01_lifecycle_defense`](system_vulnerabilities/5x01_lifecycle_defense/README.md) : correctifs et cycle de vie des paquets.
- [`5x02_bastion_host`](system_vulnerabilities/5x02_bastion_host/README.md) : durcissement d'un serveur Ubuntu.
- [`5x03_identity_fortress`](system_vulnerabilities/5x03_identity_fortress/README.md) : PAM, mots de passe, SSH et MFA.
- [`5x04_contained_chaos`](system_vulnerabilities/5x04_contained_chaos/README.md) : sécurité des images et conteneurs Docker.
- `5x05_hardened_shield` : capstone de durcissement Linux, identité, SSH,
  services et conteneurs.
  Il comprend un Compose avec limites runtime et l'audit automatisé.

## Python for Cybersecurity

### [`4x00_python_security`](python_for_cyber/4x00_python_security/README.md)

Ce module applique Python à des tâches de cybersécurité. Il commence par la préparation d'un environnement virtuel, la gestion des dépendances et les contrôles de style avec `pycodestyle`.

Le premier projet contient notamment :

- `breach_check.py` : script principal.
- `requirements.txt` : dépendances Python.
- `.gitignore` : fichiers exclus du versionnement.
- `venv/` : environnement virtuel local, non versionné.

Autres projets Python présents dans le dépôt:

- [`4x01_log_alchemist`](python_for_cyber/4x01_log_alchemist/README.md) : analyse et détection dans les journaux.
- [`4x02_network_probing`](python_for_cyber/4x02_network_probing/README.md) : sondage réseau local autorisé avec Python.
- [`4x03_IntelBroker`](python_for_cyber/4x03_IntelBroker/README.md) : enrichissement d'adresses IP avec des données de renseignement simulées.
- [`4x04_network_sniffer`](python_for_cyber/4x04_network_sniffer/README.md) : capture et analyse de paquets avec Scapy.

## Strategy Layer

[`strategy_layer`](strategy_layer/README.md) traite l'analyse des causes
profondes d'un incident et les décisions métier qui influencent la sécurité.

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
