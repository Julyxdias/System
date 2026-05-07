Script servidor.sh

#!/bin/bash
# servidor.sh — LogixAI Agent — Logix Brasil Ltda.
# Organiza coletas recebidas e executa backup diário

BASE="/srv/logix"
BACKUP_DIR="/srv/logix/backups"
LOG="/var/log/logixai/servidor.log"
DATA=$(date +%Y-%m-%d_%H-%M)

echo "[$DATA] Iniciando rotina de organização..." >> "$LOG"

# Organizar arquivos recebidos por departamento
for DEPT in rh financeiro ti operacoes; do
    if ls "$BASE/$DEPT/coletas/"*.csv 2>/dev/null; then
        echo "[$DATA] Processando coletas: $DEPT" >> "$LOG"
    fi
done

# Backup com timestamp (Opção C escolhida)
tar -czf "$BACKUP_DIR/backup_$DATA.tar.gz" "$BASE" \
    --exclude="$BASE/backups" 2>> "$LOG"
echo "[$DATA] Backup concluído: backup_$DATA.tar.gz" >> "$LOG"

# Retenção: apagar backups com mais de 7 dias
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +7 -delete