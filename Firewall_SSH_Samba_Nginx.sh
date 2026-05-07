Firewall + SSH + Samba + Nginx

# UFW
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # Nginx
sudo ufw allow 445/tcp   # Samba
sudo ufw enable

# Nginx (portal futuro)
sudo apt install nginx -y
sudo systemctl enable nginx

# Samba
sudo apt install samba -y
# Configurar /etc/samba/smb.conf (rascunho na Fase 2)