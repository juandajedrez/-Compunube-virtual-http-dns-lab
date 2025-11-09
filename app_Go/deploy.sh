#!/bin/bash
# ============================================
# Script: deploy.sh
# Autor: ZoroB
# Descripción:
#   Envía un .zip con una página web a una VM con Apache2
#   y lo despliega automáticamente en /var/www/deploy
# ============================================

# --- Configuración editable ---
ZIP_LOCAL=$1               # Ruta local al archivo ZIP
HOST_VM=$2                 # IP o nombre DNS de la VM
USUARIO=vboxuser           # Usuario con acceso SSH en la VM
RUTA_REMOTA=/tmp/sitio.zip # Donde se guarda temporalmente el ZIP en la VM

# --- Validaciones ---
if [ -z "$ZIP_LOCAL" ] || [ -z "$HOST_VM" ]; then
  echo "Uso: $0 <ruta_zip_local> <ip_o_host_vm>"
  exit 1
fi

if [ ! -f "$ZIP_LOCAL" ]; then
  echo " Archivo ZIP no encontrado: $ZIP_LOCAL"
  exit 1
fi

echo " Iniciando despliegue en $HOST_VM ..."
echo " Subiendo archivo ZIP a la VM..."

# --- 1. Enviar el archivo ZIP a la VM ---
scp -o StrictHostKeyChecking=no "$ZIP_LOCAL" "$USUARIO@$HOST_VM:$RUTA_REMOTA"
if [ $? -ne 0 ]; then
  echo " Error al copiar el archivo a la VM."
  exit 1
fi

echo " Archivo enviado correctamente."

# --- 2. Desplegar dentro de la VM ---
echo " Descomprimiendo y configurando sitio..."
ssh "$USUARIO@$HOST_VM" "bash -s" <<'EOF'

  set -e  # abortar si algo falla
  cd /    # nos aseguramos de estar en raíz, no en /home/vboxuser

  ZIP_PATH="/tmp/sitio.zip"
  DEPLOY_PATH="/var/www/deploy"
  GO_APP_NAME="app_go"

  if [ ! -f "$ZIP_PATH" ]; then
    echo "No se encontró el archivo ZIP en $ZIP_PATH"
    exit 1
  fi


  echo " Descomprimiendo contenido..."
  sudo unzip -o "$ZIP_PATH" -d "$DEPLOY_PATH"

  echo " Desplegando sitio estático..."

  # Si el ZIP tiene una carpeta interna, mover contenido
  if [ -d "$DEPLOY_PATH/"* ]; then
    CARPETA=$(ls "$DEPLOY_PATH" | head -n1)
    if [ -d "$DEPLOY_PATH/$CARPETA" ]; then
      sudo mv "$DEPLOY_PATH/$CARPETA"/* "$DEPLOY_PATH"/ 2>/dev/null || true
      sudo rm -rf "$DEPLOY_PATH/$CARPETA"
    fi
  fi

  echo " Sitio estático desplegado en Apache."

  echo " Ajustando permisos..."
  sudo chown -R www-data:www-data "$DEPLOY_PATH"
  sudo chmod -R 755 "$DEPLOY_PATH"

  echo " Recargando Apache..."
  sudo systemctl reload apache2

  echo " Despliegue completado exitosamente."
EOF

if [ $? -eq 0 ]; then
  echo "Sitio disponible en: http://$HOST_VM/"
else
  echo "Error durante el despliegue en la VM."
fi
