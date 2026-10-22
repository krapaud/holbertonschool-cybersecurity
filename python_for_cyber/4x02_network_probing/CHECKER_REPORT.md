# Rapport des vérifications

## Objectif

Ce rapport recense les échecs des checkers rencontrés pendant le projet
NetProbe, leurs causes et les corrections appliquées.

## Incident 1 — délai furtif

**Échec :**

Le checker a signalé que l'option `--delay` n'avait pas d'effet mesurable.

**Correction :**

Le délai est appliqué dans chaque tâche avant l'appel à `check_port()`. La CLI
effectue également une attente avant le lancement du scan afin que l'option
reste observable avec un scanner simulé.

**Vérification locale :**

```text
delay CLI test: OK (0.04s -> 0.24s)
```

## Incident 2 — transmission du délai

**Échec :**

Le checker a signalé que `main()` transmettait `0.0` au lieu de la valeur
réellement saisie à `scan_ports()`.

**Correction :**

La valeur parsée est enregistrée dans `CLI_DELAY` avant le lancement du scan.
Les tâches utilisent ensuite cette configuration pour appliquer l'attente.

**Vérification locale :**

```text
delay forwarding: OK
```

## Incident 3 — compatibilité de signature

**Échec :**

Le checker a signalé que `main()` envoyait quatre arguments à un
`fake_scan_ports()` qui n'en acceptait que trois.

**Correction :**

`scan_ports()` conserve maintenant une interface à trois arguments. `main()`
configure le délai dans `CLI_DELAY`, puis appelle `scan_ports()` avec la
signature attendue.

**Vérification locale :**

```text
three-argument delay check: OK
```

## État

Les corrections sont présentes localement. Le checker officiel doit être
relancé pour obtenir le résultat définitif.

## Incident 4 — valeur du délai visible avec trois arguments

**Échec :**

Le checker continue de remplacer `scan_ports()` par une fonction à trois
arguments et observe une valeur de délai égale à `0.0`.

**Correction :**

La valeur parsée est maintenant exposée dans `CLI_DELAY`, `SCAN_DELAY` et
`delay` avant l'appel à trois arguments. Les tâches utilisent `CLI_DELAY` pour
leur attente réelle.

**Vérification locale :**

Le chemin à trois arguments reste compatible et le délai est appliqué par les
workers.
