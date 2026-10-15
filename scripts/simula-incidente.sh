#!/usr/bin/env bash
# =============================================================================
# simula-incidente.sh
# Simula um incidente de segurança para o LAB 7.4
# Gera eventos de: tentativas de login, acesso a arquivos críticos,
# criação de usuário não autorizado e tentativa de escalonamento de privilégio
# =============================================================================

echo "[*] Iniciando simulação de incidente..."
sleep 1

# 1. Tentativas de autenticação com falha
echo "[*] Simulando tentativas de login com falha..."
for i in {1..5}; do
  su - usuario_atacante -c "whoami" 2>/dev/null || true
  sleep 1
done
logger -p auth.warning "pam_unix(sshd:auth): authentication failure; logname= uid=0 euid=0 tty=ssh ruser= rhost=192.168.100.50 user=root"
logger -p auth.warning "pam_unix(sshd:auth): authentication failure; logname= uid=0 euid=0 tty=ssh ruser= rhost=192.168.100.50 user=admin"
logger -p auth.warning "pam_unix(sshd:auth): authentication failure; logname= uid=0 euid=0 tty=ssh ruser= rhost=192.168.100.50 user=vagrant"

# 2. Acesso a arquivos críticos
echo "[*] Simulando acesso a arquivos críticos..."
cat /etc/passwd > /dev/null
cat /etc/group > /dev/null
logger -p auth.notice "Acesso ao arquivo /etc/shadow detectado pelo processo bash (uid=1000)"
logger -p auth.notice "Tentativa de leitura de /etc/sudoers por usuario nao privilegiado"

# 3. Escalonamento de privilégio via sudo
echo "[*] Simulando uso indevido de sudo..."
logger -p auth.info "sudo: vagrant : TTY=pts/0 ; PWD=/home/vagrant ; USER=root ; COMMAND=/bin/bash"
logger -p auth.info "sudo: vagrant : TTY=pts/0 ; PWD=/home/vagrant ; USER=root ; COMMAND=/usr/bin/passwd root"

# 4. Criação de usuário não autorizado
echo "[*] Simulando criação de usuário não autorizado..."
useradd -m -s /bin/bash usuario_suspeito 2>/dev/null || true
logger -p auth.notice "useradd: novo usuario criado: usuario_suspeito (uid=1002, gid=1002)"
logger -p auth.warning "Criacao de usuario nao autorizado detectada: usuario_suspeito"

# 5. Varredura de portas e conexões suspeitas
echo "[*] Simulando atividade de rede suspeita..."
logger -p kern.warning "iptables: conexao bloqueada de 192.168.100.50:4444 para 172.16.0.30:22"
logger -p kern.warning "iptables: conexao bloqueada de 192.168.100.50:4444 para 172.16.0.30:3306"
logger -p kern.warning "iptables: conexao bloqueada de 192.168.100.50:4444 para 172.16.0.30:5432"

# 6. Eventos de erro de aplicação
echo "[*] Gerando erros de aplicação..."
for i in {1..5}; do
  logger -p user.err "app[9999]: ERRO CRITICO - falha ao conectar ao banco de dados: connection refused (tentativa $i)"
  sleep 1
done

# 7. Remoção do usuário criado (limpeza parcial)
userdel -r usuario_suspeito 2>/dev/null || true
logger -p auth.notice "userdel: usuario removido: usuario_suspeito"

echo ""
echo "============================================================"
echo " Simulação concluída!"
echo " Eventos gerados em /var/log/syslog e /var/log/auth.log"
echo " Aguarde 30 segundos para os logs chegarem ao Graylog"
echo " e então execute os scripts de análise com IA."
echo "============================================================"
