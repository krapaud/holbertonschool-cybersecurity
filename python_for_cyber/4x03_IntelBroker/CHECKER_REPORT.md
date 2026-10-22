# Rapport des corrections

J’ai ajouté la classe `TargetDossier` pour regrouper l’adresse IP, les données
VirusTotal, les données AbuseIPDB et les ports Nmap ouverts.

Le programme prend maintenant l’IP en argument, lance les trois vérifications
l’une après l’autre et affiche un résumé. Si Nmap échoue ou renvoie un XML
invalide, le programme affiche un message d’erreur et termine le résumé sans
traceback.

J’ai testé le flux avec des réponses simulées et vérifié le lint Python.
