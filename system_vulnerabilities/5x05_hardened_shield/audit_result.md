# Hardened Shield: rapport d'audit

- État: en attente d'exécution dans le conteneur Hardened Shield.
- Commande: `python3 /opt/hardened-shield/scripts/audit.py`
- Fichier produit: `audit_result.md`

## Scores

| Catégorie | Score |
|---|---:|
| Kernel hardening | En attente |
| Filesystem security | En attente |
| Identity security | En attente |
| Service security | En attente |
| Container security | En attente |
| **Overall** | **En attente** |

## Statut

**PENDING**: les contrôles n'ont pas encore été lancés dans le conteneur.

Les contrôles de noyau, de montages, de services et de restrictions Docker
dépendent de l'environnement d'exécution. Aucun score n'est inscrit ici avant
l'exécution de l'audit dans le conteneur. Le script remplacera ce fichier par
les résultats, les scores par catégorie et le statut général.
