#!/bin/bash
# =============================================================================
# 02_firewall_samba_nginx.sh — LogixAI Agent — Logix Brasil Ltda.
# Configura UFW, Samba e Nginx no servidor central
# Ambiente: KillerCoda Ubuntu Playground
# Execução: sudo bash 02_firewall_samba_nginx.sh
# =============================================================================

set -e

echo "=== [1/4] Configurando Firewall (UFW) ==="
sudo apt-get install -y ufw > /dev/null 2>&1

sudo ufw allow 22/tcp    comment 'SSH - acesso remoto seguro'
sudo ufw allow 80/tcp    comment 'Nginx - portal web futuro'
sudo ufw allow 445/tcp   comment 'Samba - compartilhamento Windows'
sudo ufw allow 139/tcp   comment 'Samba - NetBIOS legado'

# --force evita o prompt interativo "Command may disrupt existing ssh connections"
sudo ufw --force enable

echo "Status do firewall:"
sudo ufw status verbose

echo ""
echo "=== [2/4] Instalando e configurando Nginx ==="
sudo apt-get install -y nginx > /dev/null 2>&1
sudo systemctl enable nginx
sudo systemctl start nginx

# Página de status básica do portal futuro
sudo tee /var/www/html/index.html > /dev/null << 'EOF'
<!DOCTYPE html>
<html lang="pt-br">
<head>
  <meta charset="UTF-8">
  <meta http-equiv="refresh" content="60">
  <title>LogixAI Agent — Logix Brasil</title>
  <style>
    body { font-family: Arial, sans-serif; background: #f4f6f9; margin: 0; padding: 40px; color: #222; }
    h1   { color: #1F4E79; border-bottom: 2px solid #2E75B6; padding-bottom: 10px; }
    .card { background: white; border-radius: 8px; padding: 20px; margin: 16px 0;
            box-shadow: 0 1px 4px rgba(0,0,0,0.1); }
    .ok   { color: #3B6D11; font-weight: bold; }
    .ts   { color: #888; font-size: 13px; }
  </style>
</head>
<body>
  <h1>LogixAI Agent</h1>
  <p class="ts">Logix Brasil Ltda. — Portal de Monitoramento (Base)</p>
  <div class="card">
    <strong>Servidor central</strong><br>
    <span class="ok">● Online</span>
    <span class="ts"> — Última verificação: <span id="ts"></span></span>
  </div>
  <div class="card">
    <strong>Repositório de coletas</strong><br>
    <span class="ts">/srv/logix/{rh,financeiro,ti,operacoes}/coletas/</span>
  </div>
  <div class="card">
    <strong>Próxima evolução</strong><br>
    <span class="ts">Dashboard dinâmico com Flask/FastAPI — fase futura do projeto</span>
  </div>
  <script>document.getElementById('ts').textContent = new Date().toLocaleString('pt-BR');</script>
</body>
</html>
EOF

echo "Nginx status:"
sudo systemctl status nginx --no-pager -l | head -15
echo ""
echo "Página acessível em: http://$(ip addr show enp1s0 | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)"

echo ""
echo "=== [3/4] Instalando e configurando Samba ==="
sudo apt-get install -y samba > /dev/null 2>&1

# Backup do smb.conf original
sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.bak

# Configuração do Samba para a Logix Brasil
sudo tee /etc/samba/smb.conf > /dev/null << 'EOF'
[global]
   workgroup = LOGIXBR
   server string = LogixAI Agent - Servidor Central
   security = user
   map to guest = bad user
   log file = /var/log/samba/log.%m
   max log size = 1000
   logging = file

# Compartilhamento TI — leitura para auditoria (sem escrita)
[ti_auditoria]
   path = /srv/logix/ti
   comment = TI - Auditoria (somente leitura)
   browseable = yes
   read only = yes
   valid users = @grp_ti @grp_auditoria
   create mask = 0750

# Compartilhamento Financeiro
[financeiro]
   path = /srv/logix/financeiro
   comment = Financeiro
   browseable = no
   read only = no
   valid users = @grp_financeiro
   create mask = 0750

# Compartilhamento RH — restrito (LGPD)
[rh]
   path = /srv/logix/rh
   comment = RH - Acesso restrito (LGPD)
   browseable = no
   read only = no
   valid users = @grp_rh
   create mask = 0750
EOF

# Testa a configuração antes de reiniciar
sudo testparm -s > /dev/null 2>&1 && echo "  smb.conf: configuração válida ✓"

sudo systemctl enable smbd
sudo systemctl restart smbd

echo "Samba status:"
sudo systemctl status smbd --no-pager -l | head -10

echo ""
echo "=== [4/4] Verificando portas abertas ==="
sudo ss -tlnp | grep -E '22|80|139|445'

echo ""
echo "=== CONCLUÍDO ==="
echo "IP do servidor (enp1s0): $(ip addr show enp1s0 | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)"
echo "Use este IP no agente.ps1 como ServidorIP"
