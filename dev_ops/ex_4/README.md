# Exercice 4 : Stack ELK (Elasticsearch + Logstash + Kibana) — Corrections et justifications

## 1. Résoudre les problèmes de mémoire d'Elasticsearch

- Le compose original ne définit aucune limite mémoire sur le conteneur ES. Le heap JVM est fixé à 512 Mo (`ES_JAVA_OPTS=-Xms512m -Xmx512m`), mais le heap n'est qu'une partie de la mémoire consommée par ES. Lucene, le moteur de recherche derrière ES, utilise massivement le page cache de l'OS (hors-heap) pour mapper ses fichiers d'index en mémoire. Sans limite, ES voit toute la RAM du host et tente de l'utiliser, ce qui provoque une saturation complète de la mémoire — confirmé par l'impossibilité d'utiliser Portainer ou de consulter les logs quand ES tournait.
- J'ai ajouté `mem_limit: 1g` pour plafonner la RAM totale du conteneur. La règle recommandée par Elastic est d'allouer environ 2x le heap au conteneur : 512 Mo de heap + ~500 Mo pour Lucene, les thread stacks et les buffers réseau = 1 Go.
- J'ai ajouté `memswap_limit: 1g` (même valeur que `mem_limit`) pour interdire l'utilisation du swap0.

- Le paramètre `vm.max_map_count=262144` est un prérequis kernel pour ES (qui utilise `mmap` pour mapper ses fichiers d'index). La valeur par défaut de Linux est 65530, insuffisante pour ES. Ce n'était pas la cause du problème dans mon cas (la valeur était déjà correcte sur mon host), mais c'est un piège classique à documenter pour la portabilité du setup. Le script `init.sh` vérifie cette valeur et avertit l'utilisateur si elle est insuffisante.

## 2. S'assurer que les services démarrent dans le bon ordre

- Le compose original n'a que des `depends_on` basiques sans healthcheck. Sur une stack de cette taille (ES met 30-60s à s'initialiser, Logstash et Kibana tentent de s'y connecter immédiatement), cela provoque des crashs en cascade : Kibana et Logstash démarrent avant qu'ES soit prêt, échouent à se connecter, et selon les versions peuvent ne pas réessayer correctement.
- J'ai ajouté des healthchecks sur ES (`curl` sur `/_cluster/health`), Logstash (`curl` sur l'API monitoring port 9600) et Kibana (`curl` sur `/api/status`). Les trois images Elastic contiennent `curl`, contrairement à Mattermost qui nécessitait `mmctl`.
- J'ai amélioré tous les `depends_on` avec `condition: service_healthy` pour orchestrer le démarrage : ES démarre en premier, puis Logstash et Kibana ne se lancent que quand ES est healthy, puis Filebeat ne se lance que quand Logstash est healthy.
- Les `start_period` sont adaptés au temps d'initialisation de chaque service : 60s pour ES (chargement des index et plugins), 45s pour Logstash (initialisation des pipelines), 60s pour Kibana (migrations des saved objects).

## 3. Tester l'ingestion de logs et leur visualisation dans Kibana

- La stack complète fonctionne de bout en bout : Filebeat lit les fichiers `/var/log/*.log` du host → envoie à Logstash via le protocole Beats sur le port 5044 → Logstash pousse dans Elasticsearch → les données sont visualisables dans Kibana.
- Vérification par `curl -s http://localhost:9200/_cat/indices?v` : l'index `filebeat-8.11.0-2026.04.14` contient 101 524 documents (21.7 Mo), confirmant que l'ingestion fonctionne.
- Visualisation dans Kibana : création d'un Data View avec le pattern `filebeat-*` et le champ `@timestamp`, puis consultation dans Discover.

- EN COURS manque de temps pour finir 

## 4. Optimiser les performances et la sécurité

- Manque de temps

## Mentions spéciales

- Création d'un script `init.sh` pour initialiser automatiquement les fichiers de config (Logstash, Filebeat) avec les bonnes permissions. Sans ce script, si `docker compose up` est lancé avant que les fichiers existent, Docker crée des dossiers vides à leur place (owned par root), ce qui empêche les conteneurs de démarrer. Le script détecte et nettoie ces dossiers fantômes, crée les fichiers de config, fixe les permissions Filebeat (`chmod 644`, exigé par Filebeat qui refuse de démarrer si son config est writable par le groupe), et vérifie le prérequis `vm.max_map_count`.
- Warning Filebeat : le type d'input `log` est déprécié depuis la 8.x au profit de `filestream`. Le pipeline fonctionne mais pour anticiper les futures versions, il faudrait migrer vers `type: filestream`.
- La directive `xpack.monitoring.elasticsearch.hosts` dans `logstash.yml` est dépréciée depuis la 8.x. Le monitoring passe désormais par le self-monitoring intégré. Ça ne provoque pas de crash mais génère des warnings dans les logs.