#!/bin/bash
set -e

echo "=== Actualizando sistema ==="
apt update && apt upgrade -y

echo "=== Instalando básicos ==="
apt install -y \
    ca-certificates curl gnupg lsb-release \
    apt-transport-https software-properties-common \
    git wget nano vim zsh htop btop mc make \
    ufw fail2ban cifs-utils

echo "=== Configurando Docker ==="
# Añadir clave y repo oficial
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/$(. /etc/os-release; echo "$ID")/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") \
  $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list

apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl enable docker
systemctl start docker

echo "=== Configurando SSH ==="
# PermitRootLogin y PasswordAuthentication (ajusta si quieres claves SSH)
sed -i 's/#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart ssh

echo "=== Activando UFW con reglas básicas ==="
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

echo "=== Instalando Oh My Zsh ==="
rm -rf /root/.oh-my-zsh
RUNZSH=no KEEP_ZSHRC=yes sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

echo "=== Configurando montajes de red CIFS ==="
# Carpeta de destino
#mkdir -p /home/root/shared/{backups,musica,comics,peliculas,series}

# Archivo de credenciales SMB
#cat > /home/root/.smbcredentials <<EOF
#username=smb
#password=12345678a
#EOF
#chmod 600 /home/root/.smbcredentials

# Añadir a /etc/fstab
#cat >> /etc/fstab <<EOF
#//192.168.100.28/backups      /home/root/shared/backups    cifs    credentials=/home/root/.smbcredentials,iocharset=utf8,forceuid,forcegid,cifsacl    0    0
#//192.168.100.28/MusicaGerard /home/root/shared/musica     cifs    credentials=/home/root/.smbcredentials,iocharset=utf8,forceuid,forcegid,cifsacl    0    0
#//192.168.100.28/comics       /home/root/shared/comics     cifs    credentials=/home/root/.smbcredentials,iocharset=utf8,forceuid,forcegid,cifsacl    0    0
#//192.168.100.28/Peliculas    /home/root/shared/peliculas  cifs    credentials=/home/root/.smbcredentials,iocharset=utf8,forceuid,forcegid,cifsacl    0    0
#//192.168.100.28/Series       /home/root/shared/series     cifs    credentials=/home/root/.smbcredentials,iocharset=utf8,forceuid,forcegid,cifsacl    0    0
#EOF

# Montar todo de golpe
#mount -a


echo "=== Plantilla lista 🚀 ==="
echo " - Docker instalado y corriendo"
echo " - SSH habilitado"
echo " - Firewall básico (22, 80, 443)"
echo " - Oh My Zsh listo"
echo " - Montajes de red configurados en /etc/fstab"