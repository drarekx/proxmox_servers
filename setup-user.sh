#!/bin/bash
set -euo pipefail

USERNAME="www"
PASSWORD="1234"
SHELL="/bin/bash"
HOME_DIR="/home/${USERNAME}"
SSH_DIR="${HOME_DIR}/.ssh"
KEY_FILE="${SSH_DIR}/id_ed25519"

# Función para detectar package manager e instalar paquetes
install_pkg() {
  pkg="$1"
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update -y
    DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg"
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y "$pkg"
  elif command -v yum >/dev/null 2>&1; then
    yum install -y "$pkg"
  elif command -v pacman >/dev/null 2>&1; then
    pacman -Sy --noconfirm "$pkg"
  else
    echo "No se encontró gestor de paquetes soportado (apt/dnf/yum/pacman). Instala '$pkg' manualmente."
    return 1
  fi
}

# Check run as root
if [ "$(id -u)" -ne 0 ]; then
  echo "Este script debe ejecutarse como root."
  exit 1
fi

# Crear usuario si no existe
if id "${USERNAME}" >/dev/null 2>&1; then
  echo "El usuario '${USERNAME}' ya existe."
else
  echo "Creando usuario ${USERNAME}..."
  useradd -m -d "${HOME_DIR}" -s "${SHELL}" "${USERNAME}"
  echo "${USERNAME}:${PASSWORD}" | chpasswd
  echo "Usuario ${USERNAME} creado con contraseña temporal."
fi

# Instalar sudo si hace falta
if ! command -v sudo >/dev/null 2>&1; then
  echo "sudo no está instalado. Intentando instalar..."
  if install_pkg sudo; then
    echo "sudo instalado."
  else
    echo "No se pudo instalar sudo automáticamente. Continuamos intentando añadir sudoers manualmente."
  fi
else
  echo "sudo ya instalado."
fi

# Añadir usuario a grupo sudo / wheel o crear sudoers.d
if getent group sudo >/dev/null 2>&1; then
  echo "Añadiendo ${USERNAME} al grupo 'sudo'..."
  usermod -aG sudo "${USERNAME}"
elif getent group wheel >/dev/null 2>&1; then
  echo "Añadiendo ${USERNAME} al grupo 'wheel'..."
  usermod -aG wheel "${USERNAME}"
else
  echo "No existe el grupo 'sudo' ni 'wheel'. Creando entrada en /etc/sudoers.d/${USERNAME}..."
  SUDOERS_FILE="/etc/sudoers.d/${USERNAME}"
  echo "${USERNAME} ALL=(ALL) ALL" > "${SUDOERS_FILE}"
  chmod 0440 "${SUDOERS_FILE}"
  # Comprobar sintaxis
  if visudo -cf "${SUDOERS_FILE}"; then
    echo "Entrada sudoers creada y comprobada."
  else
    echo "Error en la comprobación de sudoers. Eliminando ${SUDOERS_FILE} por seguridad."
    rm -f "${SUDOERS_FILE}"
    echo "Por favor, añade el usuario manualmente al sudoers si es necesario."
  fi
fi

# Crear .ssh y generar clave si no existe
echo "Configurando SSH para ${USERNAME}..."
mkdir -p "${SSH_DIR}"
chown "${USERNAME}:${USERNAME}" "${SSH_DIR}"
chmod 700 "${SSH_DIR}"

if [ ! -f "${KEY_FILE}" ]; then
  echo "Generando clave ed25519 en ${KEY_FILE}..."
  # Generar la clave como el usuario (para que el propietario sea correcto)
  sudo -u "${USERNAME}" ssh-keygen -t ed25519 -C "${USERNAME}@$(hostname)" -f "${KEY_FILE}" -N ""
  chown "${USERNAME}:${USERNAME}" "${KEY_FILE}" "${KEY_FILE}.pub"
  chmod 600 "${KEY_FILE}"
  chmod 644 "${KEY_FILE}.pub"
  echo "Clave generada."
else
  echo "Ya existe clave en ${KEY_FILE}, no se sobrescribe."
fi

# Crear authorized_keys (añadir la pública por defecto)
AUTH_KEYS="${SSH_DIR}/authorized_keys"
if ! grep -qxF "$(cat "${KEY_FILE}.pub")" "${AUTH_KEYS}" 2>/dev/null; then
  cat "${KEY_FILE}.pub" >> "${AUTH_KEYS}"
fi
chown "${USERNAME}:${USERNAME}" "${AUTH_KEYS}"
chmod 600 "${AUTH_KEYS}"

echo ""
echo "================================================="
echo "Usuario: ${USERNAME}"
echo "Home: ${HOME_DIR}"
echo "Contraseña temporal: ${PASSWORD}"
echo ""
echo "Clave pública (copiar a GitHub o a otros hosts):"
echo "-------------------------------------------------"
cat "${KEY_FILE}.pub"
echo "-------------------------------------------------"
echo "SSH privado: ${KEY_FILE}"
echo ""
echo "Recomendaciones finales:"
echo " - Cambia la contraseña: passwd ${USERNAME}"
echo " - Si prefieres no permitir password auth, configura SSH para usar solo claves."
echo " - Si quieres que ${USERNAME} tenga sudo sin pedir contraseña, edita /etc/sudoers.d/${USERNAME} y pon:"
echo "     ${USERNAME} ALL=(ALL) NOPASSWD:ALL"
echo "   (pero eso reduce seguridad)."
echo "================================================="