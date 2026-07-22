# The Wiretap : Cours pour débutants

---

## 1. Capturer du trafic réseau

### tcpdump : L'enregistreur de paquets

`tcpdump` est comme un magnétophone branché sur ton câble réseau. Il enregistre tout ce qui passe sur une interface réseau dans un fichier `.pcap` (Packet Capture).

```bash
sudo tcpdump -i eth0 -w capture.pcap

```text

- `-i eth0` : interface à écouter (`eth0`, `eth1`, `wlan0`...)

- `-w fichier.pcap` : écrire dans un fichier au lieu d'afficher

- `sudo` : obligatoire car lire le trafic réseau nécessite des droits root

**Pourquoi sudo ?** Écouter le réseau c'est comme brancher un micro dans une salle : c'est une action sensible. Le noyau Linux l'interdit aux utilisateurs normaux.

### Les filtres BPF (Berkeley Packet Filter)

Les filtres BPF permettent de capturer **seulement ce qui t'intéresse**. Imagine que tu enregistres un concert mais que tu ne veux que la voix du chanteur : le filtre BPF c'est ton égaliseur.

**Syntaxe de base :**

```text
host 192.168.1.10          # trafic vers/depuis cette IP
net 192.168.1.0/24         # tout un réseau
port 80                    # port 80 (HTTP)
port 22 or port 80         # plusieurs ports
tcp                        # seulement TCP
udp                        # seulement UDP
icmp                       # seulement ICMP
src host 10.0.0.1          # seulement depuis cette source
dst port 443               # seulement vers ce port destination

```text

**Combinaisons :**

```bash
# ICMP depuis/vers une IP ET trafic HTTP d'une autre IP
sudo tcpdump -i eth1 -w out.pcap '(icmp and host 10.42.0.1) or (tcp port 80 and host 10.42.0.2)'

```text

Les parenthèses fonctionnent comme en maths : elles groupent les conditions.

---

## 2. Analyser un fichier pcap avec Wireshark

### Filtres d'affichage Wireshark

Wireshark a ses propres filtres : différents des filtres BPF de tcpdump. Les filtres BPF servent à **capturer**, les filtres Wireshark servent à **afficher**.

C'est comme la différence entre choisir quels films enregistrer sur ta clé USB (BPF) et chercher parmi les films déjà enregistrés (Wireshark).

**Filtres par protocole :**

```text
http           # tout le trafic HTTP
dns            # requêtes DNS
telnet         # sessions Telnet
ftp            # commandes FTP
tcp            # tout TCP
icmp           # tout ICMP
ssh            # tout SSH

```text

**Filtres par IP :**

```text
ip.src == 10.10.10.1          # source = cette IP
ip.dst == 10.10.10.2          # destination = cette IP
ip.addr == 10.10.10.1         # source OU destination
ip.src != 10.10.10.105        # exclure cette IP source

```text

**Filtres par port :**

```text
tcp.port == 80                # port TCP 80 (source ou destination)
tcp.dport == 443              # port destination 443
tcp.sport == 12345            # port source

```text

**Filtres par flags TCP :**

```text
tcp.flags.syn == 1                                  # paquet SYN
tcp.flags.ack == 1                                  # paquet ACK
tcp.flags.syn == 1 and tcp.flags.ack == 0           # SYN sans ACK (début de connexion)

```text

**Combinaisons :**

```text
http && ip.src == 10.10.10.1           # HTTP depuis cette IP
telnet && ip.src != 10.10.10.105       # Telnet sans cette IP

```text

### Le handshake TCP en 3 étapes

Chaque connexion TCP commence par un "bonjour" en 3 temps. C'est comme une poignée de main formelle :

```text
Client                    Serveur
  |--- SYN --------------->|   "Je veux parler"
  |<-- SYN-ACK ------------|   "D'accord, moi aussi"
  |--- ACK --------------->|   "Parfait, c'est parti"
  |                         |
  |=== données ============>|

```text

- **SYN** : synchronize : demande de connexion

- **ACK** : acknowledge : confirmation de réception

- **FIN** : finish : demande de fermeture

**Pourquoi c'est important ?** Un scanner réseau envoie des SYN sans terminer la connexion. Filtrer `syn == 1 and ack == 0` permet de détecter ces scans.

### ISN : Initial Sequence Number

Quand une connexion TCP s'établit, chaque côté choisit un numéro de séquence de départ (ISN). C'est comme choisir un numéro de page pour commencer à écrire une lettre longue : les deux côtés se synchronisent pour savoir où en est la conversation.

```text
SYN → seq=1234567890           # ISN du client
SYN-ACK → seq=9876543210       # ISN du serveur

```text

---

## 3. Scans réseau avec nmap

`nmap` est l'outil de référence pour découvrir des machines et des services sur un réseau. Pense à lui comme un facteur qui sonne à toutes les portes pour voir qui répond.

### Découverte d'hôtes

**ARP Discovery (`-PR`) :**

```bash
nmap -sn -PR 192.168.1.0/24

```text

Utilise ARP (couche 2) pour détecter les machines actives. ARP ne traverse pas les routeurs : ça ne marche que sur le réseau local. Très fiable : les machines ne peuvent pas ignorer ARP.

**ICMP Mask Discovery (`-PM`) :**

```bash
sudo nmap -sn -PM 192.168.1.0/24

```text

Envoie des requêtes ICMP Address Mask (type 17). Certains systèmes y répondent, d'autres non.

### Scans de ports

**Connect Scan (`-sT`) :**

```bash
nmap -sT -p 22,80,443 192.168.1.1

```text

Établit une vraie connexion TCP complète (3-way handshake). Pas besoin de root. **Facile à détecter** par les logs serveur car la connexion est complète.

**SYN Scan (`-sS`) : le scan "furtif" :**

```bash
sudo nmap -sS -p 22,80,443 192.168.1.1

```text

Envoie un SYN, reçoit un SYN-ACK, puis envoie un RST (reset) au lieu de finaliser. La connexion n'est jamais complète : les anciens systèmes ne loggaient pas ça. Nécessite root (pour forger les paquets bruts).

| Réponse reçue | Signification |
| --- | --- |
| SYN-ACK | Port **ouvert** |
| RST | Port **fermé** |
| Pas de réponse / ICMP unreachable | Port **filtré** (pare-feu) |

**UDP Scan (`-sU`) :**

```bash
sudo nmap -sU -p 53,161 192.168.1.1

```text

UDP n'a pas de handshake. nmap envoie un paquet UDP :

- Si ICMP "port unreachable" → port **fermé**

- Si pas de réponse → port **ouvert ou filtré**

- Si réponse UDP → port **ouvert**

Beaucoup plus lent que TCP car il faut attendre les timeouts.

**Version Detection (`-sV`) :**

```bash
nmap -sV -p 80 192.168.1.1

```text

Essaie d'identifier le logiciel et sa version sur chaque port ouvert. nmap envoie des "sondes" et analyse les réponses pour deviner : Apache 2.4.41, OpenSSH 8.2, etc.

---

## 4. Protocoles non sécurisés

### Telnet : Le protocole nu

Telnet transmet tout en **clair** : commandes, réponses, et mots de passe inclus. C'est comme écrire un mot de passe sur une carte postale : n'importe qui entre toi et le destinataire peut le lire.

Dans Wireshark, filtrer `telnet` et suivre le flux TCP (`Follow > TCP Stream`) montre la session complète en clair.

### FTP : Transfert de fichiers sans chiffrement

FTP (port 21) transmet les credentials et les données en clair, tout comme Telnet. Il existe en deux modes :

- **Mode actif** : le serveur se connecte au client (problématique avec les NAT)

- **Mode passif** : le client se connecte au serveur (préféré aujourd'hui)

**SFTP/FTPS** sont les alternatives sécurisées (SSH ou TLS).

### HTTP vs HTTPS

- **HTTP** (port 80) : texte en clair : n'importe qui sur le réseau voit tes données

- **HTTPS** (port 443) : chiffré avec TLS : seul le serveur destination peut lire

Dans Wireshark, le trafic HTTPS apparaît comme `TLSv1.3` ou `TLSv1.2` : les données sont illisibles sans la clé privée du serveur. On peut quand même voir le **SNI** (Server Name Indication) dans le ClientHello, qui révèle le domaine visité.

---

## 5. Récap des commandes essentielles

```bash
# Capturer avec tcpdump
sudo tcpdump -i eth1 -w capture.pcap 'host 10.0.0.1'

# Lire un fichier pcap avec tshark
tshark -r fichier.pcap

# Scanner un réseau (découverte ARP)
nmap -sn -PR 192.168.1.0/24

# Scanner des ports (SYN scan)
sudo nmap -sS -p 22,80,443 192.168.1.1

# Détecter les versions
nmap -sV -p 80 192.168.1.1

```text
