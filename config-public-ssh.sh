#!/bin/bash
# Configura acceso SSH por clave para el usuario actual

# === Variables ===
USER_HOME=$(eval echo ~${SUDO_USER:-$USER})
SSH_DIR="$USER_HOME/.ssh"
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"
PUBLIC_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHBmv4hUyl+iZFU0gBH1SJKzce+RDOnECluaUGGsr9KX mrdrarek@gmail.com"
SSHD_CONFIG="/etc/ssh/sshd_config"

echo "🔧 Configurando acceso SSH para el usuario: $USER"
echo "📂 Directorio SSH: $SSH_DIR"

# === 1. Crear directorio .ssh si no existe ===
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"
chown "$USER:$USER" "$SSH_DIR"

# === 2. Crear archivo authorized_keys ===
echo "$PUBLIC_KEY" > "$AUTHORIZED_KEYS"
chmod 600 "$AUTHORIZED_KEYS"
chown "$USER:$USER" "$AUTHORIZED_KEYS"

echo "✅ Clave pública añadida a $AUTHORIZED_KEYS"

# === 3. Configurar /etc/ssh/sshd_config ===
echo "🛠️  Verificando configuración SSH..."

# habilita PubkeyAuthentication y AuthorizedKeysFile
if grep -q "^#*PubkeyAuthentication" "$SSHD_CONFIG"; then
    sed -i 's|^#*PubkeyAuthentication.*|PubkeyAuthentication yes|' "$SSHD_CONFIG"
else
    echo "PubkeyAuthentication yes" >> "$SSHD_CONFIG"
fi

if grep -q "^#*AuthorizedKeysFile" "$SSHD_CONFIG"; then
    sed -i 's|^#*AuthorizedKeysFile.*|AuthorizedKeysFile .ssh/authorized_keys|' "$SSHD_CONFIG"
else
    echo "AuthorizedKeysFile .ssh/authorized_keys" >> "$SSHD_CONFIG"
fi

# habilita temporalmente acceso por contraseña para evitar bloqueos
if grep -q "^#*PasswordAuthentication" "$SSHD_CONFIG"; then
    sed -i 's|^#*PasswordAuthentication.*|PasswordAuthentication yes|' "$SSHD_CONFIG"
else
    echo "PasswordAuthentication yes" >> "$SSHD_CONFIG"
fi

echo "✅ Configuración de sshd_config actualizada."

# === 4. Reiniciar servicio SSH ===
echo "🔄 Reiniciando servicio SSH..."
if systemctl restart ssh 2>/dev/null; then
    echo "✅ Servicio SSH reiniciado correctamente (systemd)."
elif service ssh restart 2>/dev/null; then
    echo "✅ Servicio SSH reiniciado correctamente (SysVinit)."
else
    echo "⚠️  No se pudo reiniciar automáticamente el servicio SSH. Hazlo manualmente:"
    echo "    sudo systemctl restart ssh"
fi

echo "🎉 Configuración completada. Ya puedes conectarte con tu clave privada."
