#!/usr/bin/env bash
# =============================================================================
# instala-opensearch.sh
# Instala Docker e sobe OpenSearch 2.x + OpenSearch Dashboards via Docker Compose
# Curso 516 — Auditoria de Logs · 4Linux
# =============================================================================
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

echo ""
echo "============================================================"
echo " Instalação do OpenSearch + OpenSearch Dashboards"
echo " Docker + Docker Compose"
echo "============================================================"
echo ""

# -----------------------------------------------------------------------------
# Docker
# -----------------------------------------------------------------------------
echo "==> [1/3] Instalando Docker..."

curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | gpg --batch --yes --dearmor -o /usr/share/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  | tee /etc/apt/sources.list.d/docker.list

apt-get update -q
apt-get install -y -q docker-ce docker-ce-cli containerd.io docker-compose-plugin

systemctl enable docker
systemctl start docker
usermod -aG docker vagrant

echo "==> Docker OK."

# -----------------------------------------------------------------------------
# Docker Compose para OpenSearch
# -----------------------------------------------------------------------------
echo ""
echo "==> [2/3] Criando ambiente Docker Compose..."

mkdir -p /opt/opensearch

cat > /opt/opensearch/docker-compose.yml <<'EOF'
services:

  opensearch:
    image: opensearchproject/opensearch:2
    restart: unless-stopped
    environment:
      - discovery.type=single-node
      - OPENSEARCH_JAVA_OPTS=-Xms1g -Xmx1g
      - OPENSEARCH_INITIAL_ADMIN_PASSWORD=4Linux@516!
    ulimits:
      memlock:
        soft: -1
        hard: -1
      nofile:
        soft: 65536
        hard: 65536
    ports:
      - "9200:9200"
    volumes:
      - opensearch_data:/usr/share/opensearch/data

  opensearch-dashboards:
    image: opensearchproject/opensearch-dashboards:2
    restart: unless-stopped
    depends_on:
      - opensearch
    environment:
      - OPENSEARCH_HOSTS=https://opensearch:9200
      - OPENSEARCH_USERNAME=admin
      - OPENSEARCH_PASSWORD=4Linux@516!
      - OPENSEARCH_SSL_VERIFICATIONMODE=none
    ports:
      - "5601:5601"

volumes:
  opensearch_data:
EOF

echo "==> docker-compose.yml criado em /opt/opensearch/"

# -----------------------------------------------------------------------------
# Subindo os containers
# -----------------------------------------------------------------------------
echo ""
echo "==> [3/3] Baixando imagens e iniciando containers..."
echo "    (o download das imagens pode levar alguns minutos)"
echo ""

cd /opt/opensearch
docker compose up -d

echo ""
echo "==> Aguardando OpenSearch iniciar (pode levar até 2 minutos)..."
timeout 120 bash -c \
  'until curl -sk -u admin:4Linux@516! https://127.0.0.1:9200/_cluster/health 2>/dev/null | grep -q "status"; do sleep 5; done' \
  && echo "==> OpenSearch OK." \
  || echo "==> AVISO: OpenSearch ainda inicializando — verifique com: docker compose logs opensearch"

# -----------------------------------------------------------------------------
# Conclusão
# -----------------------------------------------------------------------------
echo ""
echo "============================================================"
echo " Instalação concluída!"
echo "============================================================"
echo ""
echo " Containers:"
docker compose ps --format "  {{.Name}}: {{.Status}}"
echo ""
echo " Acesso:"
echo "   OpenSearch API:        https://172.16.0.20:9200"
echo "   OpenSearch Dashboards: http://172.16.0.20:5601"
echo "   Login: admin / 4Linux@516!"
echo "============================================================"
