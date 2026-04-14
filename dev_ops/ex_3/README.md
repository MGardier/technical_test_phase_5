# Exercice 3 : Mattermost + PostgreSQL — Corrections et justifications

## 1. Identifier pourquoi la connexion à la base de données échoue

- L'erreur `pq: SSL is not enabled on the server` dans les logs indique que Mattermost tente par défaut une connexion SSL vers PostgreSQL, mais PostgreSQL n'a pas SSL activé.
- J'ai ajouté `?sslmode=disable&connect_timeout=10` à la chaîne de connexion `MM_SQLSETTINGS_DATASOURCE` pour désactiver SSL et définir un timeout de 10 secondes pour la connexion.
- La désactivation de SSL est justifiée car les deux services communiquent via le réseau interne Docker, sans exposition extérieure. Si l'équipe souhaite activer SSL, il faudrait générer un certificat et une clé privée, les monter dans le container PostgreSQL avec `command: -c ssl=on -c ssl_cert_file=... -c ssl_key_file=...`, puis changer le `sslmode` en `require` (ou `verify-ca` en production).
- L'erreur `minimum Postgres version requirements not met. Found: 13.23, Wanted: 14.0` indique que Mattermost 11.5.1 (latest) nécessite au minimum PostgreSQL 14. J'ai donc mis à jour PostgreSQL vers la version 17.9 qui est la dernière version stable. Si la version est trop récente pour l'équipe, elle peut utiliser la version 14.22 au minimum.

## 2. Vérifier le format de la chaîne de connexion Mattermost

- Le format complet de la chaîne de connexion est : `postgres://USER:PASSWORD@HOST:PORT/DATABASE?sslmode=disable&connect_timeout=10`.
- Ce format est conforme au fichier `env.example` du dépôt officiel Mattermost Docker (github.com/mattermost/docker).
- Mattermost utilise la convention `MM_SECTION_SETTING` pour ses variables d'environnement, qui mappent directement les paramètres du fichier `config.json`. Par exemple, `SqlSettings.DataSource` dans le `config.json` devient `MM_SQLSETTINGS_DATASOURCE` en variable d'environnement. C'est pourquoi la connexion à la BDD se fait via une URI complète et non des variables séparées comme `POSTGRES_HOST`, contrairement à Nextcloud ou WordPress.
- Le paramètre `connect_timeout=10` définit un délai maximum de 10 secondes pour établir la connexion TCP avec PostgreSQL. Sans ce timeout, Mattermost pourrait rester bloqué indéfiniment si PostgreSQL ne répond pas.

## 3. Sécuriser la configuration avec des variables d'environnement

- Externalisation des credentials PostgreSQL et de l'URL du site dans un fichier `.env` pour éviter de commiter les secrets dans le repo Git.
- `MM_SERVICESETTINGS_SITEURL` a été externalisée dans le `.env` car cette valeur change selon l'environnement (domaine, HTTPS en production).

## Mentions spéciales

- Remplacement de `mattermost/mattermost-team-edition:latest` par la version fixée `11.5.1` (détectée dans les logs) pour la reproductibilité et la stabilité.
- Mise à jour de PostgreSQL 13 vers 17.9 pour respecter les prérequis de Mattermost 11.5.1.
- Ajout de `restart: unless-stopped` sur les deux services pour qu'ils redémarrent automatiquement en cas de crash.
- Ajout d'un healthcheck sur PostgreSQL avec pg_isready et sur Mattermost avec mmctl system status --local (CLI native incluse dans l'image). L'image officielle mattermost-team-edition n'a ni curl ni wget ne sont disponibles.
- Amélioration du `depends_on` avec `condition: service_healthy` pour que Mattermost ne démarre que quand PostgreSQL est prêt, évitant les erreurs `connection refused` au démarrage.