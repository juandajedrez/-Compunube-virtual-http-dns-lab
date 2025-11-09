#!/bin/bash
# ============================================
# Script: configurar_red.sh
# Autor: ZoroB
# Descripción:
#   Configura una IP estática en una VM Debian
#   conectándose por SSH al usuario vboxuser.
# ============================================

# --- Configuración editable ---
HOST_VM=$1                  # IP o nombre DNS de la VM (temporal o inicial)
USUARIO=vboxuser            # Usuario con acceso SSH en la VM
IP_ESTATICA=$2              # IP estática a asignar
GATEWAY_INTERNO="192.168.222.1"
DNS_INTERNO="192.168.222.2"
MASCARA="255.255.255.0"

# --- Validaciones ---
if [ -z "$HOST_VM" ] || [ -z "$IP_ESTATICA" ]; then
  echo "Uso: $0 <ip_o_host_vm> <ip_estatica>"
  exit 1
fi

echo "Iniciando configuración de red en $HOST_VM ..."
echo "   IP estática: $IP_ESTATICA"
echo "   Gateway: $GATEWAY_INTERNO"
echo "   DNS: $DNS_INTERNO"

# --- 1. Ejecutar comandos dentro de la VM ---
ssh -o StrictHostKeyChecking=no "$USUARIO@$HOST_VM" "bash -s" <<EOF
set -e

echo "Verificando instalación de iproute2..."
if ! command -v ip &> /dev/null; then
  echo "   iproute2 no encontrado. Instalando..."
  sudo apt update -y && sudo apt install -y iproute2
else
  echo "   iproute2 ya está instalado."
fi

echo "Detectando interfaz de red principal..."
IFACE=\$(ip -o link show | awk -F': ' '{print \$2}' | grep -E '^en|^eth' | head -n1)

if [ -z "\$IFACE" ]; then
  echo "No se detectó ninguna interfaz de red válida."
  echo "Ejecuta manualmente: ip -o link show"
  exit 1
fi

echo "   Interfaz detectada: \$IFACE"

echo "Creando respaldo de /etc/network/interfaces..."
if [ -f /etc/network/interfaces ]; then
  sudo cp /etc/network/interfaces /etc/network/interfaces.bak_\$(date +%Y%m%d%H%M%S)
  echo "   Respaldo creado correctamente."
else
  echo "   No existía archivo previo, se creará uno nuevo."
fi

echo "Configurando IP estática..."
sudo tee /etc/network/interfaces > /dev/null <<EONET
auto lo
iface lo inet loopback

auto \$IFACE
iface \$IFACE inet static
    address $IP_ESTATICA
    netmask $MASCARA
    gateway $GATEWAY_INTERNO
    dns-nameservers $DNS_INTERNO 8.8.8.8
EONET

echo "Programando reinicio de red asíncrono..."

# Crear un script temporal dentro de la VM
sudo tee /tmp/restart_network.sh > /dev/null <<EOSUB
#!/bin/bash
sleep 2
if systemctl restart networking 2>/dev/null; then
  echo "Servicio de red reiniciado correctamente (systemctl)." >> /var/log/configurar_red.log
elif service networking restart 2>/dev/null; then
  echo "Servicio de red reiniciado correctamente (service)." >> /var/log/configurar_red.log
else
  echo "Error al reiniciar el servicio de red." >> /var/log/configurar_red.log
fi
EOSUB

# Hacerlo ejecutable y ejecutarlo en segundo plano con nohup
sudo chmod +x /tmp/restart_network.sh
nohup sudo /tmp/restart_network.sh >/dev/null 2>&1 &

echo "El servicio de red se reiniciará en segundo plano. Cerrando sesión SSH..."
exit 0
EOF

# --- 2. Resultado final ---
if [ $? -eq 0 ]; then
  echo "Configuración de red aplicada correctamente a $HOST_VM ($IP_ESTATICA)"
else
  echo "Error durante la configuración de red en la VM."
fi
