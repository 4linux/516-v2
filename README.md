# Labs: Log Analytics - Da Auditoria à Análise com IA (516)

Ambiente de laboratório baseado em Vagrant + VirtualBox.

---

## Arquitetura de VMs

| VM           | IP           | RAM    | Ferramentas                                    |
|--------------|--------------|--------|------------------------------------------------|
| `containers` | 172.16.0.30  | 2 GB   | Docker, Fluent Bit, auditd, Python3            |
| `graylog`    | 172.16.0.10  | 3 GB   | MongoDB 8.0, OpenSearch 2.x, Graylog 7.1       |
| `opensearch` | 172.16.0.20  | 3 GB   | OpenSearch 2 + Dashboards (Docker)             |

**Importante:** só um backend fica ligado por vez (`graylog` **ou** `opensearch`), junto da VM `containers`, que gera os dados dos laboratórios. Nunca suba as três VMs ao mesmo tempo em um computador com 8 GB de RAM.

---

## Qual VM usar em cada módulo

| Módulo | Conteúdo                              | VM(s) necessária(s)          |
|--------|---------------------------------------|------------------------------|
| 01     | rsyslog, journald, logrotate          | `containers`                 |
| 02     | auditd, ausearch, aureport            | `containers`                 |
| 03     | Graylog (instalação e configuração)   | `graylog`                    |
| 04     | OpenSearch + Dashboards + ISM         | `opensearch`                 |
| 05     | Docker logging, Fluent Bit            | `containers` + `graylog` **ou** `containers` + `opensearch` |
| 06     | Logs na nuvem (GCP)                   | nenhuma (conta GCP do aluno) |
| 07     | Análise de logs com IA                | `containers` + `graylog` (LAB 7.3 complementar: `containers` + `opensearch`) |

---

## Pré-requisitos

- [VirtualBox](https://www.virtualbox.org/) 7.x
- [Vagrant](https://www.vagrantup.com/) 2.3+
- 8 GB de RAM (mínimo). Nunca rode as 3 VMs ao mesmo tempo
- Conexão com a internet durante o primeiro `vagrant up` (download de pacotes)

---

## Comandos essenciais

### Subir VMs

```bash
# Subir apenas uma VM (recomendado para economia de RAM)
vagrant up containers
vagrant up graylog
vagrant up opensearch

# Subir duas juntas (para labs que integram ferramentas)
vagrant up containers graylog
vagrant up containers opensearch
```

### Acessar uma VM

```bash
vagrant ssh containers
vagrant ssh graylog
vagrant ssh opensearch
```

### Desligar VMs

```bash
# Desligar todas
vagrant halt

# Desligar apenas uma
vagrant halt containers
```

### Destruir e recriar

```bash
# Destruir todas (libera disco)
vagrant destroy -f

# Destruir apenas uma
vagrant destroy -f graylog
```

### Status

```bash
vagrant status
```

---

## Detalhes de cada VM

### VM: containers (172.16.0.30)

Usada nos labs 01, 02, 05 e 07.

**Serviços instalados:**
- `docker`: ativo e iniciando com o sistema
- `fluent-bit`: instalado, mas parado e desabilitado. Cada laboratório grava a sua configuração e inicia o serviço
- `auditd`: ativo com regras básicas pré-carregadas
- Python 3 com a biblioteca `requests`

**Scripts disponíveis em `/home/vagrant/`:**
- `analisa-arquivo.py`: analisa logs locais com IA
- `analisa-graylog.py`: busca logs no Graylog e analisa com IA
- `analisa-opensearch.py`: busca logs no OpenSearch e analisa com IA
- `simula-incidente.sh`: gera eventos de segurança para o LAB 7.4

Os logs do sistema (`/var/log/syslog`, `/var/log/auth.log`, `/var/log/audit/audit.log`) só podem ser lidos pelo root. Nos laboratórios, eleve o privilégio com `sudo -i`.

**Portas:**
- Nenhuma porta encaminhada para o host (acesso via `vagrant ssh containers`)

---

### VM: graylog (172.16.0.10)

Usada nos labs 03, 05 (GELF) e 07.

O provision só prepara a VM. A instalação é feita no LAB 3.1 com o script `/home/vagrant/instala-graylog.sh`, que instala, sem Docker:
- `mongod`: MongoDB 8.0
- `opensearch`: OpenSearch 2.x (single-node, segurança desabilitada, só para uso do Graylog)
- `graylog-server`: Graylog Server 7.1

**Acesso:**
1. Acesse `http://172.16.0.10:9000` (ou `http://localhost:9000`) no navegador do host
2. Login: `admin` / `4Linux@516!`

**Inputs usados nos laboratórios** (criados no LAB 3.2):
- `Syslog UDP` na porta `5140`
- `GELF UDP` na porta `12201`

**Porta encaminhada para o host:**
- `9000`: interface web do Graylog

---

### VM: opensearch (172.16.0.20)

Usada nos labs 04, 05 (Fluent Bit → OpenSearch) e 07.

O provision só prepara a VM. A instalação é feita no LAB 4.1 com o script `/home/vagrant/instala-opensearch.sh`, que instala o Docker e sobe, via Docker Compose em `/opt/opensearch/`:
- `opensearch`: OpenSearch 2.x com HTTPS e autenticação (`admin` / `4Linux@516!`)
- `opensearch-dashboards`: interface web, em `http://172.16.0.20:5601`

**Comandos úteis dentro da VM:**

```bash
# Ver status
cd /opt/opensearch && docker compose ps

# Ver logs
cd /opt/opensearch && docker compose logs -f

# Reiniciar
cd /opt/opensearch && docker compose restart
```

**Portas encaminhadas para o host:**
- `9200`: API REST do OpenSearch (`https://`)
- `5601`: OpenSearch Dashboards

---

## Configuração da chave de API do Lab 07

O Lab 07 usa a API do OpenRouter para análise de logs com IA.

1. Crie uma conta gratuita em [openrouter.ai](https://openrouter.ai)
2. Gere a chave em **Workspaces → Default Workspace → API Keys → New Key** (não use as Management Keys)
3. Na VM `containers`, eleve o privilégio, entre na pasta dos scripts e exporte a chave:

```bash
sudo -i
cd /home/vagrant
export OPENROUTER_API_KEY="sk-or-v1-xxxxxxxxxxxxxxxxxxxxxxxx"
```

Para persistir entre sessões do root:

```bash
echo 'export OPENROUTER_API_KEY="sk-or-v1-xxx"' >> /root/.bashrc
```

Os scripts usam modelos gratuitos (sufixo `:free`). Para trocar o modelo preferido, exporte `OPENROUTER_MODEL` com o nome de outro modelo gratuito.

---

## Estrutura do diretório `labs/`

```
labs/
├── Vagrantfile                  # Definição das 3 VMs
├── README.md                    # Este arquivo
├── provision/
│   ├── containers.sh            # Provisionamento da VM containers
│   ├── graylog.sh               # Provisionamento da VM graylog
│   └── opensearch.sh            # Provisionamento da VM opensearch
├── lab-07/
│   ├── analisa-arquivo.py       # Script: análise de arquivo local com IA
│   ├── analisa-graylog.py       # Script: busca no Graylog + IA
│   └── analisa-opensearch.py    # Script: busca no OpenSearch + IA
└── scripts/
    ├── instala-graylog.sh       # Instalação do Graylog (LAB 3.1)
    ├── instala-opensearch.sh    # Instalação do OpenSearch + Dashboards (LAB 4.1)
    └── simula-incidente.sh      # Gerador de eventos de segurança (LAB 7.4)
```
