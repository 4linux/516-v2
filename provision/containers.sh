#!/usr/bin/env bash
# =============================================================================
# provision/containers.sh
# Instala Docker, Fluent Bit, auditd e Python na VM de containers
# Usada nos Labs: 01, 02, 05 e 07
# =============================================================================
set -euo pipefail

# Fix: ubuntu/jammy64 cloud-init reseta o hostname a cada reboot
echo 'preserve_hostname: true' > /etc/cloud/cloud.cfg.d/99-hostname.conf
hostnamectl set-hostname containers

# Fix: enp0s8 (private_network) fica DOWN no ubuntu/jammy64 — configurar via netplan
cat > /etc/netplan/99-private.yaml <<'EOF'
network:
  version: 2
  ethernets:
    enp0s8:
      addresses:
        - 172.16.0.30/24
EOF
chmod 600 /etc/netplan/99-private.yaml
netplan apply

echo "==> Atualizando o sistema..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get install -y -q \
  curl wget gnupg apt-transport-https ca-certificates \
  auditd audispd-plugins \
  rsyslog \
  python3 python3-pip \
  netcat-openbsd \
  jq

# -----------------------------------------------------------------------------
# Docker
# -----------------------------------------------------------------------------
echo "==> Instalando Docker..."
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

# Configura limite de tamanho dos logs dos containers (boa prática)
cat > /etc/docker/daemon.json <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
systemctl restart docker

# -----------------------------------------------------------------------------
# Fluent Bit
# -----------------------------------------------------------------------------
echo "==> Instalando Fluent Bit..."
curl -fsSL https://raw.githubusercontent.com/fluent/fluent-bit/master/install.sh | sh

# Instalado, mas desabilitado e parado. O serviço só sobe quando o aluno
# grava a configuração do lab (4.2, 5.2 ou 5.3) e roda systemctl start/restart.
# Não é habilitado no boot para a config de um lab não vazar para o seguinte.
systemctl disable --now fluent-bit 2>/dev/null || true
mkdir -p /var/lib/fluent-bit

# Guarda a config de exemplo do pacote (input cpu -> stdout) e deixa só um aviso
if [ -f /etc/fluent-bit/fluent-bit.conf ] && [ ! -f /etc/fluent-bit/fluent-bit.conf.pacote ]; then
  mv /etc/fluent-bit/fluent-bit.conf /etc/fluent-bit/fluent-bit.conf.pacote
fi
cat > /etc/fluent-bit/fluent-bit.conf <<'EOF'
# Arquivo vazio de propósito.
# O conteúdo é gravado em cada laboratório (LAB 4.2, 5.2 e 5.3) da apostila.
EOF

# -----------------------------------------------------------------------------
# auditd — para labs 01 e 02
# -----------------------------------------------------------------------------
echo "==> Habilitando auditd..."
systemctl enable auditd
systemctl start auditd

# Regras básicas de auditoria para os labs
cat > /etc/audit/rules.d/auditoria-labs.rules <<'EOF'
# Monitoramento de arquivos críticos
-w /etc/passwd  -p rwa -k monitoramento-passwd
-w /etc/shadow  -p rwa -k monitoramento-shadow
-w /etc/sudoers -p rwa -k monitoramento-sudoers
-w /usr/bin/sudo -p x  -k uso-sudo
EOF

augenrules --load

# -----------------------------------------------------------------------------
# Python — biblioteca requests para lab-07
# -----------------------------------------------------------------------------
echo "==> Instalando dependências Python..."
pip3 install --quiet requests

# Copia scripts do lab-07 para /home/vagrant
if [ -d /vagrant/lab-07 ]; then
  cp /vagrant/lab-07/*.py /home/vagrant/
  chown vagrant:vagrant /home/vagrant/*.py
  chmod +x /home/vagrant/*.py
fi

# Copia script de simulação de incidente
if [ -f /vagrant/scripts/simula-incidente.sh ]; then
  cp /vagrant/scripts/simula-incidente.sh /home/vagrant/
  chown vagrant:vagrant /home/vagrant/simula-incidente.sh
  chmod +x /home/vagrant/simula-incidente.sh
fi

# -----------------------------------------------------------------------------
# Usuário suporte
# -----------------------------------------------------------------------------
useradd -m -s /bin/bash suporte
echo 'suporte:4linux@123' | chpasswd
usermod -aG sudo suporte

# -----------------------------------------------------------------------------
# Conclusão
# -----------------------------------------------------------------------------
echo ""
echo "============================================================"
echo " Instalação concluída!"
echo "============================================================"
echo ""
echo " Serviços:"
echo "   Docker:    $(systemctl is-active docker)"
echo "   Fluent Bit: $(systemctl is-active fluent-bit) (sobe só nos labs)"
echo "   auditd:    $(systemctl is-active auditd)"
echo ""
echo " Python:"
echo "   $(python3 --version)"
echo "   requests: $(pip3 show requests | grep Version)"
echo ""
echo " Rede:"
echo "   IP desta VM: $(ip -4 addr show enp0s8 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || echo '172.16.0.30')"
echo "   Graylog:     172.16.0.10:9000"
echo "   OpenSearch:  172.16.0.20:9200"
echo "============================================================"
