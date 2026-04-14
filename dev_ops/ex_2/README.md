# Exercice 2 : Nextcloud + PostgreSQL — Corrections et justifications

## 1. Identifier pourquoi Nextcloud affiche "Internal Server Error"

- N'ayant pas pu reproduire l'erreur, celle-ci était probablement intermittente, liée au timing de démarrage entre les services.
- Le problème peut être dû à un problème de connexion avec PostgreSQL. J'ai donc ajouté un healthcheck pour vérifier que PostgreSQL est prêt et amélioré le `depends_on` pour ne lancer Nextcloud que si PostgreSQL est healthy.
- Cela peut aussi être dû à des problèmes de compatibilité avec l'image `latest` qui peut avoir changé depuis ou une incompatibilité avec la version de PostgreSQL. J'ai donc fixé la version de Nextcloud.
- Dernière chose, cela peut être dû à l'environnement de l'équipe qui peut avoir des problèmes avec un ancien volume, une ancienne version de la config sous une autre image de Nextcloud qui n'est plus compatible, ou alors un problème avec la config PHP comme `memory_limit` par exemple. Dans ce cas l'équipe doit supprimer ou migrer son ancienne configuration, supprimer les anciens volumes et ajuster la configuration à l'environnement si besoin.
- Pour diagnostiquer précisément l'erreur, il faut consulter les logs applicatifs Nextcloud via `docker compose exec nextcloud cat /var/www/html/data/nextcloud.log` qui contient le détail de l'erreur, contrairement aux logs Apache qui n'affichent que la 500.

## 2. Intégrer Redis comme cache pour Nextcloud

- Dans le compose original il n'y avait pas de connexion entre Redis et Nextcloud. Nextcloud n'était pas au courant de l'existence de Redis. J'ai donc rajouté la variable d'environnement `REDIS_HOST` pour le connecter à Redis.
- Redis n'étant utilisé qu'en interne, j'ai retiré l'exposition du port vers l'extérieur et je n'ai donc pas mis de mot de passe.
- Si jamais l'équipe souhaite sécuriser Redis avec un mot de passe, elle devra ajouter côté Redis : `command: redis-server --requirepass <password>` et côté Nextcloud : `REDIS_HOST_PASSWORD=<password>`.

## 3. Mettre en place les health checks appropriés

- Ajout d'un healthcheck sur PostgreSQL avec `pg_isready` pour vérifier que le serveur accepte des connexions.
- Ajout d'un healthcheck sur Redis avec `redis-cli ping` pour vérifier que le cache répond.
- Ajout d'un healthcheck sur Nextcloud avec `curl` sur localhost pour vérifier qu'Apache répond.
- Amélioration des `depends_on` de Nextcloud avec `condition: service_healthy` pour que Nextcloud ne démarre que quand PostgreSQL et Redis sont prêts. Cela prévient les erreurs de connexion intermittentes au démarrage.

## Mentions spéciales

- Remplacement de `nextcloud:latest` par une version fixée et `redis:alpine` par une version fixée pour la reproductibilité et la stabilité.
- Externalisation des credentials dans un fichier `.env` pour éviter de commiter les secrets dans le repo Git.
- Retrait de l'exposition des ports PostgreSQL et Redis car ces services ne communiquent qu'en interne via le réseau Docker.
- Ajout de `NEXTCLOUD_ADMIN_USER` et `NEXTCLOUD_ADMIN_PASSWORD` pour automatiser la création du compte administrateur au premier lancement, évitant le passage par le wizard d'installation.