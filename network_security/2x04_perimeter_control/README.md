# Perimeter Control : Cours pour débutants

---

## 1. Auditer les ports ouverts

Avant de sécuriser un système, il faut savoir quels services écoutent. La commande `ss` (Socket Statistics) remplace le vieux `netstat`.

```bash
ss -l -tup

```text

- `-l` : listening : seulement les sockets en écoute

- `-t` : TCP

- `-u` : UDP

- `-p` : process : afficher quel programme écoute

**Analogie :** C'est comme faire le tour de ta maison pour vérifier quelles fenêtres et portes sont ouvertes avant de partir en vacances.

---

## 2. nftables : Le pare-feu Linux moderne

nftables est le système de filtrage réseau intégré au noyau Linux depuis 2014, successeur d'iptables. Il contrôle quel trafic entre, sort ou traverse ta machine.

**Analogie :** nftables c'est le vigile de ta boîte de nuit réseau. Il a une liste de règles : certains entrent, d'autres non, selon des critères précis.

### Structure : table → chain → rule

```text
table  (famille + nom)
  └── chain  (hook + type + policy)
        └── rule  (condition + action)

```text

- **Table** : conteneur principal. Définit la famille (`inet` = IPv4+IPv6, `ip` = IPv4 seulement)

- **Chain** : filtre attaché à un hook du noyau (input, output, forward, postrouting...)

- **Rule** : condition + action (`accept`, `drop`, `masquerade`...)

### Les hooks nftables

Un hook est un point d'interception dans le chemin d'un paquet dans le noyau :

```text
[Internet]
    |
    |---> input (paquets à destination de cette machine)
    |---> forward (paquets qui traversent vers un autre réseau)
    |
[Machine]
    |---> output (paquets générés par cette machine)
    |
    |---> postrouting (après décision de routage, avant envoi)

```text

### Politiques : accept vs drop

Chaque chain a une **policy** par défaut :

- `policy accept` : tout passer par défaut (et les règles peuvent bloquer)

- `policy drop` : tout bloquer par défaut (et les règles peuvent autoriser)

Pour la sécurité, on utilise `policy drop` sur `input` et `forward` : on n'autorise que ce qu'on veut explicitement.

### Connection Tracking (`ct state`)

`ct state` permet de distinguer les paquets selon l'état de la connexion :

```text
established  → appartient à une connexion déjà établie
related      → lié à une connexion (ex: FTP data channel)
new          → nouveau paquet initiant une connexion
invalid      → paquet qui ne correspond à aucune connexion connue

```text

Autoriser `established,related` permet aux réponses de revenir sans ouvrir tous les ports. C'est comme dire au vigile : "laisse entrer les réponses aux gens qui sont déjà sortis".

### Exemple de skeleton.conf commenté

```text
table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;
        ct state established,related accept   # laisser passer les réponses
        iif lo accept                         # loopback (127.0.0.1)
        tcp dport 22 accept                   # SSH
        udp dport 51820 accept                # WireGuard
        icmp accept                           # ping
    }

    chain forward {
        type filter hook forward priority 0; policy drop;
        iif wg0 accept                        # trafic venant du VPN
    }

    chain output {
        type filter hook output priority 0; policy accept;
    }
}

table ip nat {
    chain postrouting {
        type nat hook postrouting priority 100;
        masquerade                            # NAT pour les clients VPN
    }
}

```text

### Filtrer par interface : `iif` et `oif`

- `iif` : input interface : interface par laquelle le paquet **arrive**

- `oif` : output interface : interface par laquelle le paquet **repart**

```text
iif lo accept          # accepter le loopback
iif wg0 accept         # accepter tout ce qui vient de l'interface VPN

```text

### Filtrer par IP source : `ip saddr`

```text
ip saddr 10.200.0.2 tcp dport 22 accept    # SSH seulement depuis le VPN client

```text

Plusieurs conditions sur la même ligne sont toutes évaluées avant d'exécuter l'action. C'est un ET logique : tout doit être vrai.

### Commandes nftables utiles

```bash
nft list ruleset                   # afficher toutes les règles actives
nft flush ruleset                  # supprimer toutes les règles
nft -f /etc/nftables.conf          # charger une config depuis un fichier
systemctl enable nftables          # activer au démarrage

```text

---

## 3. WireGuard : VPN moderne

WireGuard est un protocole VPN intégré au noyau Linux depuis 5.6. Il est plus simple et plus rapide que OpenVPN ou IPsec.

**Analogie :** WireGuard crée un tunnel secret entre deux machines. Tout le trafic dedans est chiffré : comme un tuyau opaque entre deux pièces d'une maison.

### Le principe des clés asymétriques

WireGuard utilise une paire de clés pour chaque pair :

- **Clé privée** : ne quitte jamais la machine, ne se partage JAMAIS

- **Clé publique** : dérivée de la clé privée, se partage avec les pairs

C'est comme un cadenas (clé publique) et sa clé (clé privée). Tu peux donner ton cadenas à tout le monde : seul toi peux l'ouvrir.

```bash
wg genkey > private_key                    # générer une clé privée
wg pubkey < private_key > public_key       # dériver la clé publique

```text

### Structure d'une config WireGuard

**Serveur (`wg0.conf`) :**

```ini
[Interface]
Address = 10.200.0.1/24          # IP du serveur dans le tunnel
ListenPort = 51820               # port UDP d'écoute
PrivateKey = <clé_privée_serveur>

[Peer]
PublicKey = <clé_publique_client>
AllowedIPs = 10.200.0.2/32       # IP autorisée pour ce client

```text

**Client (`client.conf`) :**

```ini
[Interface]
Address = 10.200.0.2/24          # IP du client dans le tunnel
PrivateKey = <clé_privée_client>

[Peer]
PublicKey = <clé_publique_serveur>
Endpoint = <ip_publique_serveur>:51820
AllowedIPs = 10.200.0.0/24       # trafic à faire passer dans le tunnel

```text

### AllowedIPs : ce que ça signifie

`AllowedIPs` a deux fonctions selon qu'on est serveur ou client :

- **Côté serveur** : quelles IPs sont autorisées à s'identifier avec cette clé publique

- **Côté client** : quelles destinations sont routées dans le tunnel

`AllowedIPs = 0.0.0.0/0` envoie **tout** le trafic dans le tunnel (full VPN).

### Commandes WireGuard

```bash
wg show                            # état de toutes les interfaces WireGuard
wg show wg0                        # état de wg0 spécifiquement
wg show wg0 latest-handshakes      # dernier handshake avec chaque pair (timestamp Unix)
ip link add wg0 type wireguard     # créer l'interface
wg setconf wg0 /etc/wireguard/wg0.conf   # appliquer une config
ip link set wg0 up                 # activer l'interface

```text

Un handshake WireGuard se fait toutes les 3 minutes. Un timestamp de `0` signifie qu'aucune connexion n'a eu lieu.

---

## 4. IP Forwarding : Devenir un routeur

Par défaut, Linux ignore les paquets qui ne lui sont pas destinés. Pour qu'il les transmette (comme un routeur), il faut activer le **forwarding**.

```bash
sysctl -w net.ipv4.ip_forward=1                      # activer immédiatement
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf     # rendre persistant au reboot

```text

- `sysctl -w` : écrire une valeur dans le noyau (effet immédiat, perdu au reboot)

- `/etc/sysctl.conf` : fichier lu au démarrage pour appliquer des paramètres permanents

**Pourquoi le VPN en a besoin ?** Les clients VPN (10.200.0.x) veulent accéder à internet. Leurs paquets arrivent sur l'interface `wg0` et doivent être retransmis vers `eth0`. Sans forwarding, le serveur les jette.

---

## 5. NAT : Masquerade

Les clients VPN ont des IPs privées (10.200.0.x). Internet ne peut pas leur répondre directement car ces IPs ne sont pas routables publiquement.

**La solution : Masquerade (SNAT)**

Le serveur remplace l'IP source du client par sa propre IP publique avant d'envoyer le paquet sur internet. Quand la réponse arrive, il fait l'inverse. C'est invisible pour le client.

```text
Client VPN (10.200.0.2) → Serveur (10.200.0.1) → Internet
                          "de ma part" (IP publique)

```text

C'est exactement ce que fait ta box internet pour ton réseau local : tes appareils ont des IPs privées (192.168.x.x), mais internet ne voit que l'IP publique de ta box.

---

## 6. Déploiement à distance

Pour configurer le pare-feu d'un serveur distant, la combinaison SCP + SSH permet d'envoyer la config et de l'appliquer.

### La règle de sécurité du `panic button`

Avant d'appliquer une nouvelle config de pare-feu à distance, il faut prévoir un **retour arrière automatique**. Si tu te bloques toi-même par erreur, la session SSH sera coupée et tu perdras l'accès.

```bash
nft flush ruleset ; echo "restore_command" | at now + 5 minutes

```text

`at` : planifie une commande pour dans X minutes. Si la nouvelle config est bonne, tu annules. Sinon, la restauration se fait automatiquement.

---

## 7. Récap des commandes essentielles

```bash
# Auditer les ports
ss -l -tup

# Lister les règles nftables
nft list ruleset

# Charger une config nftables
nft -f /etc/nftables.conf

# Générer des clés WireGuard
wg genkey > private && wg pubkey < private > public

# Voir l'état WireGuard
wg show wg0

# Activer le forwarding IPv4
sysctl -w net.ipv4.ip_forward=1

# Déployer une config à distance
scp fichier.conf user@ip:/tmp/ && ssh user@ip "nft -f /tmp/fichier.conf"

```text
