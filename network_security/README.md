# Network Security : Sommaire des modules

Ce dossier regroupe tous les modules de sécurité réseau du parcours Holberton. L'objectif : comprendre le réseau en profondeur, capturer et analyser du trafic, détecter des attaques, et sécuriser un périmètre avec pare-feu et VPN.

---

## Modules

### [2x00 : Network Fundamentals](2x00_network_fundamentals/README.md)

Les bases indispensables du réseau avant d'aborder la sécurité.

- Binaire et adressage IPv4 (32 bits, 4 octets)
- Sous-réseaux : CIDR, calcul d'adresse réseau (AND bit à bit), broadcast
- VLSM : allocation efficace des adresses
- Décisions de routage : local vs distant, table de routage
- ARP : résolution MAC locale, pourquoi il ne traverse pas les routeurs
- TTL : durée de vie d'un paquet, protection contre les boucles
- Modèle OSI pratique : couches 2 (MAC, ARP) et 3 (routage IP)

---

### [2x01 : Network Services](2x01_network_services/README.md)

Les protocoles fondamentaux qu'on retrouve sur tous les réseaux.

- DNS : résolution récursive vs itérative, hiérarchie (root → TLD → autoritaire)
- Types de records : A, AAAA, CNAME, MX, TXT, PTR, SOA, NS
- TTL et cache DNS
- Sécurité DNS : `/etc/hosts`, SPF, Zone Transfer (AXFR)
- DHCP : processus DORA (Discover, Offer, Request, Acknowledge)
- Rogue DHCP : attaque Man-in-the-Middle via faux serveur DHCP
- Outils : `dig`, `nslookup`, `/etc/resolv.conf`

---

### [2x02 : The Wiretap](2x02_the_wiretap/README.md)

Capturer et analyser du trafic réseau.

- `tcpdump` : capture sur interface, écriture pcap
- Filtres BPF : `host`, `port`, `tcp`, `icmp`, `src`, `dst`, combinaisons avec `and/or`
- Filtres d'affichage Wireshark vs filtres BPF : la différence
- Handshake TCP 3-way (SYN / SYN-ACK / ACK), flags, ISN
- `nmap` : ARP (`-PR`), ICMP Mask (`-PM`), Connect (`-sT`), SYN (`-sS`), UDP (`-sU`), version (`-sV`)
- Protocoles en clair : Telnet, FTP, HTTP vs HTTPS/TLS

---

### [2x03 : Traffic Forensics](2x03_traffic_forensics/README.md)

Analyser un incident à partir d'une capture réseau avec `tshark`.

- `tshark` : `-r`, `-Y`, `-T fields`, `-e`, `-q`, `-z io,phs`, `-z conv,tcp`
- Identifier les bavards, la hiérarchie des protocoles, les conversations TCP
- Détection de scan SYN (flags.syn == 1 && flags.ack == 0)
- Enumération web : codes 404, user-agents suspects
- Extraction de credentials HTTP (formulaires POST `urlencoded`)
- Injection SQL dans les URIs, encodage URL (%53%45%4c%45%43%54)
- RCE : `frame contains "/bin/sh"`, détection reverse shell (`uid=0`)
- Beaconing C2 : intervalles réguliers dans `frame.time_relative`
- Tunneling DNS : requêtes avec noms > 50 caractères
- Tunneling ICMP : paquets ICMP anormalement volumineux (> 100 octets)
- Carving de fichiers HTTP avec `--export-objects`

---

### [2x04 : Perimeter Control](2x04_perimeter_control/README.md)

Sécuriser le périmètre d'un serveur avec pare-feu et VPN.

- `ss -l -tup` : audit des ports en écoute
- `nftables` : tables (inet/ip), chains, hooks (input/forward/output/postrouting)
- Politiques drop vs accept, connection tracking (`ct state established,related`)
- Filtres : `iif`, `oif`, `tcp dport`, `udp dport`, `ip saddr`
- NAT masquerade pour router le trafic des clients VPN
- WireGuard : keypairs (`wg genkey/pubkey`), `wg0.conf`, `client.conf`, `AllowedIPs`
- `wg show wg0 latest-handshakes`
- IP forwarding : `sysctl -w net.ipv4.ip_forward=1`, persistance dans `/etc/sysctl.conf`
- Déploiement distant : `scp` + `ssh`, panic button avec `at`
