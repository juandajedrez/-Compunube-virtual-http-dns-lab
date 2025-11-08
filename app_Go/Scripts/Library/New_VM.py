import subprocess
import os

# 📁 Parámetros de configuración
VM_NAME = "apache-instance-01"
VM_FOLDER = r"V:\Maquinas virtuales\ws\DEBIAN CLI (COMPU-NUBE)\Proyecto final\Servidores"
DISK_BASE = r"V:\Maquinas virtuales\ws\DEBIAN CLI (COMPU-NUBE)\Parcial 2\Disco\disco_servidor\Debian.vdi"
CLONE_PATH = os.path.join(VM_FOLDER, f"{VM_NAME}-disk.vdi")
BRIDGE_ADAPTER = "Realtek RTL8723BE Wireless LAN 802.11n PCI-E NIC"  # Cambia según tu adaptador

# 🛠️ Crear carpeta si no existe
os.makedirs(VM_FOLDER, exist_ok=True)

# 🧬 0️⃣ Clonar el disco base
subprocess.run([
    "VBoxManage", "clonehd",
    DISK_BASE,
    CLONE_PATH,
    "--format", "VDI"
])

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
    "--medium", CLONE_PATH
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
    "--type", "gui"
])

print(f"✅ VM '{VM_NAME}' creada y lanzada con disco clonado: {CLONE_PATH}")