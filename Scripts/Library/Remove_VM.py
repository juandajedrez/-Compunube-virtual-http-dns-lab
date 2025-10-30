import subprocess
import os
import shutil

# 📁 Parámetros de configuración
VM_NAME = "apache-instance-01"
VM_FOLDER = r"V:\Maquinas virtuales\ws\DEBIAN CLI (COMPU-NUBE)\Proyecto final\Servidores"
CLONE_PATH = os.path.join(VM_FOLDER, f"{VM_NAME}-disk.vdi")

# 🧹 1️⃣ Apagar la VM si está corriendo
subprocess.run([
    "VBoxManage", "controlvm", VM_NAME, "poweroff"
])

# 🗑️ 2️⃣ Eliminar la VM del registro de VirtualBox
subprocess.run([
    "VBoxManage", "unregistervm", VM_NAME, "--delete"
])

# 🧨 3️⃣ Eliminar el disco clonado manualmente si no fue borrado
if os.path.exists(CLONE_PATH):
    os.remove(CLONE_PATH)
    print(f"🗑️ Disco eliminado: {CLONE_PATH}")

# 🧹 4️⃣ Eliminar la carpeta de la VM si está vacía
if os.path.exists(VM_FOLDER) and not os.listdir(VM_FOLDER):
    shutil.rmtree(VM_FOLDER)
    print(f"🧹 Carpeta eliminada: {VM_FOLDER}")

print(f"✅ VM '{VM_NAME}' eliminada completamente.")