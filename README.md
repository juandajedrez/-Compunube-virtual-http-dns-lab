# HTTPaaS Local con VirtualBox, Apache y Bind9

Simulación de una plataforma HTTP como servicio (HTTPaaS) en entorno local, utilizando Oracle VirtualBox, Apache Web Server y Bind9. El sistema permite aprovisionar instancias web bajo demanda, registrar dinámicamente sus nombres en una zona DNS local (`grid.lab`) y desplegar contenido web automáticamente.

## 📦 Características

- Aprovisionamiento automatizado de servidores HTTP con Apache.
- Registro dinámico de hosts en Bind9 dentro del dominio `grid.lab`.
- Despliegue de contenido web desde archivos `.zip` enviados por el usuario.
- Dashboard web en Go para gestión de instancias y acceso directo.
- Infraestructura virtualizada con discos multiconexión en VirtualBox.

## 🧱 Componentes

- **Servidor DNS**: VM dedicada con Bind9, zona local `grid.lab`, registro dinámico.
- **Plantilla Apache**: VM Debian 13 CLI con Apache, disco en modo multiconexión.
- **Aplicación Web (Go)**: Interfaz para usuarios, orquestación de VMs, despliegue de contenido.
- **Red VirtualBox**: Configuración de red interna o puente para comunicación entre VMs.

## 🚀 Requisitos

- Oracle VirtualBox
- Debian 13 (CLI)
- Apache2
- Bind9
- Golang 1.20+
- Scripts de automatización (Python)

## 📚 Créditos

Proyecto académico Universidad del Quindío
desarrollado en el curso *Computación en la Nube 2025-2*
Profesores: Carlos Eduardo Gómez Montoya – Juan Sebastián Salazar Osorio  
Desarrolladores: [Jhan Carlos Martinez](https://github.com/KJahn26) - [Juan David Guzman](https://github.com/juandajedrez)
Asistencia técnica: [Microsoft Copilot](https://copilot.microsoft.com)
