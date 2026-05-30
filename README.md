<h1 align="center">LogixAI Agent</h1>

<p align="center">
  Agente de monitoramento de infraestrutura Windows/Linux com coleta automatizada, backup e análise de dados — desenvolvido para a Logix Brasil Ltda.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=flat-square&logo=powershell&logoColor=white" />
  <img src="https://img.shields.io/badge/Bash-Ubuntu_24-4EAA25?style=flat-square&logo=gnubash&logoColor=white" />
  <img src="https://img.shields.io/badge/Python-3.x-3776AB?style=flat-square&logo=python&logoColor=white" />
  <img src="https://img.shields.io/badge/Nginx-009639?style=flat-square&logo=nginx&logoColor=white" />
  <img src="https://img.shields.io/badge/Samba-file_share-red?style=flat-square" />
  <img src="https://img.shields.io/badge/Databricks-análise_simulada-FF3621?style=flat-square&logo=databricks&logoColor=white" />
  <img src="https://img.shields.io/badge/status-academic-lightgrey?style=flat-square" />
</p>

---

## 📖 Sobre o projeto

O **LogixAI Agent** é um sistema de monitoramento de infraestrutura corporativa que coleta métricas de estações Windows, envia os dados via SCP para um servidor central Linux, executa backup automatizado com retenção e analisa os dados em busca de alertas críticos (CPU, disco, erros de sistema, serviços parados).

O projeto simula um ambiente de TI real com segmentação por departamentos, controle de acesso LGPD, firewall e compartilhamento Samba — rodando em **KillerCoda Ubuntu Playground** como servidor central.

Projeto acadêmico desenvolvido em Engenharia da Computação.

---

## 🏗️ Arquitetura

```
┌─────────────────────────────────┐
│  Estações Windows (por depto.)  │
│  agente.ps1 — Task Scheduler    │
│  Coleta: CPU, RAM, Disco,       │
│  Serviços, Erros, Hotfixes      │
│  Envio: SCP com retry (3x)      │
└────────────┬────────────────────┘
             │ SCP → /srv/logix/{dept}/coletas/
             ▼
┌────────────────────────────────────────────────────┐
│  Servidor Central (Ubuntu — KillerCoda)            │
│                                                    │
│  /srv/logix/                                       │
│  ├── rh/          (750 — grp_rh, LGPD)            │
│  ├── financeiro/  (750 — grp_financeiro)           │
│  ├── ti/          (755 — grp_ti, auditoria)        │
│  ├── operacoes/   (750 — grp_ti)                   │
│  ├── backups/     (tar.gz com timestamp)           │
│  └── nuvem_simulada/ (simula bucket de nuvem)      │
│                                                    │
│  servidor.sh — cron 02:00                          │
│  ├── organiza CSVs por departamento                │
│  ├── gera backup_YYYY-MM-DD.tar.gz                 │
│  ├── "envia" para nuvem simulada                   │
│  └── retenção: apaga backups > 7 dias              │
│                                                    │
│  Nginx   — portal web de status (porta 80)         │
│  Samba   — compartilhamento por grupo (porta 445)  │
│  UFW     — firewall: 22, 80, 139, 445              │
└────────────────────────────────────────────────────┘
             │
             ▼
┌────────────────────────────────┐
│  Análise de Dados (Python)     │
│  analise_coletas.py            │
│  Simulação de pipeline         │
│  Databricks / Azure Data Lake  │
│  Alertas: CPU > 80%, disco     │
│  < 10GB, erros > 10/24h        │
└────────────────────────────────┘
```

---

## ✨ Funcionalidades

**Agente Windows (`agente.ps1`)**
- Coleta por hora via Task Scheduler: CPU, RAM, disco, IP, serviços parados, hotfixes, erros do Event Viewer (últimas 24h)
- Exporta CSV com timestamp e envia via SCP para o servidor Linux
- Retry automático com backoff progressivo (15s, 30s)
- Log local de falhas em `%TEMP%\logixai_erros.log`

**Servidor central (Bash)**
- Estrutura de diretórios segmentada por departamento com permissões LGPD
- Grupos e usuários de serviço separados (`grp_rh`, `grp_financeiro`, `grp_ti`, `grp_auditoria`)
- Backup diário com `tar.gz` + timestamp e retenção de 7 dias
- Simulação de envio para nuvem (pronto para substituir `cp` por `az storage blob upload`)
- Firewall UFW, Samba por grupo e Nginx com portal de status

**Análise de dados (Python)**
- Pipeline de análise sobre CSVs coletados (ou dados simulados em modo demo)
- Métricas por departamento: CPU média/máxima, disco mínimo, erros acumulados
- Detecção de alertas CRÍTICO / ATENÇÃO por estação
- Relatório salvo em `/var/log/logixai/relatorio_databricks.txt`
- Preparado para migração ao Databricks (`spark.read.csv`) e Azure Data Lake

---

## 🛠️ Stack

| Camada | Tecnologia |
|---|---|
| Agente de coleta | PowerShell 5.1+, WMI/CIM, OpenSSH (SCP) |
| Servidor central | Bash, Ubuntu 24, UFW, Samba, Nginx |
| Análise de dados | Python 3, pandas |
| Infraestrutura simulada | KillerCoda Ubuntu Playground |
| Nuvem (produção futura) | Azure Data Lake, Databricks, `az` CLI |

---

## 🚀 Como rodar (servidor — KillerCoda)

### Passo a passo completo

```bash
# 1. Clonar o repositório
apt-get install -y git
git clone https://github.com/Julyxdias/System.git
cd System && git checkout Scripts

# 2. Estrutura de pastas e permissões
sudo bash 01_estrutura_permissoes.sh

# 3. Firewall, Samba e Nginx
sudo bash 02_firewall_samba_nginx.sh

# 4. Rodar o servidor de coleta/backup
sudo cp servidor.sh /srv/logix/servidor.sh
sudo bash /srv/logix/servidor.sh

# 5. Análise de dados (cria e executa o script Python)
# Veja o Passo 6 completo em Logix.sh

# 6. Pegar o IP para configurar o agente.ps1
ip addr show enp1s0 | grep 'inet '
```

### Agendar via cron (produção)

```bash
# Backup diário às 02:00
echo "0 2 * * * bash /srv/logix/servidor.sh" | sudo crontab -
```

---

## 💻 Agente Windows

```powershell
# Executar manualmente
.\agente.ps1 -ServidorIP "IP_DO_SERVIDOR" -Departamento "financeiro"

# Departamentos válidos: rh | financeiro | ti | operacoes
```

Para agendar via Task Scheduler (1x/hora):

```
Ação: PowerShell.exe -ExecutionPolicy Bypass -File "C:\LogixAI\agente.ps1" -ServidorIP "SEU_IP" -Departamento "ti"
```

---

## 📁 Estrutura do repositório

```
System/
└── Scripts/
    ├── 01_estrutura_permissoes.sh   # Cria diretórios, grupos e permissões
    ├── 02_firewall_samba_nginx.sh   # Configura UFW, Samba e Nginx
    ├── servidor.sh                  # Backup, retenção e envio à nuvem
    ├── agente.ps1                   # Coleta de métricas Windows + SCP
    └── Logix.sh                     # Guia passo a passo de execução completa
```

---

## 🔐 Segurança e conformidade LGPD

| Diretório | Permissão | Grupo | Observação |
|---|---|---|---|
| `/srv/logix/rh` | 750 | `grp_rh` | Dado sensível — acesso mínimo |
| `/srv/logix/financeiro` | 750 | `grp_financeiro` | Acesso restrito |
| `/srv/logix/ti` | 755 | `grp_ti` | Auditoria pode ler, sem escrita |
| `/srv/logix/operacoes` | 750 | `grp_ti` | Operações gerenciadas pela TI |

Samba configurado com `valid users` por grupo — sem acesso anônimo. Dado de `UltimoLogin` no agente é coletado mas segregado por departamento (conformidade LGPD).

---

## 📊 Alertas detectados pela análise

| Nível | Condição |
|---|---|
| CRÍTICO | CPU média > 80% |
| CRÍTICO | Disco livre < 10 GB |
| ATENÇÃO | Serviços parados > 3 |
| ATENÇÃO | Erros de sistema > 10/24h |

---

## 🔭 Evolução prevista (produção)

- Substituir `cp` por `az storage blob upload` → Azure Data Lake real
- Migrar `analise_coletas.py` para notebook Databricks com `spark.read.csv`
- Dashboard dinâmico com Flask/FastAPI servido pelo Nginx
- Alertas via e-mail ou Teams webhook

---

## 👩‍💻 Autora

Desenvolvido por **[Julyxdias](https://github.com/Julyxdias)** — Engenharia da Computação.

---

<p align="center"><sub>Projeto acadêmico • Logix Brasil Ltda. • 2025</sub></p>
