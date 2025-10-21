#!/bin/bash
set -euo pipefail

# Config
NODE_MAJOR="${1:-20}"    # Por defecto 20. Puedes pasar otro número como: ./install-node.sh 18
NODE_DISTRO_SETUP="https://deb.nodesource.com/setup_${NODE_MAJOR}.x"

echo "=== Instalador: Node.js ${NODE_MAJOR} + npm + pnpm ==="

echo "1) Actualizando repos y paquetes básicos..."
apt update
apt install -y curl ca-certificates gnupg build-essential

# Añadir NodeSource (idempotente)
if ! command -v node >/dev/null 2>&1 || [ "$(node -v 2>/dev/null || echo '')" != "v${NODE_MAJOR}" ] ; then
  echo "2) Añadiendo repositorio NodeSource para Node ${NODE_MAJOR}..."
  curl -fsSL "${NODE_DISTRO_SETUP}" | bash -
else
  echo "Node parece estar instalado (verificando versión)..."
fi

echo "3) Instalando nodejs (incluye npm)..."
apt install -y nodejs

# Verificar instalación
echo "Node version: $(node -v)"
echo "npm  version: $(npm -v)"

# Actualizar npm a la última versión estable (opcional, idempotente)
echo "4) Asegurando npm actualizado..."
npm install -g npm@latest

echo "npm actualizado: $(npm -v)"

# Instalación/activación de pnpm
echo "5) Instalando/activando pnpm (vía corepack cuando esté disponible)..."

# Si corepack existe, usarlo (mejor)
if command -v corepack >/dev/null 2>&1; then
  echo "corepack detectado. Activando y preparando pnpm..."
  corepack enable
  corepack prepare pnpm@latest --activate
else
  # Fallback: instalar pnpm globalmente con npm
  echo "corepack NO detectado. Instalando pnpm mediante npm (fallback)..."
  npm install -g pnpm
fi

echo "pnpm version: $(pnpm -v || echo 'no disponible')"

# Opcional: configurar un prefix global seguro para npm (evita permisos raros)
echo "6) Configuración recomendada: prefijo global de npm en /usr/local (ya suele estar así)"
npm_prefix=$(npm config get prefix)
echo "npm prefix actual: $npm_prefix"


# Instalación de pm2 y serve globalmente
echo "6) Instalando pm2 y serve..."
npm install -g pm2 serve

echo "pm2 version: $(pm2 -v || echo 'no disponible')"
echo "serve version: $(serve --version || echo 'no disponible')"

echo "=== Instalación completada ✅ ==="
echo "Node:  $(node -v)"
echo "npm:   $(npm -v)"
echo "pnpm:  $(pnpm -v || echo 'no disponible')"
echo "pm2:   $(pm2 -v || echo 'no disponible')"
echo "serve: $(serve --version || echo 'no disponible')"

echo ""
echo "Uso rápido:"
echo "  node -v"
echo "  npm -v"
echo "  pnpm -v"
echo "  pm2 -v"
echo "  serve -s dist -l 3000"
echo ""
echo "Si quieres instalar una versión distinta de Node, ejecuta este script pasando el major como argumento:"
echo "  ./install-node.sh 18   # instalar Node 18"