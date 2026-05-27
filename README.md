# LogixAI Agent

**Agente inteligente de automação e gestão de infraestrutura**  
Consultoria de TI para a Logix Brasil Ltda. — Disciplina: Sistemas Operacionais  
SENAC São Paulo · Engenharia de Computação · Prof. Rafael S Novo Pereira

---

## Sobre o projeto

O LogixAI Agent é uma solução de infraestrutura desenvolvida para modernizar o ambiente de TI da Logix Brasil Ltda., empresa brasileira com 180 colaboradores e ambiente híbrido Linux/Windows.

A solução resolve seis problemas críticos identificados no diagnóstico:

- Arquivos compartilhados sem estrutura departamental
- Ausência de controle de permissões e grupos de acesso
- Impossibilidade de auditoria rastreável
- Estações Windows sem monitoramento automatizado
- Backups inconsistentes e manuais
- Exposição a riscos da LGPD (Lei 13.709/2018)

---

## Arquitetura

```
Estações Windows (agente.ps1)
        ↓  SCP / SSH porta 22
Servidor Central Linux (/srv/logix/)
        ↓  servidor.sh + cron
Backup tar.gz + nuvem_simulada/  →  Azure Blob Storage (produção)
        ↓
analise_coletas.py  →  Databricks (analytics)
```

---

## Estrutura do repositório

```
System/
├── 01_estrutura_permissoes.sh    # Cria diretórios, grupos Unix e permissões
├── 02_firewall_samba_nginx.sh    # Configura UFW, Samba e Nginx
├── servidor.sh                   # Organiza coletas e executa backup com timestamp
├── agente.ps1                    # Agente de coleta PowerShell (estações Windows)
└── README.md
```

---

## Scripts

### `01_estrutura_permissoes.sh`
Cria a estrutura departamental no servidor Linux e aplica permissões conforme a política de acesso da Logix Brasil.

```bash
sudo bash 01_estrutura_permissoes.sh
```

**O que faz:**
- Cria `/srv/logix/{rh,financeiro,ti,operacoes}/{documentos,coletas,backups}`
- Cria grupos Unix: `grp_rh`, `grp_financeiro`, `grp_ti`, `grp_auditoria`
- Aplica `chmod 750` nos departamentos sensíveis (RH, Financeiro)
- Aplica `chmod 755` no diretório de TI (auditoria sem escrita)
- Idempotente: pode ser re-executado sem erros

---

### `02_firewall_samba_nginx.sh`
Configura os serviços de rede do servidor central.

```bash
sudo bash 02_firewall_samba_nginx.sh
```

**O que faz:**
- UFW: libera portas 22 (SSH), 80 (Nginx), 139 e 445 (Samba)
- Nginx: instala e sobe página de status em `/var/www/html/` — base do portal futuro
- Samba: configura compartilhamentos por departamento com `valid users` por grupo
- Valida `smb.conf` com `testparm -s` antes de reiniciar o serviço

---

### `servidor.sh`
Script central do servidor. Executado via `cron` diariamente.

```bash
sudo bash /srv/logix/servidor.sh
```

**O que faz:**
1. Verifica coletas CSV recebidas em cada departamento
2. Gera backup compactado com timestamp: `backup_YYYY-MM-DD_HH-MM.tar.gz`
3. Copia backup para `/srv/logix/nuvem_simulada/` (representa Azure Blob em produção)
4. Aplica retenção de 7 dias (`find -mtime +7 -delete`)
5. Registra tudo em `/var/log/logixai/servidor.log`

**Em produção, substituir a linha de cópia por:**
```bash
az storage blob upload --file backup.tar.gz --container logixai
```

---

### `agente.ps1`
Agente de coleta PowerShell para estações Windows 10/11.

```powershell
.\agente.ps1 -ServidorIP "IP_DO_SERVIDOR" -Departamento "financeiro"
```

**O que coleta:**
| Métrica | Cmdlet |
|---|---|
| CPU (%) | `Get-CimInstance Win32_Processor` |
| RAM total e livre (GB) | `Win32_ComputerSystem` + `Win32_OperatingSystem` |
| Disco livre C: (GB) | `Get-PSDrive C` |
| IP local | `Get-NetIPAddress` |
| Serviços automáticos parados | `Get-Service` |
| Updates instalados | `Get-HotFix` |
| Último login | `Get-LocalUser` |
| Erros de sistema (24h) | `Get-WinEvent` |

**Mecanismo de envio:**
- Exporta para CSV via `Export-Csv`
- Envia via SCP (OpenSSH nativo do Windows)
- Retry automático: 3 tentativas com espera progressiva (15s, 30s)
- Em caso de falha definitiva: arquivo mantido localmente + log de erro

**Agendar execução (1x/hora via Task Scheduler):**
```powershell
$action  = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-File C:\logix\agente.ps1"
$trigger = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Hours 1) -Once -At (Get-Date)
Register-ScheduledTask -TaskName "LogixAI-Agente" -Action $action -Trigger $trigger -RunLevel Highest
```

---

## Como executar no KillerCoda

```bash
# 1. Instalar git (se necessário)
apt-get install -y git

# 2. Clonar o repositório
git clone https://github.com/Julyxdias/System.git
cd System
git checkout Scripts

# 3. Executar na ordem
sudo bash 01_estrutura_permissoes.sh
sudo bash 02_firewall_samba_nginx.sh
sudo cp servidor.sh /srv/logix/servidor.sh
sudo bash /srv/logix/servidor.sh

# 4. Verificar resultados
ls -lh /srv/logix/backups/
cat /var/log/logixai/servidor.log
ip addr show enp1s0 | grep 'inet '
```

---

## Decisões técnicas

| Decisão | Escolha | Motivo |
|---|---|---|
| Estrutura de pastas | Departamento + subpastas funcionais | Escalável e granular |
| Permissões | Grupos Unix + chmod/chown | Simples, auditável, sem dependências |
| Compartilhamento | Samba + SSH em paralelo | Samba para acesso interativo, SSH para automação |
| Transporte | SCP via OpenSSH nativo | Zero instalação adicional no Windows |
| Nuvem | Azure Blob Storage | Integração nativa com Azure Databricks e PowerShell |
| Backup | tar + timestamp + retenção 7 dias | Nativo, auditável e suficiente para o volume |
| Frequência de coleta | 1x/hora via Task Scheduler | Equilíbrio entre visibilidade e overhead |
| LGPD | chmod 750 em /srv/logix/rh | Segregação de dados sensíveis |
| Auditoria | grp_auditoria com chmod 755 | Leitura sem escrita |
| Portal futuro | Nginx instalado como base | Expansão incremental sem retrabalho |

---

## Tecnologias utilizadas

**Servidor Linux**
- Ubuntu (KillerCoda Ubuntu Playground)
- Samba, OpenSSH, UFW, Nginx
- Bash Script, cron, tar

**Estações Windows**
- PowerShell 5.1 / 7+
- OpenSSH Client nativo (Windows 10/11)
- Task Scheduler

**Armazenamento e Analytics**
- Azure Blob Storage (recomendado — simulado no POC)
- Databricks Community Edition (análise de coletas)
- Python 3 + pandas (analise_coletas.py)

---

## Conformidade com a LGPD

| Controle | Implementação |
|---|---|
| Segregação de dados de RH | `chmod 750` + `grp_rh` exclusivo |
| Auditoria sem escrita | `chmod 755` + `grp_auditoria` |
| Transporte criptografado | SSH/SCP — nenhum dado em texto puro |
| Retenção controlada | Backups deletados após 7 dias |
| Base legal | Art. 7°, IX — legítimo interesse para segurança da informação |

---

## Ferramentas de IA utilizadas

Este projeto utilizou IA generativa como copiloto — não como substituto do raciocínio técnico.

| Ferramenta | Uso |
|---|---|
| Claude (Anthropic) — Sonnet 4.6 | Copiloto principal: arquitetura, scripts, documentação, slides |
| ChatGPT (OpenAI) — GPT-4o | Tomada de decisões arquiteturais |
| Gemini (Google) — 1.5 Pro | Planejamento e organização das etapas |

Todos os scripts foram executados e validados no KillerCoda. Erros identificados durante a execução foram corrigidos e documentados no Diário de Desenvolvimento.

---

## Autoria

**Julya Dias**  
Engenharia de Computação — 7° semestre  
SENAC São Paulo  
[github.com/Julyxdias](https://github.com/Julyxdias)

---

*Logix Brasil Ltda. é uma empresa fictícia criada para fins acadêmicos.*
