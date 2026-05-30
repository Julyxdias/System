#!/bin/bash
# =============================================================================
# 01_estrutura_permissoes.sh — LogixAI Agent — Logix Brasil Ltda.
# Cria estrutura de diretórios, grupos e permissões no servidor central
# Ambiente: KillerCoda Ubuntu Playground
# Execução: sudo bash 01_estrutura_permissoes.sh
# =============================================================================

set -e  # Para execução se qualquer comando falhar

echo "=== [1/4] Criando estrutura de diretórios ==="
sudo mkdir -p /srv/logix/{rh,financeiro,ti,operacoes}/{documentos,coletas,backups}
sudo mkdir -p /srv/logix/nuvem_simulada   # Representa bucket em nuvem (POC)
sudo mkdir -p /var/log/logixai            # Diretório de logs do servidor

echo "Estrutura criada:"
ls -la /srv/logix/

echo ""
echo "=== [2/4] Criando grupos de usuários ==="
# Verifica se grupo já existe antes de criar (idempotência)
for grupo in grp_rh grp_financeiro grp_ti grp_auditoria; do
    if ! getent group "$grupo" > /dev/null 2>&1; then
        sudo groupadd "$grupo"
        echo "  Grupo criado: $grupo"
    else
        echo "  Grupo já existe (ok): $grupo"
    fi
done

echo ""
echo "=== [3/4] Criando usuários de teste ==="
# -M: sem home (usuários de serviço), -s /sbin/nologin: sem login interativo
for user_group in "usuario_rh:grp_rh" "usuario_fin:grp_financeiro" "usuario_ti:grp_ti,grp_auditoria"; do
    USER=$(echo "$user_group" | cut -d: -f1)
    GROUP=$(echo "$user_group" | cut -d: -f2)
    if ! id "$USER" > /dev/null 2>&1; then
        sudo useradd -m -G "$GROUP" "$USER"
        echo "  Usuário criado: $USER (grupos: $GROUP)"
    else
        echo "  Usuário já existe (ok): $USER"
    fi
done

echo ""
echo "=== [4/4] Aplicando donos e permissões ==="

# RH — só grp_rh acessa (LGPD: dados sensíveis)
sudo chown -R root:grp_rh /srv/logix/rh
sudo chmod -R 750 /srv/logix/rh
echo "  /srv/logix/rh → 750 (root:grp_rh)"

# Financeiro — só grp_financeiro acessa
sudo chown -R root:grp_financeiro /srv/logix/financeiro
sudo chmod -R 750 /srv/logix/financeiro
echo "  /srv/logix/financeiro → 750 (root:grp_financeiro)"

# TI — todos leem, só root escreve (auditoria sem escrita)
sudo chown -R root:grp_ti /srv/logix/ti
sudo chmod -R 755 /srv/logix/ti
echo "  /srv/logix/ti → 755 (root:grp_ti)"

# Operações — padrão
sudo chown -R root:grp_ti /srv/logix/operacoes
sudo chmod -R 750 /srv/logix/operacoes
echo "  /srv/logix/operacoes → 750 (root:grp_ti)"

# Log do servidor — escrita irrestrita para o script do servidor
sudo chmod 755 /var/log/logixai

echo ""
echo "=== Verificação final de permissões ==="
ls -la /srv/logix/
echo ""
ls -la /srv/logix/rh/
echo ""
echo "=== CONCLUÍDO com sucesso ==="
