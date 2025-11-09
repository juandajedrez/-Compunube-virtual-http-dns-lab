import subprocess
import os
import shutil
import sys

#  Obtener nombre de la VM desde argumentos
if len(sys.argv) < 2:
    print("Error: No se proporcionó el nombre de la VM.")
    sys.exit(1)

VM_NAME = sys.argv[1]
VM_FOLDER = os.path.join("C:\\Users\\ZoroB\\VirtualBox VMs", VM_NAME) #Carpeta donde se crean las maquinas virtuales
CLONE_PATH = os.path.join(VM_FOLDER, f"{VM_NAME}-disk.vdi") #carpeta donde esta el disco

#  Apagar la VM si está corriendo
subprocess.run(["VBoxManage", "controlvm", VM_NAME, "poweroff"])

#  Eliminar la VM del registro de VirtualBox
subprocess.run(["VBoxManage", "unregistervm", VM_NAME, "--delete"])

#  Eliminar el disco clonado manualmente si no fue borrado
if os.path.exists(CLONE_PATH):
    os.remove(CLONE_PATH)
    print(f" Disco eliminado: {CLONE_PATH}")

#Eliminar la carpeta de la VM si está vacía
if os.path.exists(VM_FOLDER) and not os.listdir(VM_FOLDER):
    shutil.rmtree(VM_FOLDER)
    print(f"Carpeta eliminada: {VM_FOLDER}")

print(f" VM '{VM_NAME}' eliminada completamente.")
