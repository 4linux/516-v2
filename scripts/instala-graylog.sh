#!/usr/bin/env bash
# =============================================================================
# instala-graylog.sh
# Instala MongoDB 8.0 + OpenSearch 2.x + Graylog Open 7.1 no Ubuntu 22.04
# Curso 516 — Auditoria de Logs · 4Linux
# =============================================================================
set -euo pipefail

ADMIN_PASSWORD="4Linux@516!"
ADMIN_PASSWORD_SHA2=$(echo -n "$ADMIN_PASSWORD" | sha256sum | cut -d' ' -f1)
PASSWORD_SECRET=$(openssl rand -hex 48)
MONGODB_URI="mongodb://127.0.0.1:27017/graylog"

export DEBIAN_FRONTEND=noninteractive

echo ""
echo "============================================================"
echo " Instalação do Graylog Open 7.1"
echo " MongoDB 8.0 + OpenSearch 2.x + Graylog Server"
echo "============================================================"
echo ""

# -----------------------------------------------------------------------------
# MongoDB 8.0
# -----------------------------------------------------------------------------
echo "==> [1/4] Instalando MongoDB 8.0..."

curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc \
  | gpg --batch --yes --dearmor -o /usr/share/keyrings/mongodb-server-8.0.gpg

echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] \
  https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/8.0 multiverse" \
  | tee /etc/apt/sources.list.d/mongodb-org-8.0.list

apt-get update -q
apt-get install -y -q mongodb-org
apt-mark hold mongodb-org

systemctl enable mongod
systemctl start mongod

echo "==> Aguardando MongoDB iniciar..."
timeout 30 bash -c 'until mongosh --quiet --eval "db.runCommand({ping:1})" &>/dev/null; do sleep 2; done'
echo "==> MongoDB OK."

# -----------------------------------------------------------------------------
# OpenSearch 2.x
# -----------------------------------------------------------------------------
echo ""
echo "==> [2/4] Instalando OpenSearch 2.x..."

curl -fsSL https://artifacts.opensearch.org/publickeys/opensearch.pgp \
  | gpg --dearmor --batch --yes -o /usr/share/keyrings/opensearch-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/opensearch-keyring.gpg] \
  https://artifacts.opensearch.org/releases/bundle/opensearch/2.x/apt stable main" \
  | tee /etc/apt/sources.list.d/opensearch-2.x.list

apt-get update -q
OPENSEARCH_INITIAL_ADMIN_PASSWORD="4Linux@516!" DISABLE_INSTALL_DEMO_CONFIG=true \
  apt-get install -y -q opensearch

# Configuração single-node sem segurança (ambiente de lab)
cat > /etc/opensearch/opensearch.yml <<'EOF'
cluster.name: graylog
node.name: graylog-node-1
network.host: 127.0.0.1
discovery.type: single-node
plugins.security.disabled: true
EOF

# Heap: 1g (ambiente de lab com 3 GB de RAM)
sed -i 's/^-Xms.*/-Xms1g/' /etc/opensearch/jvm.options
sed -i 's/^-Xmx.*/-Xmx1g/' /etc/opensearch/jvm.options

systemctl enable opensearch
systemctl start opensearch

echo "==> Aguardando OpenSearch iniciar (pode levar até 2 minutos)..."
timeout 120 bash -c \
  'until curl -s http://127.0.0.1:9200/_cluster/health 2>/dev/null | grep -q "status"; do sleep 5; done' \
  && echo "==> OpenSearch OK." \
  || echo "==> AVISO: OpenSearch não respondeu em 2 minutos — verifique com: journalctl -u opensearch -n 30"

# -----------------------------------------------------------------------------
# Graylog Server 7.1
# -----------------------------------------------------------------------------
echo ""
echo "==> [3/4] Instalando Graylog Server 7.1..."

wget -q https://packages.graylog2.org/repo/packages/graylog-7.1-repository_latest.deb \
  -O /tmp/graylog-repo.deb
dpkg -i /tmp/graylog-repo.deb
apt-get update -q
apt-get install -y -q graylog-server

# Configuração principal
sed -i "s|^password_secret =.*|password_secret = ${PASSWORD_SECRET}|" \
  /etc/graylog/server/server.conf
sed -i "s|^root_password_sha2 =.*|root_password_sha2 = ${ADMIN_PASSWORD_SHA2}|" \
  /etc/graylog/server/server.conf
sed -i "s|^#\?http_bind_address =.*|http_bind_address = 0.0.0.0:9000|" \
  /etc/graylog/server/server.conf
sed -i "s|^mongodb_uri =.*|mongodb_uri = ${MONGODB_URI}|" \
  /etc/graylog/server/server.conf
sed -i "s|^#\?elasticsearch_hosts =.*|elasticsearch_hosts = http://127.0.0.1:9200|" \
  /etc/graylog/server/server.conf

# Heap: 512m (VM com 3 GB dividida entre 3 serviços)
if [ -f /etc/graylog/server/jvm.options ]; then
  sed -i 's/^-Xms.*/-Xms512m/' /etc/graylog/server/jvm.options
  sed -i 's/^-Xmx.*/-Xmx512m/' /etc/graylog/server/jvm.options
elif [ -f /etc/default/graylog-server ]; then
  sed -i 's/-Xms[0-9]*[mg]/-Xms512m/g' /etc/default/graylog-server
  sed -i 's/-Xmx[0-9]*[mg]/-Xmx512m/g' /etc/default/graylog-server
fi

systemctl enable graylog-server
systemctl start graylog-server

# -----------------------------------------------------------------------------
# Verificação final
# -----------------------------------------------------------------------------
echo ""
echo "==> [4/4] Verificando serviços..."

echo "==> Aguardando Graylog Server iniciar (pode levar até 2 minutos)..."
timeout 120 bash -c \
  'until curl -s http://127.0.0.1:9000/api/system/lbstatus 2>/dev/null | grep -q "ALIVE"; do sleep 5; done' \
  && echo "==> Graylog Server OK." \
  || echo "==> AVISO: Graylog não respondeu — verifique com: tail -30 /var/log/graylog-server/server.log"

echo ""
echo "============================================================"
echo " Instalação concluída!"
echo "============================================================"
echo ""
echo " Serviços:"
echo "   MongoDB:        $(systemctl is-active mongod)"
echo "   OpenSearch:     $(systemctl is-active opensearch)"
echo "   Graylog Server: $(systemctl is-active graylog-server)"
echo ""
echo " Acesso:"
echo "   URL:    http://172.16.0.10:9000"
echo "   Login:  admin / ${ADMIN_PASSWORD}"
echo "============================================================"
