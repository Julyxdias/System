# Estrutura de pastas + permissões

# 1. Criar estrutura B (departamento + subpastas funcionais)
sudo mkdir -p /srv/logix/{rh,financeiro,ti,operacoes}/{documentos,coletas,backups}

# 2. Criar grupos
sudo groupadd grp_rh
sudo groupadd grp_financeiro
sudo groupadd grp_ti
sudo groupadd grp_auditoria

# 3. Criar usuários de teste
sudo useradd -m -G grp_rh usuario_rh
sudo useradd -m -G grp_financeiro usuario_fin
sudo useradd -m -G grp_ti,grp_auditoria usuario_ti

# 4. Atribuir dono e permissões
sudo chown -R root:grp_rh /srv/logix/rh
sudo chown -R root:grp_financeiro /srv/logix/financeiro
sudo chown -R root:grp_ti /srv/logix/ti

sudo chmod -R 750 /srv/logix/rh          # RH: dono lê/escreve, grupo lê, outros nada
sudo chmod -R 750 /srv/logix/financeiro
sudo chmod -R 755 /srv/logix/ti          # TI: todos leem, só dono escreve (auditoria)