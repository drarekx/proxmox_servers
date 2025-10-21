echo "=== Generando clave SSH para GitHub (root) ==="

SSH_HOME="/root"

# Pedir nombre de la clave
read -p "Introduce el nombre de la clave SSH (ej: id_ed25519_github): " KEY_NAME
[ -z "$KEY_NAME" ] && KEY_NAME="id_ed25519_github"

KEY_PATH="${SSH_HOME}/.ssh/${KEY_NAME}"
PUB_PATH="${KEY_PATH}.pub"

# Asegurar carpeta .ssh
mkdir -p "${SSH_HOME}/.ssh"
chmod 700 "${SSH_HOME}/.ssh"

# Generar clave si no existe
if [ -f "${KEY_PATH}" ]; then
  echo "La clave ${KEY_PATH} ya existe, no se sobrescribe."
else
  echo "Generando clave Ed25519 en ${KEY_PATH} (sin passphrase)..."
  ssh-keygen -t ed25519 -C "generated-for-github" -f "${KEY_PATH}" -N ""
  chmod 600 "${KEY_PATH}"
  chmod 644 "${PUB_PATH}"
  echo "Clave generada correctamente."
fi

# Añadir github.com a known_hosts
ssh-keyscan -t rsa github.com >> "${SSH_HOME}/.ssh/known_hosts" 2>/dev/null || true
chmod 644 "${SSH_HOME}/.ssh/known_hosts"

# Config SSH para que use esta clave con GitHub
cat > "${SSH_HOME}/.ssh/config" <<EOF
Host github.com
  HostName github.com
  IdentityFile ${KEY_PATH}
  IdentitiesOnly yes
EOF
chmod 600 "${SSH_HOME}/.ssh/config"

echo "=== FIN: clave SSH creada para root ==="
echo "Clave privada: ${KEY_PATH}"
echo "Clave pública: ${PUB_PATH}"
echo ""
echo "Añádela en GitHub → Settings → SSH and GPG keys → New SSH key"
echo "Para verla: cat ${PUB_PATH}"