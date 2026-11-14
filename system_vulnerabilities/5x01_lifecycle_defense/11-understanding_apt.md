# Comprendre APT

`/etc/apt/sources.list` contient les dépôts principaux de la machine. Les fichiers de `/etc/apt/sources.list.d/` permettent d’ajouter ou de gérer séparément des dépôts, par exemple ceux d’un éditeur. Cette séparation facilite l’administration, mais chaque dépôt doit être fiable et compatible avec la version d’Ubuntu.

Pour Ubuntu 20.04, `focal` désigne la distribution. `focal-security` fournit les correctifs de sécurité, `focal-updates` les mises à jour recommandées après la publication initiale, et `focal-backports` des versions plus récentes adaptées à la distribution, avec une garantie de support différente. Les dépôts doivent correspondre à la version installée.

Les priorités APT déterminent quelle version est candidate lorsqu’un paquet existe dans plusieurs sources. `apt-cache policy nom_du_paquet` affiche les versions disponibles et leurs priorités. Les préférences dans `/etc/apt/preferences` ou `/etc/apt/preferences.d/` peuvent épingler une version ou un dépôt. Un pin mal choisi peut bloquer un correctif, sélectionner une version inattendue ou mélanger des distributions.

Je préfère ajouter un fichier dédié dans `sources.list.d` pour isoler un dépôt tiers et pouvoir le désactiver facilement. Modifier directement `sources.list` peut affecter les dépôts système, créer des doublons ou rendre les mises à jour incohérentes. Avant toute modification, je sauvegarde le fichier, vérifie le nom de code Ubuntu, puis lance `apt-get update` et examine les erreurs ainsi que `apt-cache policy`.
