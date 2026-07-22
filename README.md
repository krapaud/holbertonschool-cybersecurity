# Holberton School : Cybersécurité

Bienvenue dans le repo de cours cybersécurité de Holberton School. Ce dépôt regroupe tous les modules pratiques du parcours, organisés en deux grandes familles : la sécurité Linux et la sécurité réseau.

---

## Structure du repo

```text
holbertonschool-cybersecurity/
├── linux_security/
│   ├── 1x00_linux_fundamentals/     # Bases Linux : shell, fichiers, permissions
│   ├── 1x01_shell_ops/              # Opérations shell avancées
│   ├── 1x02_identity_management/    # Gestion des utilisateurs et droits
│   ├── 1x03_system_visibility/      # Surveillance et logs système
│   ├── 1x04_security_automation/    # Automatisation des tâches de sécurité
│   └── 1x05_hardening/              # Durcissement d'un système Linux
│
└── network_security/
    ├── 2x00_network_fundamentals/   # Bases réseau : IP, masques, routage, OSI
    ├── 2x01_network_services/       # DNS, DHCP, services réseau
    ├── 2x02_the_wiretap/            # Capture réseau, nmap, Wireshark
    ├── 2x03_traffic_forensics/      # Analyse forensique avec tshark
    └── 2x04_perimeter_control/      # Pare-feu nftables, WireGuard VPN
```

---

## Modules Network Security

### [2x00 : Fondamentaux Réseau](network_security/2x00_network_fundamentals/README.md)

Les bases indispensables avant de toucher à la sécurité réseau.

- Binaire et adressage IPv4
- Sous-réseaux, CIDR, VLSM
- Modèle OSI pratique (couches 2 et 3)
- Routage, ARP, TTL

---

### [2x01 : Services Réseau](network_security/2x01_network_services/README.md)

Les protocoles que tu rencontres tous les jours sur un réseau.

- DNS : résolution récursive/itérative, types de records, TTL, cache
- Sécurité DNS : /etc/hosts, SPF, Zone Transfer (AXFR)
- DHCP : processus DORA, rogue DHCP
- Outils : `dig`, `nslookup`

---

### [2x02 : The Wiretap](network_security/2x02_the_wiretap/README.md)

Capturer et analyser du trafic réseau.

- `tcpdump` et filtres BPF pour la capture
- Filtres d'affichage Wireshark
- Handshake TCP, flags, ISN
- `nmap` : scans SYN, Connect, UDP, ARP, ICMP Mask, détection de version
- Protocoles non sécurisés : Telnet, FTP, HTTP

---

### [2x03 : Traffic Forensics](network_security/2x03_traffic_forensics/README.md)

Analyser un incident à partir d'une capture réseau.

- `tshark` : options `-r`, `-Y`, `-T fields`, `-e`, `-q`, `-z`
- Hiérarchie des protocoles, identification des bavards, conversations TCP
- Détection : scan SYN, énumération 404, injection SQL, RCE, reverse shell
- Beaconing C2, tunneling DNS, tunneling ICMP
- Carving de fichiers HTTP

---

### [2x04 : Perimeter Control](network_security/2x04_perimeter_control/README.md)

Sécuriser le périmètre d'un serveur avec un pare-feu et un VPN.

- Audit des ports avec `ss`
- `nftables` : tables, chains, hooks, politiques, connection tracking, `ip saddr`
- NAT masquerade pour partager une connexion
- WireGuard VPN : keypairs, `wg0.conf`, `client.conf`, `AllowedIPs`
- IP forwarding avec `sysctl`
- Déploiement à distance avec SCP + SSH

---

## Auteur

**Mickael Krapaud** : Étudiant Holberton School
