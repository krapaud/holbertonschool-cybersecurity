# Services Réseau : Cours pour débutants

---

## 1. Fondamentaux DNS

### Requêtes récursives vs itératives

Quand tu tapes `google.com` dans ton navigateur, ton ordinateur doit trouver l'IP correspondante. Il y a deux façons de faire ça :

**Requête récursive** : ton ordinateur demande à son resolver (ex: `8.8.8.8`) et lui dit *"trouve-moi l'IP, je t'attends"*. Le resolver fait tout le travail et te répond directement avec la réponse finale. C'est ce que fait ta machine au quotidien.

**Requête itérative** : le resolver demande à chaque serveur *"qui peut répondre ?"* et suit les indications étape par étape. C'est ce que font les resolvers entre eux.

```
[Ta machine] →→ (récursive) →→ [Resolver 8.8.8.8]
                                      ↓ (itérative)
                               [Root server]  → "demande à .com"
                                      ↓
                               [Serveur .com] → "demande à google.com"
                                      ↓
                               [Serveur google.com] → "142.250.x.x"
                                      ↓
[Ta machine] ←← 142.250.x.x ←← [Resolver 8.8.8.8]
```

### La hiérarchie DNS

Le DNS est organisé comme une **arborescence inversée** :

```
                    . (Root)
                   / \
                .com  .fr  .org  ...
               /    \
          google.com  facebook.com
          /
    www.google.com
```

- **Root servers (.)** : 13 clusters de serveurs dans le monde. Ils ne connaissent pas les IPs, mais savent qui gère chaque extension (.com, .fr, .org...).
- **Serveurs TLD** : gèrent les extensions (.com géré par Verisign, .fr par l'AFNIC...). Ils savent qui gère chaque domaine de leur zone.
- **Serveurs autoritaires** : gèrent un domaine précis (ex: `google.com`). Ils connaissent les vraies réponses (IPs, MX, etc.).

### Les types de records DNS

| Type | Nom | Rôle | Exemple |
|------|-----|------|---------|
| **A** | Address | IP v4 d'un domaine | `google.com → 142.250.74.206` |
| **AAAA** | IPv6 Address | IP v6 d'un domaine | `google.com → 2a00:1450::200e` |
| **CNAME** | Canonical Name | Alias vers un autre domaine | `www.github.com → github.com` |
| **MX** | Mail Exchanger | Serveur mail du domaine | `google.com → smtp.google.com` |
| **TXT** | Text | Texte libre (SPF, vérifications) | `"v=spf1 include:..."` |
| **PTR** | Pointer | Reverse DNS (IP → nom) | `8.8.8.8 → dns.google.` |
| **SOA** | Start of Authority | Infos d'administration de la zone | Serveur primaire, admin, TTL... |
| **NS** | Name Server | Serveurs autoritaires du domaine | `google.com → ns1.google.com` |

### TTL et cache DNS

Le **TTL** (Time To Live) indique combien de temps (en secondes) une réponse DNS peut être mise en **cache**.

```
dig google.com → 142.250.74.206  TTL: 300
```

Cela signifie : *"cette réponse est valide 300 secondes (5 min). Après ça, redemande."*

**Pourquoi ?** Sans cache, chaque requête web déclencherait des dizaines de requêtes DNS. Avec le cache, ta machine mémorise les réponses et ne redemande qu'après expiration du TTL.

---

## 2. Sécurité DNS

### /etc/hosts : le DNS local qui prime sur tout

Avant de contacter un serveur DNS, ton système lit le fichier `/etc/hosts`. Ce fichier contient des correspondances statiques nom → IP.

```
127.0.0.1   localhost
192.168.1.10  monserveur.local
```

**Usages légitimes :**
- Développeurs testant un site en local (`monapp.local → 127.0.0.1`)
- Bloquer des domaines publicitaires (`ads.example.com → 0.0.0.0`)

**Usages malveillants :**
- Un malware modifie `/etc/hosts` pour rediriger `mabanque.fr → IP du hacker`
- Tu tapes l'URL correcte, mais tu arrives sur une fausse page

C'est pour ça que ce fichier est une cible privilégiée des malwares.

### SPF : Empêcher l'usurpation d'email

Le **SPF** (Sender Policy Framework) est un record **TXT** dans le DNS qui liste les serveurs autorisés à envoyer des emails pour un domaine.

```
dig TXT google.com
→ "v=spf1 include:_spf.google.com ~all"
```

**Comment ça marche ?**
1. Tu reçois un email de `contact@google.com`
2. Ton serveur mail demande : *"quels serveurs sont autorisés à envoyer pour google.com ?"*
3. Il compare avec l'IP du serveur expéditeur
4. Si ce n'est pas dans la liste SPF → email suspect → spam ou rejet

Sans SPF, n'importe qui peut envoyer un email en se faisant passer pour `google.com`.

### Zone Transfer (AXFR) : La fuite de données DNS

Un **Zone Transfer** est le mécanisme par lequel un serveur DNS secondaire copie toute la zone DNS du serveur primaire pour rester synchronisé.

**Le problème :** si le serveur est mal configuré et accepte les transfers de n'importe qui, un attaquant peut récupérer **toute la base de données DNS** du domaine :
- Tous les sous-domaines (y compris internes : `vpn.acme.corp`, `dev.acme.corp`)
- Toutes les IPs associées
- Les serveurs mail, les serveurs de noms...

```bash
dig AXFR domaine.com @ns1.domaine.com
```

Un serveur correctement configuré répondra `; Transfer failed.`

### Interroger un serveur DNS directement

Par défaut, `dig` utilise le resolver configuré dans `/etc/resolv.conf`. Pour interroger un serveur spécifique :

```bash
dig @8.8.8.8 google.com        # interroge Google DNS
dig @1.1.1.1 google.com        # interroge Cloudflare DNS
dig @10.10.10.5 intranet.corp  # interroge un DNS interne
```

Utile pour : comparer les réponses de différents serveurs, déboguer, ou accéder aux DNS internes d'une organisation.

---

## 3. Fondamentaux DHCP

### Le processus DORA

Quand tu connectes ta machine à un réseau, elle n'a pas d'IP. Le protocole **DHCP** lui en attribue une automatiquement via 4 étapes appelées **DORA** :

```
Machine                          Serveur DHCP
  |                                    |
  |--- DISCOVER (broadcast) ---------> |  "Y a-t-il un serveur DHCP ?"
  |                                    |
  |<-- OFFER ------------------------- |  "Oui, je t'offre 192.168.1.10"
  |                                    |
  |--- REQUEST ----------------------> |  "J'accepte cette IP"
  |                                    |
  |<-- ACKNOWLEDGE ------------------- |  "C'est confirmé, c'est à toi"
  |                                    |
```

- **Discover** : broadcast sur tout le réseau (l'hôte ne connaît personne)
- **Offer** : le serveur propose une IP disponible
- **Request** : l'hôte confirme qu'il veut cette IP (broadcast aussi, pour informer d'autres serveurs DHCP)
- **Acknowledge** : le serveur valide et envoie toutes les infos

### Ce que DHCP fournit

Un bail DHCP contient bien plus qu'une IP :

| Information | Exemple | Rôle |
|-------------|---------|------|
| Adresse IP | `192.168.1.10` | Ton identité sur le réseau |
| Masque | `255.255.255.0` | Délimite ton réseau local |
| Gateway | `192.168.1.1` | Porte de sortie vers internet |
| DNS | `8.8.8.8` | Qui répond à tes requêtes DNS |
| Lease time | `3600s` | Durée de validité du bail |

### Où sont stockés les baux DHCP sous Linux ?

Selon la distribution et le gestionnaire réseau :

```bash
/var/lib/dhcp/dhclient.eth0.leases   # dhclient classique
nmcli -f DHCP4 con show "nom"        # NetworkManager
journalctl | grep -i dhcp            # logs systemd
```

### Attaque par Rogue DHCP

Un **Rogue DHCP** est un faux serveur DHCP sur le réseau qui répond plus vite que le serveur légitime.

**Scénario d'attaque :**
1. L'attaquant connecte une machine avec un serveur DHCP malveillant
2. Ta machine envoie un DHCP Discover (broadcast)
3. Le serveur malveillant répond en premier avec son OFFER
4. Il te donne une IP valide, mais son **gateway = sa propre machine**
5. Tout ton trafic passe maintenant par l'attaquant → **Man-in-the-Middle**

C'est pour ça qu'il est important de vérifier l'IP du serveur DHCP qui t'a attribué ton bail.

---

## 4. Compétences pratiques

### dig : Outil de référence pour le DNS

```bash
dig google.com                    # requête A (IPv4)
dig AAAA google.com               # requête IPv6
dig MX google.com                 # serveurs mail
dig TXT google.com                # records texte
dig CNAME www.github.com          # alias
dig SOA google.com                # infos zone
dig NS google.com                 # serveurs de noms
dig +short google.com             # juste l'IP, sans verbosité
dig +trace google.com             # trace la résolution étape par étape
dig -x 8.8.8.8                    # reverse DNS (PTR)
dig @8.8.8.8 google.com           # interroger un serveur spécifique
dig AXFR domaine.com @ns1.dom.com # tentative de zone transfer
```

### nslookup : Débogage interactif

```bash
nslookup google.com               # requête simple
nslookup -type=MX google.com      # type spécifique
nslookup google.com 8.8.8.8       # via un serveur précis
```

En mode interactif :
```bash
nslookup
> set type=MX
> google.com
> exit
```

### Lire /etc/resolv.conf

```bash
cat /etc/resolv.conf
```

```
nameserver 10.211.55.2    ← resolver primaire
nameserver fe80::1%eth0   ← resolver secondaire (IPv6)
search hbtn.fr            ← domaine de recherche par défaut
```

Le `nameserver` est l'IP à qui ta machine pose ses questions DNS. Si un attaquant le change, il contrôle ta résolution DNS.

### Reverse DNS (PTR)

Le reverse DNS permet de trouver le nom associé à une IP : l'inverse d'une requête A.

```bash
dig +short -x 8.8.8.8    → dns.google.
dig +short -x 1.1.1.1    → one.one.one.one.
```

**Utilisations :**
- Analyser des logs : *"qui est derrière cette IP ?"*
- Valider les serveurs mail : les serveurs vérifient que l'IP expéditrice a un PTR valide
- Reconnaissance lors d'un audit de sécurité
