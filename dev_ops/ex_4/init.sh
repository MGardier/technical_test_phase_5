#!/bin/bash
# init.sh — Initialise les fichiers de config pour la stack ELK
# À exécuter une seule fois avant le premier docker compose up

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# --- Nettoyage des dossiers fantômes créés par Docker ---
# Si Docker a été lancé avant que les fichiers de config existent,
# il crée des dossiers vides à leur place. On les détecte et on les supprime.
for target in ./logstash/config/logstash.yml ./filebeat/filebeat.yml; do
  if [ -d "$target" ]; then
    echo "⚠  $target est un dossier (créé par Docker), suppression..."
    rm -rf "$target"
  fi
done

# --- Logstash ---
mkdir -p ./logstash/config ./logstash/pipeline

if [ ! -f ./logstash/config/logstash.yml ]; then
  cat > ./logstash/config/logstash.yml << 'EOF'
http.host: "0.0.0.0"
xpack.monitoring.elasticsearch.hosts: [ "http://elasticsearch:9200" ]
EOF
  echo "✔ logstash/config/logstash.yml créé"
else
  echo "⏭ logstash/config/logstash.yml existe déjà"
fi

if [ ! -f ./logstash/pipeline/logstash.conf ]; then
  cat > ./logstash/pipeline/logstash.conf << 'EOF'
input {
  beats {
    port => 5044
  }
}

output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "%{[@metadata][beat]}-%{[@metadata][version]}-%{+YYYY.MM.dd}"
  }
}
EOF
  echo "✔ logstash/pipeline/logstash.conf créé"
else
  echo "⏭ logstash/pipeline/logstash.conf existe déjà"
fi

# --- Filebeat ---
mkdir -p ./filebeat

if [ ! -f ./filebeat/filebeat.yml ]; then
  cat > ./filebeat/filebeat.yml << 'EOF'
filebeat.inputs:
- type: filestream
  enabled: true
  paths:
    - /var/log/*.log

output.logstash:
  hosts: ["logstash:5044"]

processors:
  - add_host_metadata:
      when.not.contains.tags: forwarded
EOF
  echo "✔ filebeat/filebeat.yml créé"
else
  echo "⏭ filebeat/filebeat.yml existe déjà"
fi

# --- Permissions ---
# Filebeat exige que son config ne soit writable que par le owner (644 max)
chmod 644 ./filebeat/filebeat.yml
echo "✔ Permissions filebeat.yml fixées (644)"

# --- Prérequis host ---
CURRENT_MAP_COUNT=$(sysctl -n vm.max_map_count 2>/dev/null || echo "0")
if [ "$CURRENT_MAP_COUNT" -lt 262144 ]; then
  echo ""
  echo "⚠  vm.max_map_count=$CURRENT_MAP_COUNT (minimum requis: 262144)"
  echo "   Elasticsearch risque de ne pas démarrer."
  echo "   Fix temporaire :  sudo sysctl -w vm.max_map_count=262144"
  echo "   Fix permanent  :  echo 'vm.max_map_count=262144' | sudo tee -a /etc/sysctl.conf"
else
  echo "✔ vm.max_map_count=$CURRENT_MAP_COUNT (OK)"
fi

echo ""
echo "Initialisation terminée. Lance : docker compose up -d"