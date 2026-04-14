# Exercice 1 : WordPress + MySQL — Corrections et justifications

## 1. Identifier pourquoi MySQL ne démarre pas

- MySQL ne démarre pas car la variable `MYSQL_ROOT_PASSWORD` a été oubliée et refuse de démarrer, ce qui est le comportement voulu par MySQL sans cette option ou l'option `MYSQL_ALLOW_EMPTY_PASSWORD=yes` pour se connecter sans mot de passe.
- J'ai rajouté l'option `MYSQL_ROOT_PASSWORD` pour le fixer plutôt que le 2ème choix qui est très risqué car n'importe qui peut se connecter root sans mot de passe.

## 2. Corriger les problèmes de connexion WordPress ↔ MySQL

- Le problème était que MySQL crashait mais le `depends_on` de WordPress ne vérifiait que le démarrage, pas l'état du container MySQL. Donc WordPress démarrait sans MySQL.
- J'ai donc ajouté un healthcheck sur MySQL pour vérifier qu'il est healthy et amélioré le `depends_on` de WordPress pour qu'il ne démarre que si le service est healthy.

## 3. Sécuriser la configuration (mots de passe, réseau)

- Retirer les ports de MySQL car dans le contexte actuel il n'a pas à exposer ses ports vers l'extérieur car il ne sert que pour des services internes.
- Déplacement des credentials dans `.env` pour éviter de commiter les credentials dans le repo Git et s'exposer. Il est à noter également qu'en production les mots de passe doivent être des mots de passe forts.
- Il est important de noter qu'en production il faudrait ajouter des mesures de restriction d'accès pour phpMyAdmin et WordPress ainsi qu'un reverse proxy en HTTPS pour sécuriser ces services.

## Mentions spéciales

- Remplacement du tag `latest` de WordPress par une version fixée, car `latest` pointe toujours vers la dernière image disponible, ce qui pose des problèmes de stabilité et de reproductibilité, surtout en production.
- Changement mineur pour l'image de phpMyAdmin vers l'image officielle maintenue par Docker pour plus de sécurité et stabilité grâce notamment aux audits de sécurité.
- J'ai également amélioré le `depends_on` de phpMyAdmin et ajouté des healthchecks pour les 3 containers pour s'assurer de leur bon fonctionnement.