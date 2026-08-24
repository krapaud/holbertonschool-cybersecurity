# Fondamentaux Réseau : Cours pour débutants

---

## 1. Binaire & Adressage

### Convertir décimal ↔ binaire

Un ordinateur ne comprend que deux états : **0** et **1**. Le binaire est un système de numération en base 2.

**Décimal → Binaire** : divise le nombre par 2 en gardant les restes.

```text
42 ÷ 2 = 21 reste 0
21 ÷ 2 = 10 reste 1
10 ÷ 2 =  5 reste 0
 5 ÷ 2 =  2 reste 1
 2 ÷ 2 =  1 reste 0
 1 ÷ 2 =  0 reste 1

42 en binaire = 101010 (on lit les restes de bas en haut)

```text

**Binaire → Décimal** : chaque bit a une valeur qui double (1, 2, 4, 8, 16, 32, 64, 128).

```text
10101010 = 128 + 0 + 32 + 0 + 8 + 0 + 2 + 0 = 170

```text

### Pourquoi une IP fait 32 bits ?

Une adresse IPv4 est composée de **32 bits** regroupés en **4 octets** (4 × 8 bits), séparés par des points :

```text
192       .168      .1        .10
11000000  10101000  00000001  00001010

```text

Chaque octet peut valoir de 0 (00000000) à 255 (11111111). Cela donne environ **4 milliards d'adresses** possibles (2³²).

### Les masques de sous-réseau au niveau des bits

Un masque de sous-réseau indique quelle partie de l'IP désigne le **réseau** et quelle partie désigne l'**hôte**.

```text
IP     : 192.168.1.10   →  11000000.10101000.00000001.00001010
Masque : 255.255.255.0  →  11111111.11111111.11111111.00000000
                                                        ↑
                              Les 1 = partie réseau     Les 0 = partie hôte

```text

### CIDR et masque pointé

La notation **CIDR** (ex: `/24`) est un raccourci qui indique combien de bits sont à **1** dans le masque.

```text
/24  →  255.255.255.0    (24 bits à 1)
/16  →  255.255.0.0      (16 bits à 1)
/8   →  255.0.0.0        (8 bits à 1)
/23  →  255.255.254.0    (23 bits à 1)

```text

---

## 2. Sous-réseaux (Subnetting)

### Calculer l'adresse réseau (Network ID)

L'adresse réseau s'obtient en faisant un **AND bit à bit** entre l'IP et le masque :

```text
IP     : 192.168.1.10  →  11000000.10101000.00000001.00001010
Masque : 255.255.255.0 →  11111111.11111111.11111111.00000000
AND    :                   11000000.10101000.00000001.00000000
                         = 192.168.1.0  ← adresse réseau

```text

Règle : là où le masque a un **1**, on garde le bit de l'IP. Là où il a un **0**, on met **0**.

### Calculer l'adresse de broadcast

L'adresse de broadcast s'obtient en mettant tous les bits hôte à **1** :

```text
Réseau : 192.168.1.0   →  11000000.10101000.00000001.00000000
Masque : 255.255.255.0 →  11111111.11111111.11111111.00000000
                          bits hôte = les 8 derniers → tous à 1
Broadcast :               11000000.10101000.00000001.11111111
                        = 192.168.1.255

```text

### Plage d'hôtes utilisables

Les adresses utilisables sont toutes celles **entre** l'adresse réseau et le broadcast :

```text
Réseau   : 192.168.1.0    ← réservé
Premier  : 192.168.1.1    ← premier hôte
...
Dernier  : 192.168.1.254  ← dernier hôte
Broadcast: 192.168.1.255  ← réservé

```text

Nombre d'hôtes = 2^(bits hôtes) - 2  →  /24 = 2^8 - 2 = **254 hôtes**

### VLSM : Allocation efficace des adresses

Le **VLSM** (Variable Length Subnet Masking) permet de découper un réseau en sous-réseaux de tailles différentes selon les besoins.

Exemple : tu as le réseau `192.168.1.0/24` et tu as besoin de :

- 1 réseau de 100 hôtes → `/25` (126 hôtes max)

- 1 réseau de 50 hôtes  → `/26` (62 hôtes max)

- 1 réseau de 20 hôtes  → `/27` (30 hôtes max)

Au lieu de gaspiller en donnant un `/24` à chacun, on découpe précisément. C'est comme couper une baguette en morceaux adaptés plutôt qu'en tranches égales.

---

## 3. Décisions de routage

### Local ou Remote ?

Quand ta machine veut envoyer un paquet, elle se pose une question : **la destination est-elle sur mon réseau local ?**

Elle fait le calcul :

```text
IP destination AND mon masque = mon adresse réseau ?

```text

- **OUI** → la destination est **locale** (même réseau)

- **NON** → la destination est **distante** (passe par le gateway)

### Pourquoi ARP n'est utilisé que localement ?

**ARP** (Address Resolution Protocol) sert à trouver l'adresse **MAC** (physique) d'une IP sur le réseau local. Or, les paquets ne peuvent traverser les routeurs qu'avec des adresses IP : les adresses MAC restent locales à chaque réseau.

- Destination **locale** → ARP pour trouver la MAC de la destination directement.

- Destination **distante** → ARP pour trouver la MAC du **gateway** (routeur), qui se chargera de transmettre.

### La table de routage

La table de routage est la "carte routière" de ta machine. Elle dit : *"pour atteindre ce réseau, envoie par ici"*.

```text
Destination     Gateway       Interface
0.0.0.0/0       10.0.0.1      eth0       ← route par défaut (tout ce qui n'est pas local)
192.168.1.0/24  0.0.0.0       eth0       ← réseau local direct

```text

### TTL : Durée de vie d'un paquet

Le **TTL** (Time To Live) est un compteur décrémenté de 1 à chaque routeur traversé. Quand il atteint 0, le paquet est détruit et un message d'erreur est renvoyé à l'expéditeur.

**Pourquoi ?** Sans TTL, un paquet mal routé tournerait en boucle indéfiniment dans le réseau. C'est le même principe qu'une lettre avec un nombre maximum de transferts autorisés.

```text
Machine A → Routeur 1 (TTL 64→63) → Routeur 2 (TTL 63→62) → ... → Destination

```text

---

## 4. Modèle OSI (Pratique)

### Couche 2 : Data Link : pourquoi la MAC du gateway ?

Ta machine veut envoyer un paquet à `8.8.8.8` (Google). Ce n'est pas local, donc elle doit passer par le **gateway** (routeur).

Mais sur le réseau physique (câble, Wi-Fi), les trames utilisent des **adresses MAC**, pas des adresses IP. Ta machine doit donc :

1. Savoir que `8.8.8.8` est distant → table de routage

2. Trouver l'IP du gateway → ex: `192.168.1.1`

3. Faire un **ARP** pour trouver la MAC de `192.168.1.1`

4. Envoyer la trame avec : **MAC destination = MAC du gateway**, IP destination = `8.8.8.8`

Le routeur reçoit la trame, lit l'IP de destination, et répète le processus vers le prochain saut.

### Couche 3 : Network : comment le routeur décide ?

À chaque saut, le routeur :

1. Reçoit le paquet

2. Lit l'IP de **destination**

3. Cherche la meilleure route dans sa table de routage

4. Envoie le paquet vers le prochain saut

Il ne regarde **pas** l'IP source, seulement la destination.

### On-link vs Off-link

| | On-link (local) | Off-link (distant) |
| --- | --- | --- |
| Réseau | Même sous-réseau | Sous-réseau différent |
| Communication | Directe via ARP | Via le gateway |
| MAC destination | MAC de la cible | MAC du gateway |
| Exemple | `192.168.1.5` depuis `192.168.1.10/24` | `8.8.8.8` depuis `192.168.1.10/24` |

**Analogie :** Imagine un immeuble. Si ton destinataire est dans le même immeuble (on-link), tu glisses la lettre sous sa porte directement. S'il est ailleurs (off-link), tu la déposes à la poste (gateway) qui se charge de l'acheminer.
