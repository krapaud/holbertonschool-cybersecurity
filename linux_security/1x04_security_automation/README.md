# Security Automation : Mini-cours

> **Dépôt :** holbertonschool-cybersecurity
> **Répertoire :** `linux_security/1x04_security_automation`

---

## Vue d'ensemble : L'agent de sécurité autonome

Ce module construit **Sentinel** : un agent de surveillance automatisé qui tourne en continu sur un système. Son rôle : surveiller, détecter, et corriger automatiquement les dérives de sécurité.

**Analogie :** Sentinel c'est le vigile de nuit de ton datacenter. Il fait des rondes toutes les 5 minutes, vérifie que les portes sont fermées, que les caméras fonctionnent, et qu'aucun inconnu n'est entré. S'il trouve un problème, il le corrige et laisse un rapport.

### Architecture de Sentinel

```text
sentinel.sh          # Le script principal : logique de surveillance
sentinel.conf        # Configuration : ce qu'on surveille
sentinel.service     # Unité systemd : comment lancer sentinel
sentinel.timer       # Timer systemd : quand le lancer (toutes les 5 min)
setup_persistence.sh # Script d'installation : active le timer au démarrage
```

---

## 1. Le fichier de configuration : `sentinel.conf`

```bash
SERVICES=("ssh" "cron")
FILES_TO_WATCH=("/etc/passwd" "/etc/ssh/sshd_config")
ALLOWED_PORTS=("22" "80")
```

La configuration est séparée du code. C'est un principe fondamental : le comportement est défini dans le code, les données (quoi surveiller) dans la config. Pour surveiller un nouveau service, on modifie la config, pas le script.

`source sentinel.conf` dans le script charge ces variables dans l'environnement courant : comme si on les avait tapées directement.

---

## 2. Les trois fonctions de surveillance

### Surveillance des services : `check_services()`

```bash
for service in "${SERVICES[@]}"; do
    if pgrep -f "$service" > /dev/null; then
        echo "OK: $service is running"
    else
        eval "${!start_cmd}"
        echo "FIXED: Restarted $service"
    fi
done
```

**`pgrep -f`** cherche un processus par son nom dans la liste complète des processus. `-f` permet de chercher dans la ligne de commande entière (pas seulement le nom court).

**`${SERVICES[@]}`** : syntaxe bash pour itérer sur tous les éléments d'un tableau.

**`eval "${!start_cmd}"`** : double déréférencement de variable.

- `start_cmd="START_${service}"` construit le nom de variable `START_ssh`
- `${!start_cmd}` récupère la valeur de la variable dont le nom est dans `start_cmd`
- `eval` exécute cette valeur comme une commande

C'est une technique pour appeler dynamiquement des commandes définies dans la config.

### Vérification d'intégrité : `check_integrity()`

```bash
hash_file=$(md5sum "$file" | awk '{print $1}')
gold="/var/backups/sentinel/$(basename "$file").gold"
hash_gold=$(md5sum "$gold" | awk '{print $1}')

if [ $hash_file = $hash_gold ]; then
    echo "OK: $file integrity verified"
else
    cp "$gold" "$file"
    echo "FIXED: Restored $file"
fi
```

**Principe :** chaque fichier critique a une copie de référence (`.gold`). À chaque ronde, Sentinel compare le hash MD5 du fichier actuel avec la copie de référence. Si ça diffère → le fichier a été modifié → restauration automatique.

**MD5 pour l'intégrité :** MD5 ne convient pas pour la cryptographie (cassé), mais pour détecter une modification de fichier, il reste suffisant. Les outils de production utilisent SHA-256.

**Pourquoi surveiller `/etc/passwd` et `sshd_config` ?**

- `/etc/passwd` : une modification pourrait indiquer l'ajout d'un compte backdoor
- `/etc/ssh/sshd_config` : une modification pourrait ré-autoriser l'accès root ou les mots de passe

### Surveillance des ports : `check_ports()`

```bash
for port in $(ss -lntp | awk 'NR>1{split($4, a, ":"); print a[2]}'); do
    allowed=false
    for allowed_port in "${ALLOWED_PORTS[@]}"; do
        if [ "$port" = "$allowed_port" ]; then
            allowed=true
        fi
    done
    if [ "$allowed" = false ]; then
        ss -K sport = :$port 2>/dev/null
        echo "ALERT: Killed rogue process on port $port"
    fi
done
```

**Logique :** pour chaque port ouvert sur le système, on vérifie s'il est dans la liste des ports autorisés. S'il ne l'est pas → processus non autorisé → on coupe la connexion avec `ss -K`.

**`ss -K sport = :$port`** : tue toutes les connexions sur ce port source. C'est une méthode agressive pour stopper un service non autorisé.

**Cas concret :** un attaquant ouvre un shell reverse sur le port 4444. Sentinel le détecte au prochain cycle (max 5 minutes) et coupe la connexion.

---

## 3. Le système de logs JSON

```bash
log() {
    local timestamp=$(date -u +%FT%TZ)
    local component=$1
    local target=$2
    local status=$3
    local details=$4
    echo "{
    \"timestamp\": \"$timestamp\",
    \"component\": \"$component\",
    \"target\": \"$target\",
    \"status\": \"$status\",
    \"details\": \"$details\"
}" >> /var/log/sentinel.log
}
```

Les logs sont au format **JSON** : un format structuré lisible par des machines. Contrairement aux logs texte libres, JSON peut être ingéré par des outils comme Elasticsearch, Splunk, ou de simples `jq`.

**`date -u +%FT%TZ`** : format ISO 8601 en UTC.

- `-u` : UTC
- `+%FT%TZ` : `2026-07-22T14:30:00Z` : format standardisé internationalement

**`local`** : déclare des variables locales à la fonction. Elles n'existent que dans le scope de la fonction et n'écrasent pas les variables du script principal.

---

## 4. Systemd : Orchestration de services

### `sentinel.service` : L'unité de service

```ini
[Unit]
Description=Sentinel Security Agent

[Service]
Type=oneshot
ExecStart=/home/student/sentinel.sh
User=root

[Install]
WantedBy=multi-user.target
```

| Directive | Signification |
| --- | --- |
| `Type=oneshot` | Le service s'exécute, termine, et systemd attend la fin avant de continuer |
| `ExecStart` | La commande à lancer |
| `User=root` | S'exécute en tant que root (nécessaire pour modifier des fichiers système) |
| `WantedBy=multi-user.target` | Activé en mode normal (avec réseau, sans interface graphique) |

### `sentinel.timer` : Le déclencheur

```ini
[Timer]
OnUnitActiveSec=5min
Persistent=true
Unit=sentinel.service
```

| Directive | Signification |
| --- | --- |
| `OnUnitActiveSec=5min` | Relance l'unité toutes les 5 minutes après la dernière activation |
| `Persistent=true` | Si la machine était éteinte à l'heure prévue, exécute dès le redémarrage |
| `Unit=sentinel.service` | Quelle unité déclencher |

**Timer vs Cron :** les timers systemd ont plusieurs avantages sur cron :

- Logs intégrés (`journalctl`)
- Gestion des ratés (`Persistent=true`)
- Dépendances systemd
- Pas de syntaxe cryptique `*/5 * * * *`

### `setup_persistence.sh` : Installation

```bash
cp sentinel.service /etc/systemd/system/
cp sentinel.timer /etc/systemd/system/
systemctl daemon-reload          # recharger la liste des unités
systemctl enable sentinel.timer  # activer au démarrage
systemctl start sentinel.timer   # démarrer maintenant
```

`daemon-reload` est obligatoire après avoir ajouté ou modifié des fichiers `.service` ou `.timer` : systemd ne détecte pas automatiquement les changements.

---

## 5. Commandes systemd essentielles

```bash
# Gérer le timer
systemctl start sentinel.timer       # démarrer
systemctl stop sentinel.timer        # arrêter
systemctl enable sentinel.timer      # activer au démarrage
systemctl disable sentinel.timer     # désactiver au démarrage
systemctl status sentinel.timer      # voir l'état

# Voir les logs de sentinel
journalctl -u sentinel.service       # tous les logs
journalctl -u sentinel.service -f    # en temps réel (follow)
journalctl -u sentinel.service -n 20 # les 20 dernières lignes

# Voir le prochain déclenchement
systemctl list-timers sentinel.timer

# Forcer une exécution immédiate
systemctl start sentinel.service
```

---

## 6. Principes de sécurité de l'automatisation

### Validation avant action

Sentinel valide la configuration au démarrage (`if [ -z "$SERVICES" ]; then exit 1`). Un script d'automatisation qui démarre sans ses paramètres et fait n'importe quoi peut causer des dommages plus graves que l'absence de surveillance.

### Idempotence

Une opération est **idempotente** si l'exécuter plusieurs fois produit le même résultat. Sentinel est idempotent : le relancer plusieurs fois ne cause pas de problème : il vérifie l'état et corrige si nécessaire, sans accumuler d'effets de bord.

### Principe du moindre privilège

Sentinel tourne en root car il doit lire des fichiers système et tuer des processus. Dans un système de production, il vaudrait mieux restreindre précisément les capabilities nécessaires plutôt que de donner root complet.

### Logs structurés

Les logs JSON permettent de :

- Corréler des événements entre systèmes
- Alimenter des SIEM (Security Information and Event Management)
- Générer des métriques et alertes automatiques

---

## 7. Récap des commandes essentielles

```bash
# Installer Sentinel
sudo ./setup_persistence.sh

# Vérifier l'état
systemctl status sentinel.timer

# Voir les logs
journalctl -u sentinel.service -f

# Tester manuellement
sudo ./sentinel.sh

# Lire le fichier de log JSON
cat /var/log/sentinel.log | python3 -m json.tool
```
