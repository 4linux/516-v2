# =============================================================================
# Vagrantfile — Auditoria de Logs 516
# =============================================================================
# VMs disponíveis:
#   graylog    — Graylog Open 7.1 (instalação nativa) | 172.16.0.10
#   opensearch — OpenSearch + Dashboards (Docker)     | 172.16.0.20
#   containers — Docker + Fluent Bit (labs 01, 02, 05, 07) | 172.16.0.30
#
# Uso recomendado (nunca subir as 3 ao mesmo tempo em 8GB de RAM):
#   vagrant up containers graylog      # Labs 01, 02, 03, 05, 07
#   vagrant up containers opensearch   # Labs 04, 05, 07
#
# Comandos úteis:
#   vagrant up <vm>        — inicializa e provisiona a VM
#   vagrant halt <vm>      — desliga a VM
#   vagrant ssh <vm>       — acessa a VM via SSH
#   vagrant destroy <vm>   — remove a VM completamente
# =============================================================================

Vagrant.configure("2") do |config|

  # ---------------------------------------------------------------------------
  # VM: graylog — Graylog Open 7.1 (instalação nativa)
  # Usar nos Labs: 03 (Graylog), 05 (Containers → Graylog)
  # ---------------------------------------------------------------------------
  config.vm.define "graylog" do |graylog|
    graylog.vm.box      = "ubuntu/jammy64"
    graylog.vm.hostname = "graylog"

    graylog.vm.network "private_network", ip: "172.16.0.10"
    graylog.vm.network "forwarded_port", guest: 9000,  host: 9000   # Interface web

    graylog.vm.provider "virtualbox" do |vb|
      vb.name   = "516-graylog"
      vb.memory = "3072"
      vb.cpus   = 2
    end

    graylog.vm.provision "shell", path: "provision/graylog.sh"
  end

  # ---------------------------------------------------------------------------
  # VM: opensearch — OpenSearch + OpenSearch Dashboards (Docker)
  # Usar nos Labs: 04 (OpenSearch), 05 (Containers → OpenSearch)
  # ---------------------------------------------------------------------------
  config.vm.define "opensearch" do |os_vm|
    os_vm.vm.box      = "ubuntu/jammy64"
    os_vm.vm.hostname = "opensearch"

    os_vm.vm.network "private_network", ip: "172.16.0.20"
    os_vm.vm.network "forwarded_port", guest: 9200, host: 9200  # API OpenSearch
    os_vm.vm.network "forwarded_port", guest: 5601, host: 5601  # OpenSearch Dashboards

    os_vm.vm.provider "virtualbox" do |vb|
      vb.name   = "516-opensearch"
      vb.memory = "3072"
      vb.cpus   = 2
    end

    os_vm.vm.provision "shell", path: "provision/opensearch.sh"
  end

  # ---------------------------------------------------------------------------
  # VM: containers — Docker + Fluent Bit + Python
  # Usar nos Labs: 01, 02, 05 (coleta de containers) e 07 (IA)
  # ---------------------------------------------------------------------------
  config.vm.define "containers" do |ct|
    ct.vm.box      = "ubuntu/jammy64"
    ct.vm.hostname = "containers"

    ct.vm.network "private_network", ip: "172.16.0.30"

    ct.vm.provider "virtualbox" do |vb|
      vb.name   = "516-containers"
      vb.memory = "2048"
      vb.cpus   = 2
    end

    ct.vm.provision "shell", path: "provision/containers.sh"
  end

end
