# Herramienta-Enumeracion-AD
Script en Bash diseñado para la automatización del descubrimiento de hosts activos en la red local y la enumeración de puertos clave (como SMB y Active Directory) de forma eficiente y sin el uso de ping (ICMP).

## Características Principales
* Escaneo optimizado de segmentos de red sin interactuar con el protocolo ICMP (ping).
* Identificación automatizada de servicios críticos en entornos Active Directory (como SMB y RPC).
* Salida estructurada y legible directamente en la consola.

## Requisitos del Sistema
* Entorno basado en Linux o subsistema compatible (como WSL en Windows, Kali Linux o Ubuntu).
* Permisos de ejecución sobre el archivo del script.

## Instrucciones de Uso
Para desplegar y ejecutar esta herramienta en un entorno de pruebas, descargue el archivo `.sh` o clone este repositorio, y ejecute los siguientes comandos en la terminal:

```bash
# Asignar permisos de ejecución al script
chmod +x "Herramienta enumeracion AD.sh"

# Ejecutar el script
./"Herramienta enumeracion AD.sh"
