#!/bin/bash
set -euo pipefail

USERNAME="www"
PASSWORD="1234"
SHELL="/bin/bash"
HOME_DIR="/home/${USERNAME}"
SSH_DIR="${HOME_DIR}/.ssh"
KEY_FILE="${SSH_DIR}/id_ed25519"

ROOT_SSH_DIR="/root/.ssh"
ROOT_AUTH_KEYS="${ROOT_SSH_DIR}/authorized_keys"
ROOT_CONFIG="${ROOT_SSH_DIR}/config"
ROOT_PRIVATE_KEY="${ROOT_SSH_DIR}/id_ed25519"
ROOT_PUBLIC_KEY="${ROOT_SSH_DIR}/id_ed25519.pub"

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

# Crear .ssh y fijar permisos básicos
echo "Configurando SSH para ${USERNAME}..."
mkdir -p "${SSH_DIR}"
chown "${USERNAME}:${USERNAME}" "${SSH_DIR}"
chmod 700 "${SSH_DIR}"

# En vez de generar la clave, copiar la que está en /root/.ssh
COPIED_ANY_KEY=false

# 1) Copiar config si existe
if [ -f "${ROOT_CONFIG}" ]; then
  echo "Copiando ${ROOT_CONFIG} -> ${SSH_DIR}/config"
  cp -p "${ROOT_CONFIG}" "${SSH_DIR}/config"
  chown "${USERNAME}:${USERNAME}" "${SSH_DIR}/config"
  chmod 600 "${SSH_DIR}/config"
else
  echo "No existe ${ROOT_CONFIG}, se omite."
fi

# 2) Copiar authorized_keys (haciendo merge y evitando duplicados)
if [ -f "${ROOT_AUTH_KEYS}" ]; then
  echo "Integrando claves de ${ROOT_AUTH_KEYS} en ${SSH_DIR}/authorized_keys (evitando duplicados)..."
  # Aseguramos fichero destino
  touch "${SSH_DIR}/authorized_keys"
  chown "${USERNAME}:${USERNAME}" "${SSH_DIR}/authorized_keys"
  chmod 600 "${SSH_DIR}/authorized_keys"

  # Concatenar y deduplicar líneas
  # Usamos una copia temporal y luego movemos al destino
  TMP_MERGE="$(mktemp)"
  cat "${SSH_DIR}/authorized_keys" >> "${TMP_MERGE}" || true
  cat "${ROOT_AUTH_KEYS}" >> "${TMP_MERGE}" || true
  awk '!seen[$0]++' "${TMP_MERGE}" > "${TMP_MERGE}.uniq"
  mv "${TMP_MERGE}.uniq" "${SSH_DIR}/authorized_keys"
  rm -f "${TMP_MERGE}"
  chown "${USERNAME}:${USERNAME}" "${SSH_DIR}/authorized_keys"
  chmod 600 "${SSH_DIR}/authorized_keys"
  COPIED_ANY_KEY=true
else
  echo "No existe ${ROOT_AUTH_KEYS}, se omite."
fi

# 3) Copiar clave privada/publica id_ed25519 si existen en root
if [ -f "${ROOT_PRIVATE_KEY}" ]; then
  echo "Copiando clave privada ${ROOT_PRIVATE_KEY} -> ${KEY_FILE}"
  cp -p "${ROOT_PRIVATE_KEY}" "${KEY_FILE}"
  chown "${USERNAME}:${USERNAME}" "${KEY_FILE}"
  chmod 600 "${KEY_FILE}"
  COPIED_ANY_KEY=true

  if [ -f "${ROOT_PUBLIC_KEY}" ]; then
    echo "Copiando clave pública ${ROOT_PUBLIC_KEY} -> ${KEY_FILE}.pub"
    cp -p "${ROOT_PUBLIC_KEY}" "${KEY_FILE}.pub"
    chown "${USERNAME}:${USERNAME}" "${KEY_FILE}.pub"
    chmod 644 "${KEY_FILE}.pub"
  else
    # Si no hay .pub en root, intentar generarla sin passphrase (solo si ssh-keygen existe)
    if command -v ssh-keygen >/dev/null 2>&1; then
      echo "No se encontró ${ROOT_PUBLIC_KEY}; generando pública a partir de la privada (sin passphrase)..."
      sudo -u "${USERNAME}" ssh-keygen -y -f "${KEY_FILE}" > "${KEY_FILE}.pub"
      chown "${USERNAME}:${USERNAME}" "${KEY_FILE}.pub"
      chmod 644 "${KEY_FILE}.pub"
    else
      echo "ssh-keygen no disponible, no se puede generar la pública."
    fi
  fi
else
  echo "No existe clave privada ${ROOT_PRIVATE_KEY} en root; no se copiará una clave privada."
fi

# Si no se ha copiado ninguna clave y no existe id_ed25519 del usuario, opcional: dejar que el script genere una (mantengo comentado)
if [ "${COPIED_ANY_KEY}" = false ] && [ ! -f "${KEY_FILE}" ]; then
  echo "No se han copiado claves desde root y no existe ${KEY_FILE}."
  echo "Actualmente el script no generará una nueva clave automáticamente."
  echo "Si deseas generar una clave para el usuario, habilita la generación manualmente en el script."
fi

# Mensajes finales y permisos finales por si algo quedó fuera
chown -R "${USERNAME}:${USERNAME}" "${SSH_DIR}"
find "${SSH_DIR}" -type d -exec chmod 700 {} \;
# Archivos privados deberían 600, públicos 644, config 600, authorized_keys 600
[ -f "${SSH_DIR}/config" ] && chmod 600 "${SSH_DIR}/config"
[ -f "${SSH_DIR}/authorized_keys" ] && chmod 600 "${SSH_DIR}/authorized_keys"
[ -f "${KEY_FILE}" ] && chmod 600 "${KEY_FILE}"
[ -f "${KEY_FILE}.pub" ] && chmod 644 "${KEY_FILE}.pub"

echo ""
echo "================================================="
echo "Usuario: ${USERNAME}"
echo "Home: ${HOME_DIR}"
echo "Contraseña temporal: ${PASSWORD}"
echo ""
if [ -f "${KEY_FILE}.pub" ]; then
  echo "Clave pública (copiar a GitHub o a otros hosts):"
  echo "-------------------------------------------------"
  cat "${KEY_FILE}.pub"
  echo "-------------------------------------------------"
  echo "SSH privado: ${KEY_FILE}"
else
  echo "No hay clave pública en ${KEY_FILE}.pub"
fi
echo ""
echo "Recomendaciones finales:"
echo " - Cambia la contraseña: passwd ${USERNAME}"
echo " - Si prefieres no permitir password auth, configura SSH para usar solo claves."
echo " - Si quieres que ${USERNAME} tenga sudo sin pedir contraseña, edita /etc/sudoers.d/${USERNAME} y pon:"
echo "     ${USERNAME} ALL=(ALL) NOPASSWD:ALL"
echo "   (pero eso reduce seguridad)."
echo "================================================="
