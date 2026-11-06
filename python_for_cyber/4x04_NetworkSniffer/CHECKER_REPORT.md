Lors de ma vérification, j’ai remarqué que `py_sniffer.py` n’était pas
exécutable. J’ai corrigé ses permissions, puis j’ai relancé le script et
pycodestyle : les deux contrôles passent.

J’ai aussi créé le `venv` du projet et installé Scapy 2.8.0. La vérification
visuelle dans VS Code n’a pas pu être faite, car l’application n’a pas répondu
aux deux tentatives d’ouverture.
