#!/bin/bash
set -euo pipefail

# === CONFIGURACIÓN ===
SMB_SERVER="192.168.100.28"
SMB_USER="smb"
SMB_PASS="12345678a"
MOUNT_BASE="/home/root/shared"
CREDENTIALS_FILE="/home/root/.smbcredentials"

# === 1. Crear carpetas de destino ===
mkdir -p "${MOUNT_BASE}"/{backups,musica,comics,peliculas,series}

# === 2. Crear archivo de credenciales SMB ===
if [ ! -f "$CREDENTIALS_FILE" ]; then
  cat > "$CREDENTIALS_FILE" <<EOF
username=${SMB_USER}
password=${SMB_PASS}
EOF
  chmod 600 "$CREDENTIALS_FILE"
fi

# === 3. Añadir montajes al /etc/fstab (si no existen ya) ===
FSTAB_ENTRIES=$(cat <<EOF
//${SMB_SERVER}/backups      ${MOUNT_BASE}/backups     cifs    credentials=${CREDENTIALS_FILE},iocharset=utf8,uid=0,gid=0,vers=3.0,nofail    0    0
//${SMB_SERVER}/MusicaGerard ${MOUNT_BASE}/musica      cifs    credentials=${CREDENTIALS_FILE},iocharset=utf8,uid=0,gid=0,vers=3.0,nofail    0    0
//${SMB_SERVER}/comics       ${MOUNT_BASE}/comics      cifs    credentials=${CREDENTIALS_FILE},iocharset=utf8,uid=0,gid=0,vers=3.0,nofail    0    0
//${SMB_SERVER}/Peliculas    ${MOUNT_BASE}/peliculas   cifs    credentials=${CREDENTIALS_FILE},iocharset=utf8,uid=0,gid=0,vers=3.0,nofail    0    0
//${SMB_SERVER}/Series       ${MOUNT_BASE}/series      cifs    credentials=${CREDENTIALS_FILE},iocharset=utf8,uid=0,gid=0,vers=3.0,nofail    0    0
EOF
)

# Evitar duplicados
echo "$FSTAB_ENTRIES" | while read -r line; do
  SHARE=$(echo "$line" | awk '{print $1}')
  if ! grep -q "$SHARE" /etc/fstab; then
    echo "$line" >> /etc/fstab
  fi
done

# === 4. Montar todas las unidades ===
mount -a

# === 5. Mostrar estado ===
echo "✅ Montajes completados:"
mount | grep "${MOUNT_BASE}" || echo "⚠️ Ninguna unidad montada."