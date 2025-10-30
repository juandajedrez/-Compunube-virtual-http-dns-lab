#!/bin/bash

# Variables
#cambiar a parametros
ZIP_PATH="/tmp/sitio_usuario.zip"
DEST_DIR="/var/www/sitio_usuario"
CONF_FILE="/etc/apache2/sites-available/sitio_usuario.conf"

# Descomprimir contenido
sudo unzip "$ZIP_PATH" -d "$DEST_DIR"

# Crear VirtualHost
sudo tee "$CONF_FILE" > /dev/null <<EOF
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot $DEST_DIR
    <Directory $DEST_DIR>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog \${APACHE_LOG_DIR}/sitio_usuario_error.log
    CustomLog \${APACHE_LOG_DIR}/sitio_usuario_access.log combined
</VirtualHost>
EOF

# Activar sitio y reiniciar Apache
sudo a2ensite sitio_usuario.conf
sudo systemctl reload apache2

# Ajustar permisos
sudo chown -R www-data:www-data "$DEST_DIR"
sudo chmod -R 755 "$DEST_DIR"

echo "Sitio desplegado en http://$(hostname -I | awk '{print $1}')"
