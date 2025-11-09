import subprocess
import os
import re
import time
import sys
import ipaddress

import socket
import struct
import psutil

# Parámetros de configuración
#cambiar segun
#VM_NAME = "apache-instance-01"
VM_FOLDER = r"C:\\Users\\ZoroB\\VirtualBox VMs" #Carpeta donde se crean las maquinas virtuales
DISK_BASE = r"C:\\Users\\ZoroB\\VirtualBox VMs\\disco_apache\\debian_apache.vdi" #carpeta donde se encuentra el disco
BRIDGE_ADAPTER = "Realtek 8822CE Wireless LAN 802.11ac PCI-E NIC"  # Cambia según tu adaptador

# 🛠️ Crear carpeta si no existe
os.makedirs(VM_FOLDER, exist_ok=True)

# 📥 Obtener nombre de la VM desde argumentos
if len(sys.argv) < 2:
    print("Error: No se proporcionó el nombre de la VM.")
    sys.exit(1)

VM_NAME = sys.argv[1]


# 1️⃣ Crear la VM
subprocess.run([
    "VBoxManage", "createvm",
    "--name", VM_NAME,
    "--basefolder", VM_FOLDER,
    "--ostype", "Debian_64",
    "--register"
])


# 2️⃣ Agregar controlador SATA
subprocess.run([
    "VBoxManage", "storagectl", VM_NAME,
    "--name", "SATA Controller",
    "--add", "sata",
    "--controller", "IntelAhci"
])


# 3️⃣ Adjuntar disco clonado
subprocess.run([
    "VBoxManage", "storageattach", VM_NAME,
    "--storagectl", "SATA Controller",
    "--port", "0",
    "--device", "0",
    "--type", "hdd",
    "--medium", DISK_BASE
])

# 4️⃣ Configurar red en modo puente
subprocess.run([
    "VBoxManage", "modifyvm", VM_NAME,
    "--nic1", "bridged",
    "--bridgeadapter1", BRIDGE_ADAPTER
])

# 5️⃣ Configurar memoria y CPU
subprocess.run([
    "VBoxManage", "modifyvm", VM_NAME,
    "--memory", "1024",
    "--cpus", "1"
])

# 6️⃣ Iniciar la VM
subprocess.run([
    "VBoxManage", "startvm", VM_NAME,
    "--type", "headless"
])

#FUNCIONES ADICIONALES
def get_wifi_broadcast_ip():
    for iface_name, iface_info in psutil.net_if_addrs().items():
        for addr in iface_info:
            if addr.family == socket.AF_INET and "Wi-Fi" in iface_name or "wlan" in iface_name.lower():
                ip = addr.address
                netmask = addr.netmask
                if ip and netmask:
                    ip_packed = struct.unpack("!I", socket.inet_aton(ip))[0]
                    mask_packed = struct.unpack("!I", socket.inet_aton(netmask))[0]
                    broadcast_packed = ip_packed | ~mask_packed & 0xFFFFFFFF
                    broadcast_ip = socket.inet_ntoa(struct.pack("!I", broadcast_packed))
                    return broadcast_ip
    return None

def ping_broadcast_wifi(count=1, timeout=1000):
    broadcast_ip = get_wifi_broadcast_ip()
    if not broadcast_ip:
        return "No se pudo determinar la IP de broadcast de la red Wi-Fi."

    try:
        result = subprocess.run(
            ["ping", "-n" if socket.gethostname().endswith(".local") else "-c", str(count), "-W", str(timeout), broadcast_ip],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        return result.stdout
    except Exception as e:
        return f"Error al hacer ping: {e}"

def obtener_broadcast_wifi():
    try:
        resultado = subprocess.check_output("ipconfig", encoding="utf-8", errors="ignore")
    except Exception as e:
        print(" Error al ejecutar ipconfig:", e)
        return None

    bloques = resultado.split("\n\n")

    for bloque in bloques:
        lineas = [l.strip() for l in bloque.splitlines() if l.strip()]

        # Ignorar interfaces desconectadas
        if any("medios desconectados" in l.lower() for l in lineas):
            continue

        # Buscar IP y máscara
        ip_match = re.search(r"Dirección IPv4.*?:\s*([\d.]+)", bloque)
        mask_match = re.search(r"Máscara de subred.*?:\s*([\d.]+)", bloque)

        if ip_match and mask_match:
            ip = ip_match.group(1)
            mask = mask_match.group(1)

            # Saltar IPs locales tipo 169.254.x.x o 127.x.x.x
            if ip.startswith("169.254.") or ip.startswith("127."):
                continue

            # Calcular broadcast
            red = ipaddress.IPv4Network(f"{ip}/{mask}", strict=False)
            broadcast = str(red.broadcast_address)

            # Obtener nombre de interfaz (si existe)
            nombre = re.search(r"Adaptador\s+(.*?)\:", bloque)
            nombre_if = nombre.group(1) if nombre else "Desconocido"

            return {
                "interfaz": nombre_if.strip(),
                "ip": ip,
                "mask": mask,
                "broadcast": broadcast
            }

    print(" No se encontró ninguna interfaz activa con IP válida.")
    return None


# OBTENER BROADCAST LOCAL
def obtener_broadcast():
    try:
        # Ejecuta ipconfig (Windows) o ip addr (Linux)
        resultado = subprocess.run(["ipconfig"], capture_output=True, text=True)

        # Buscar dirección IPv4 y máscara
        ip_match = re.search(r"IPv4.+?: (\d+\.\d+\.\d+\.\d+)", resultado.stdout)
        mask_match = re.search(r"Subred.+?: (\d+\.\d+\.\d+\.\d+)", resultado.stdout)

        if not ip_match or not mask_match:
            print("No se pudo detectar la IP o máscara local.")
            return None

        ip = ip_match.group(1)
        mask = mask_match.group(1)
        network = ipaddress.IPv4Network(f"{ip}/{mask}", strict=False)
        return str(network.broadcast_address)

    except Exception as e:
        print("Error al obtener broadcast:", e)
        return None

# HACE PING AL BROADCAST PARA LLENAR ARP
def ping_broadcast(broadcast_ip):
    print(f"Haciendo ping al broadcast {broadcast_ip} para llenar la tabla ARP...")
    try:
        subprocess.run(["ping", "-n", "1", broadcast_ip], capture_output=True)
        time.sleep(2)
        print("Ping al broadcast completado.")
    except Exception as e:
        print("Error al hacer ping al broadcast:", e)



# Obtener la MAC de la VM
def obtener_mac(vm_name):
    info = subprocess.run(["VBoxManage", "showvminfo", vm_name], capture_output=True, text=True)
    mac_match = re.search(r"NIC 1:\s+MAC: ([0-9A-Fa-f]+)", info.stdout)
    if not mac_match:
        print(" No se pudo obtener la MAC de la VM.")
        return None
    mac_raw = mac_match.group(1)
    return "-".join(mac_raw[i:i+2] for i in range(0, 12, 2)).lower()


#  Buscar IP en la tabla ARP por MAC
def buscar_ip_por_mac(mac_formatted, intentos=5, espera=10):
    for intento in range(intentos):
        arp = subprocess.run(["arp", "-a"], capture_output=True, text=True)
        for line in arp.stdout.splitlines():
            if mac_formatted in line.lower():
                ip_match = re.search(r"(\d+\.\d+\.\d+\.\d+)", line)
                if ip_match:
                    return ip_match.group(1)
        print(f" Intento {intento+1}/{intentos}: esperando {espera} segundos...")
        time.sleep(espera)
    return None


#  Detectar IP automáticamente
print(" Esperando que la VM se conecte a la red...")
time.sleep(30)  # Tiempo inicial para que la VM arranque y obtenga IP

mac_formatted = obtener_mac(VM_NAME)
if not mac_formatted:
    exit(1)

#broadcast = obtener_broadcast()
resultado= obtener_broadcast_wifi()
broadcast= ping_broadcast_wifi()
if not broadcast:
   print("No se pudo determinar el broadcast de la red.")
   exit(1)

ping_broadcast(broadcast)
ip_detectada = buscar_ip_por_mac(mac_formatted)
if ip_detectada:
    print(f" IP detectada: {ip_detectada}")
else:
    print(" No se pudo detectar la IP. ¿La VM está activa y generando tráfico?")


print (ip_detectada)

