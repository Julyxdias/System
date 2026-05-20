#!/bin/bash
# =============================================================================
# servidor.sh — LogixAI Agent — Logix Brasil Ltda.
# Organiza coletas recebidas, executa backup diário e simula envio à nuvem
# Ambiente: KillerCoda Ubuntu Playground
# Execução: bash /srv/logix/servidor.sh  (ou via cron)
# Cron sugerido: 0 2 * * * bash /srv/logix/servidor.sh
# =============================================================================

BASE="/srv/logix"
BACKUP_DIR="/srv/logix/backups"           # Backup local (dentro do servidor)
NUVEM_DIR="/srv/logix/nuvem_simulada"     # Simula bucket de nuvem (POC)
LOG="/var/log/logixai/servidor.log"
DATA=$(date +%Y-%m-%d_%H-%M)

# --- PRÉ-VERIFICAÇÃO: garantir que diretórios e log existem ---
mkdir -p "$BACKUP_DIR"
mkdir -p "$NUVEM_DIR"
mkdir -p "$(dirname "$LOG")"
touch "$LOG"

echo "[$DATA] ================================================" >> "$LOG"
echo "[$DATA] Iniciando rotina LogixAI servidor.sh" >> "$LOG"

# --- SEÇÃO 1: Organizar arquivos recebidos por departamento ---
echo "[$DATA] Verificando coletas recebidas..." >> "$LOG"

TOTAL_COLETAS=0
for DEPT in rh financeiro ti operacoes; do
    DIR_COLETAS="$BASE/$DEPT/coletas"
    # Conta quantos CSVs existem no departamento
    QTDE=$(ls "$DIR_COLETAS"/*.csv 2>/dev/null | wc -l)
    if [ "$QTDE" -gt 0 ]; then
        echo "[$DATA]   $DEPT: $QTDE arquivo(s) CSV encontrado(s)" >> "$LOG"
        TOTAL_COLETAS=$((TOTAL_COLETAS + QTDE))
    else
        echo "[$DATA]   $DEPT: nenhuma coleta recebida" >> "$LOG"
    fi
done

echo "[$DATA] Total de coletas: $TOTAL_COLETAS arquivo(s)" >> "$LOG"

# --- SEÇÃO 2: Backup com timestamp (Opção C escolhida) ---
echo "[$DATA] Iniciando backup..." >> "$LOG"

ARQUIVO_BACKUP="$BACKUP_DIR/backup_$DATA.tar.gz"

# --exclude evita incluir o próprio diretório de backups (loop)
# --exclude evita incluir a nuvem simulada (ela já recebe o backup)
tar -czf "$ARQUIVO_BACKUP" \
    "$BASE" \
    --exclude="$BASE/backups" \
    --exclude="$BASE/nuvem_simulada" \
    2>> "$LOG"

TAMANHO=$(du -sh "$ARQUIVO_BACKUP" | cut -f1)
echo "[$DATA] Backup concluído: backup_$DATA.tar.gz ($TAMANHO)" >> "$LOG"

# --- SEÇÃO 3: Simular envio para nuvem ---
# Em produção: substituir cp por "az storage blob upload --file $ARQUIVO_BACKUP ..."
# ou "aws s3 cp $ARQUIVO_BACKUP s3://logixai-backup/"
echo "[$DATA] Enviando backup para nuvem (simulada)..." >> "$LOG"
cp "$ARQUIVO_BACKUP" "$NUVEM_DIR/"

if [ $? -eq 0 ]; then
    echo "[$DATA] Envio para nuvem: OK → $NUVEM_DIR/" >> "$LOG"
    echo "[$DATA] Em produção: az storage blob upload --file $ARQUIVO_BACKUP --container logixai" >> "$LOG"
else
    echo "[$DATA] ERRO: Falha ao copiar para nuvem simulada" >> "$LOG"
fi

# --- SEÇÃO 4: Retenção — apagar backups com mais de 7 dias ---
DELETADOS=$(find "$BACKUP_DIR" -name "*.tar.gz" -mtime +7 | wc -l)
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +7 -delete
echo "[$DATA] Retenção: $DELETADOS backup(s) antigo(s) removido(s)" >> "$LOG"

# --- RELATÓRIO FINAL ---
echo "[$DATA] ---- RELATÓRIO ----" >> "$LOG"
echo "[$DATA] Coletas processadas: $TOTAL_COLETAS" >> "$LOG"
echo "[$DATA] Backup gerado: backup_$DATA.tar.gz ($TAMANHO)" >> "$LOG"
echo "[$DATA] Backups locais disponíveis: $(ls $BACKUP_DIR/*.tar.gz 2>/dev/null | wc -l)" >> "$LOG"
echo "[$DATA] Backups na nuvem (simulada): $(ls $NUVEM_DIR/*.tar.gz 2>/dev/null | wc -l)" >> "$LOG"
echo "[$DATA] ================================================" >> "$LOG"

# Exibe o log na tela também (útil para demonstração)
echo ""
echo "=== Log da execução ==="
tail -20 "$LOG"
