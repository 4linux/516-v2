#!/usr/bin/env bash
# =============================================================================
# provision/graylog.sh
# Prepara a VM do Graylog — a instalação dos serviços é feita pelo aluno
# via /home/vagrant/instala-graylog.sh durante o LAB 3.1
# =============================================================================
set -euo pipefail

# Fix: ubuntu/jammy64 cloud-init reseta o hostname a cada reboot
echo 'preserve_hostname: true' > /etc/cloud/cloud.cfg.d/99-hostname.conf
hostnamectl set-hostname graylog

# Fix: enp0s8 (private_network) fica DOWN no ubuntu/jammy64 — configurar via netplan
cat > /etc/netplan/99-private.yaml <<'EOF'
network:
  version: 2
  ethernets:
    enp0s8:
      addresses:
        - 172.16.0.10/24
EOF
chmod 600 /etc/netplan/99-private.yaml
netplan apply

echo "==> Atualizando o sistema..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get install -y -q \
  curl wget gnupg apt-transport-https ca-certificates \
  procps net-tools

# Parâmetro de kernel obrigatório para o OpenSearch — aplicado aqui pois
# precisa estar ativo antes da instalação
echo "==> Configurando vm.max_map_count..."
echo 'vm.max_map_count=262144' > /etc/sysctl.d/99-opensearch.conf
sysctl -w vm.max_map_count=262144

# Fix: habilita autenticação por senha (sshd_config.d tem prioridade no Jammy)
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config.d/*.conf 2>/dev/null || true
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart ssh

# -----------------------------------------------------------------------------
# Usuário suporte
# -----------------------------------------------------------------------------
useradd -m -s /bin/bash suporte
echo 'suporte:4linux@123' | chpasswd
usermod -aG sudo suporte

# -----------------------------------------------------------------------------
# Copia o script de instalação para o home do vagrant
# -----------------------------------------------------------------------------
if [ -f /vagrant/scripts/instala-graylog.sh ]; then
  cp /vagrant/scripts/instala-graylog.sh /home/vagrant/
  chown vagrant:vagrant /home/vagrant/instala-graylog.sh
  chmod +x /home/vagrant/instala-graylog.sh
fi

# -----------------------------------------------------------------------------
# Conclusão
# -----------------------------------------------------------------------------
echo ""
echo "============================================================"
echo " VM Graylog pronta!"
echo "============================================================"
echo ""
echo " Para instalar o Graylog, execute dentro da VM:"
echo "   bash ~/instala-graylog.sh"
echo ""
echo " Rede:"
echo "   IP desta VM: $(ip -4 addr show enp0s8 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || echo '172.16.0.10')"
echo "============================================================"
