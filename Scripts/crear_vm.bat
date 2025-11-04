@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM ===================== CONFIGURACIÓN =====================
set "DISCO=C:\Users\adrii\VirtualBox VMs\discoMulticonexion\ApacheServer.vdi"
set "RED=MediaTek Wi-Fi 6E MT7902 Wireless LAN Card"
set "MEMORIA=2048"
set "CPUS=2"
set "SUBRED=192.168.40"
set "WAIT_INITIAL=100"
set "ARP_RETRIES=6"
set "ARP_INTERVAL=20"

REM === CONFIGURACIÓN SSH ===
set "SSH_KEY_PRIV=C:\Users\adrii\.ssh\id_ed25519"
set "SSH_KEY_PUB=C:\Users\adrii\.ssh\id_ed25519.pub"
set "VM_USER=apachebase"
set "SSH_TIMEOUT=65"
set "SSH_RETRIES=60"
set "SSH_WAIT=50"

REM === PARÁMETROS DE EJECUCIÓN ===
set "VM_NAME=%1"

REM ===== LOG - Usamos DATE y TIME pero evitamos caracteres especiales de la hora/fecha =====
set "LOG=%TEMP%\crear_vm_%RANDOM%.log"
echo.
echo === INICIO: %DATE% %TIME% === > "%LOG%"


color 0B
echo.
echo =======================================================
echo     CREACIÓN AUTOMÁTICA DE VM - Apache Multiconexión
echo =======================================================
echo Log: %LOG%
echo.

REM -------- VALIDACIONES --------
if "%VM_NAME%"=="" (
  echo [ERROR] Falta el nombre de la VM
  goto :error_exit
)
if not exist "%DISCO%" (
  echo [ERROR] No se encuentra el disco base: %DISCO%
  goto :error_exit
)

REM -------- CREAR VM --------
echo [1/6] Creando VM "%VM_NAME%"...
VBoxManage createvm --name "%VM_NAME%" --register --ostype Debian_64 >> "%LOG%" 2>&1
if %ERRORLEVEL% neq 0 (
  echo [ERROR] Fallo en createvm.
  goto :error_exit
)

VBoxManage modifyvm "%VM_NAME%" --memory %MEMORIA% --cpus %CPUS% --nic1 bridged --bridgeadapter1 "%RED%" --boot1 disk >> "%LOG%" 2>&1
if %ERRORLEVEL% neq 0 (
  echo [ERROR] Fallo en modifyvm.
  goto :error_exit
)

VBoxManage storagectl "%VM_NAME%" --name "SATA Controller" --add sata --controller IntelAhci >> "%LOG%" 2>&1
if %ERRORLEVEL% neq 0 (
  echo [ERROR] Fallo en storagectl.
  goto :error_exit
)

VBoxManage storageattach "%VM_NAME%" --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium "%DISCO%" >> "%LOG%" 2>&1
if %ERRORLEVEL% neq 0 (
  echo [ERROR] Fallo en storageattach.
  goto :error_exit
)
echo [+] VM creada correctamente.

REM -------- INICIAR VM --------
echo [2/6] Iniciando VM...
VBoxManage startvm "%VM_NAME%" --type headless >> "%LOG%" 2>&1
timeout /t %WAIT_INITIAL% /nobreak >nul

REM -------- DETECTAR IP POR ARP --------
echo [3/6] Detectando IP asignada por DHCP...
for /f "tokens=2 delims==" %%M in ('VBoxManage showvminfo "%VM_NAME%" --machinereadable ^| findstr /i "macaddress"') do set "MAC=%%~M"
set "MAC=%MAC:"=%"
set "MAC_FORMAT=%MAC:~0,2%-%MAC:~2,2%-%MAC:~4,2%-%MAC:~6,2%-%MAC:~8,2%-%MAC:~10,2%"

set "IP_VM="
for /l %%R in (1,1,%ARP_RETRIES%) do (
  echo   Intento %%R/%ARP_RETRIES%...
  arp -d >nul 2>&1
  for /l %%I in (1,1,254) do ping -n 1 -w 40 %SUBRED%.%%I >nul 2>&1
  arp -a > "%TEMP%\arp_scan.txt"
  for /f "tokens=1,2" %%A in ('findstr /i "%MAC_FORMAT%" "%TEMP%\arp_scan.txt"') do (
    set "IP_VM=%%A"
    goto :found_ip
  )
  timeout /t %ARP_INTERVAL% /nobreak >nul
)
:found_ip
if not defined IP_VM (
  echo [ERROR] No se pudo detectar la IP de la VM. Verifica si el DHCP está activo.
  goto :error_exit
)
del "%TEMP%\arp_scan.txt" 2>nul
echo [+] IP detectada: %IP_VM%

REM -------- ESPERAR A QUE SSH ESTÉ DISPONIBLE --------
echo [4/6] Esperando a que el servicio SSH esté disponible...
set "SSH_READY=0"
for /l %%I in (1,1,%SSH_RETRIES%) do (
  echo   Intento %%I/%SSH_RETRIES%: Verificando puerto 22...
  
  REM Verificar si el puerto 22 está abierto usando telnet
  (echo quit | telnet %IP_VM% 22 > "%TEMP%\telnet_test.txt" 2>&1) && (
    findstr /C:"Connected" "%TEMP%\telnet_test.txt" >nul
    if !ERRORLEVEL! equ 0 (
      set "SSH_READY=1"
      del "%TEMP%\telnet_test.txt" 2>nul
      echo [+] SSH disponible después de %%I intentos
      goto :ssh_ready
    )
  )
  
  del "%TEMP%\telnet_test.txt" 2>nul
  echo     SSH no disponible aún, esperando %SSH_WAIT% segundos...
  timeout /t %SSH_WAIT% /nobreak >nul
)

:ssh_ready
if %SSH_READY% equ 0 (
  echo [ERROR] SSH no disponible después de %SSH_RETRIES% intentos
  echo [WARN] Continuando, pero la conexión SSH podría fallar...
)

REM -------- INYECTAR CLAVE SSH --------
echo [5/6] Inyectando clave SSH en %VM_USER%@%IP_VM%...

REM -------- COPIAR CLAVE SSH --------
echo [6/6] Copiando clave SSH pública...
type "%SSH_KEY_PUB%" | ssh -i "%SSH_KEY_PRIV%" -o StrictHostKeyChecking=no -o ConnectTimeout=%SSH_TIMEOUT% %VM_USER%@%IP_VM% "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys" >> "%LOG%" 2>&1
if %ERRORLEVEL% equ 0 (
  echo [+] Clave SSH copiada correctamente.
  echo [9] Clave SSH copiada >> "%LOG%"
) else (
  echo [WARN] No se pudo copiar la clave SSH automáticamente.
  echo [WARN] Esto podría causar problemas en el despliegue posterior.
)

REM -------- VERIFICACIÓN FINAL DE SSH --------
echo.
echo [*] Realizando verificación final de conectividad SSH...
ssh -i "%SSH_KEY_PRIV%" -o StrictHostKeyChecking=no -o ConnectTimeout=30 -o BatchMode=yes %VM_USER%@%IP_VM% "echo 'Conexión SSH exitosa'" >> "%LOG%" 2>&1
if %ERRORLEVEL% equ 0 (
  echo [+] Verificación SSH exitosa - VM lista para despliegue
) else (
  echo [WARN] Verificación SSH falló - El despliegue podría tener problemas
)

REM -------- FINAL EXITOSO --------
echo.
echo =======================================================
echo   VM creada y lista para despliegue por Go
echo =======================================================
echo [IP]%IP_VM%
exit /b 0

:error_exit
echo.
echo =======================================================
echo              [ERROR CRÍTICO EN EL SCRIPT]
echo =======================================================
echo.
echo Por favor, revisa el archivo de Log para detalles: %LOG%
echo.
pause 
REM Imprimir [IP]error para que Go lo capture y sepa que falló.
echo [IP]error
exit /b 1