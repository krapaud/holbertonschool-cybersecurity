# Traffic Forensics : Cours pour débutants

---

## 1. tshark : Le Wireshark en ligne de commande

`tshark` est la version terminal de Wireshark. Là où Wireshark a une interface graphique, tshark te permet d'automatiser l'analyse dans des scripts. Pense à lui comme un détective qui lit des boîtes noires d'avion depuis le terminal.

### Options fondamentales

```bash
tshark -r fichier.pcap                    # lire un fichier
tshark -r fichier.pcap -Y "http"          # filtrer l'affichage
tshark -r fichier.pcap -T fields -e ip.src  # extraire un champ précis
tshark -r fichier.pcap -q                 # mode silencieux (pour les stats)

```text

- `-r` : read : lire un fichier pcap

- `-Y` : filtre d'affichage (même syntaxe que Wireshark)

- `-T fields` : afficher seulement certains champs (toujours avec `-e`)

- `-e` : champ à extraire (ip.src, ip.dst, tcp.port, http.user_agent...)

- `-q` : quiet : supprimer l'affichage normal (utile avec `-z`)

**Important :** `-r` et `-q` sont des options séparées. Ne les fusionne jamais (`-rq` ne fonctionne pas : tshark interprète `q` comme faisant partie du nom de fichier).

### Statistiques avec `-z`

L'option `-z` génère des statistiques. Elle s'utilise toujours avec `-q`.

```bash
tshark -r fichier.pcap -q -z io,phs        # hiérarchie des protocoles
tshark -r fichier.pcap -q -z conv,tcp      # conversations TCP

```text

---

## 2. Analyser un incident réseau

### Étape 1 : La hiérarchie des protocoles

La première chose à faire sur un fichier pcap inconnu, c'est regarder quels protocoles sont présents et en quelle proportion. C'est comme ouvrir une valise inconnue et faire l'inventaire de ce qu'elle contient.

```bash
tshark -r fichier.pcap -q -z io,phs

```text

Sortie typique :

```text
===================================================================
Protocol Hierarchy Statistics
Filter:

eth                                      frames:5234 bytes:3421098
  ip                                     frames:5212 bytes:3419234
    tcp                                  frames:4890 bytes:3380123
      http                               frames:234 bytes:45321
      tls                                frames:4321 bytes:3234123
    udp                                  frames:322 bytes:39111
      dns                                frames:120 bytes:14320
    icmp                                 frames:100 bytes:9000
===================================================================

```text

Ça te dit d'un coup d'œil : beaucoup de TLS (normal), du HTTP (intéressant), du DNS, quelques ICMP.

### Étape 2 : Identifier les "bavards"

Qui parle le plus sur le réseau ? Un hôte qui génère un volume anormal de trafic est souvent impliqué dans l'incident.

```bash
tshark -r fichier.pcap -T fields -e ip.src | sort | uniq -c | sort -rn | awk '{print $2}'

```text

Décortiqué :

- `tshark ... -e ip.src` : extraire toutes les IP sources

- `sort` : trier (nécessaire pour `uniq`)

- `uniq -c` : compter les occurrences

- `sort -rn` : trier par nombre décroissant

- `awk '{print $2}'` : afficher seulement l'IP (sans le compteur)

### Étape 3 : Les conversations TCP

Une conversation TCP = un échange entre deux hôtes sur deux ports précis. Voir toutes les conversations donne une carte des communications.

```bash
tshark -r fichier.pcap -q -z conv,tcp

```text

---

## 3. Détecter les attaques

### Détection de scan SYN

Un scan de ports SYN envoie beaucoup de paquets SYN sans jamais compléter le handshake. Compter les SYN isolés (sans ACK) révèle un scan.

```bash
tshark -r fichier.pcap -Y "tcp.flags.syn == 1 and tcp.flags.ack == 0" -T fields -e frame.number | wc -l

```text

Un nombre élevé de SYN sans ACK = scan de ports en cours.

### Détection d'énumération (HTTP 404)

Un attaquant qui cherche des pages/fichiers cachés va générer beaucoup d'erreurs 404. C'est comme quelqu'un qui essaie toutes les portes d'un couloir.

```bash
tshark -r fichier.pcap -Y "http.response.code == 404" -T fields -e frame.number | wc -l

```text

### Identification des User-Agents

Les outils d'attaque (scanners, exploits) ont souvent des User-Agents reconnaissables. Un User-Agent inhabituel peut trahir l'outil utilisé.

```bash
tshark -r fichier.pcap -T fields -e http.user_agent | sort -u

```text

`sort -u` : trier et dédupliquer (afficher chaque user-agent une seule fois).

### Extraction de credentials HTTP

Les formulaires soumis en HTTP (POST) transmettent les credentials en clair dans le corps de la requête au format `urlencoded`.

```bash
tshark -r fichier.pcap -Y 'urlencoded-form.key == "password"' -T fields -e urlencoded-form.value

```text

Les champs courants : `password`, `pass`, `pwd`. Si le site utilise HTTPS, ces données sont chiffrées et illisibles dans le pcap.

### Détection d'injection SQL

Les injections SQL passent souvent par les paramètres d'URL. On peut les chercher en filtrant des mots-clés SQL dans les URIs HTTP.

```bash
tshark -r fichier.pcap -Y 'http.request.uri contains "SELECT" || http.request.uri contains "UNION"' -T fields -e http.request.uri

```text

Les attaquants encodent parfois les caractères (`SELECT` → `%53%45%4c%45%43%54`) pour contourner les filtres : il faut aussi tester les versions encodées.

### Détection RCE (Remote Code Execution)

Une RCE réussie laisse souvent des traces dans le trafic : tentatives d'exécution de shell, présence de `/bin/sh` dans les paquets.

```bash
tshark -r fichier.pcap -Y 'frame contains "/bin/sh"' -T fields -e frame.number

```text

`frame contains "..."` cherche la chaîne dans tout le contenu du paquet, pas seulement les headers.

### Détecter un reverse shell

Quand un attaquant obtient un shell, il l'ouvre vers son propre serveur (reverse shell). La commande `id` ou `whoami` retourne `uid=0(root)` si c'est root. Chercher cette signature :

```bash
tshark -r fichier.pcap -Y 'frame contains "uid=0" || frame contains "root"' -T fields -e tcp.dstport

```text

Le port destination indique vers où le shell est envoyé : c'est le port d'écoute de l'attaquant.

---

## 4. Techniques avancées

### Beaconing (balise C2)

Un malware "beacon" contacte régulièrement son serveur de commande (C2) à intervalle fixe : comme une montre qui sonne toutes les heures. Analyser les timestamps révèle ces intervalles réguliers.

```bash
tshark -r fichier.pcap -T fields -e frame.time_relative

```text

`frame.time_relative` donne le temps en secondes depuis le début de la capture.

### Tunneling DNS

Le tunneling DNS consiste à cacher des données dans des requêtes DNS. Un domaine normal fait 10-30 caractères ; un domaine utilisé pour du tunneling en fait souvent 50+, car il encode des données dans le nom de domaine.

```bash
tshark -r fichier.pcap -T fields -e dns.qry.name | awk 'length($0) > 50'

```text

`length($0) > 50` : awk ne garde que les lignes de plus de 50 caractères.

**Analogie :** C'est comme glisser un message secret dans l'adresse de retour d'une enveloppe. Les postiers (routeurs DNS) font transiter sans lire.

### Tunneling ICMP

ICMP (ping) normalement n'a que quelques octets de payload. Si les paquets ICMP sont volumineux (>100 octets), ils cachent probablement des données.

```bash
tshark -r fichier.pcap -Y 'icmp && frame.len > 100' -T fields -e ip.src

```text

### Carving de fichiers

"Carver" un fichier, c'est extraire les fichiers transférés d'une capture réseau. Si une image ou un document a été téléchargé en HTTP non chiffré, il est entier dans le pcap.

```bash
tshark -r fichier.pcap --export-objects http,/tmp/carve && md5sum /tmp/carve/*

```text

`--export-objects http,dossier` : extraire tous les objets HTTP dans ce dossier.

### Timeline : Reconstituer la chronologie

Reconstituer la chronologie d'un incident permet de comprendre la séquence des événements.

```bash
tshark -r fichier.pcap -T fields -e frame.time

```text

`frame.time` : horodatage absolu de chaque paquet.

---

## 5. Champs tshark utiles

| Champ | Description |
| --- | --- |
| `frame.number` | Numéro du paquet |
| `frame.time` | Horodatage absolu |
| `frame.time_relative` | Temps depuis le début de la capture |
| `frame.len` | Taille du paquet en octets |
| `ip.src` | IP source |
| `ip.dst` | IP destination |
| `tcp.srcport` | Port TCP source |
| `tcp.dstport` | Port TCP destination |
| `http.request.uri` | URI de la requête HTTP |
| `http.user_agent` | User-Agent HTTP |
| `http.response.code` | Code de réponse HTTP |
| `urlencoded-form.key` | Clé d'un formulaire POST |
| `urlencoded-form.value` | Valeur d'un formulaire POST |
| `dns.qry.name` | Nom demandé dans une requête DNS |

---

## 6. Récap des commandes essentielles

```bash
# Hiérarchie des protocoles
tshark -r fichier.pcap -q -z io,phs

# Top des IP sources
tshark -r fichier.pcap -T fields -e ip.src | sort | uniq -c | sort -rn

# Conversations TCP
tshark -r fichier.pcap -q -z conv,tcp

# Compter les SYN scans
tshark -r fichier.pcap -Y "tcp.flags.syn == 1 and tcp.flags.ack == 0" -T fields -e frame.number | wc -l

# Credentials HTTP
tshark -r fichier.pcap -Y 'urlencoded-form.key == "password"' -T fields -e urlencoded-form.value

# DNS tunneling
tshark -r fichier.pcap -T fields -e dns.qry.name | awk 'length($0) > 50'

# Carving HTTP
tshark -r fichier.pcap --export-objects http,/tmp/carve

```text
