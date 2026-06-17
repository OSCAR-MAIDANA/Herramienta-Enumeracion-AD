# Herramienta de Enumeración de Active Directory

Script en Bash diseñado para automatizar la fase de reconocimiento y enumeración en entornos de Active Directory (AD). Este script permite identificar hosts, controladores de dominio (DC) y servicios vulnerables sin depender exclusivamente de protocolos ICMP (ping).

---

## Características Principales

* **Descubrimiento sin PING:** Escaneo de segmentos de red basado en puertos para detectar hosts activos cuando ICMP está bloqueado.
* **Identificación de DC:** Detección automática de Domain Controllers analizando puertos críticos como Kerberos (88) y LDAP (389).
* **Enumera Servicios Críticos:** Módulos especializados para:
    * **SMB:** Listado de shares y sesiones nulas.
    * **LDAP/AD:** Extracción de dominios y usuarios.
    * **Kerberos:** ASREPRoast y Kerberoasting.
    * **Web/RDP:** Enumeración básica y detección de servicios.
* **Flujo Automatizado:** Modo "14) ENUMERACIÓN AUTOMÁTICA" que detecta servicios activos y ejecuta las enumeraciones correspondientes de forma secuencial.

## Requisitos del Sistema

* **Sistema Operativo:** Entorno basado en Linux o subsistema compatible (Kali Linux, Ubuntu, WSL).
* **Dependencias:** El script utiliza herramientas estándar de enumeración. Asegúrate de tener instaladas las siguientes para un funcionamiento completo:
    * `nmap`, `enum4linux`, `crackmapexec` (o `nxc`), `rpcclient`.
    * `ldapsearch`, `impacket` (GetADUsers, GetNPUsers, GetUserSPNs).
    * `kerbrute`, `whatweb`, `nikto`, `curl`.

## Instrucciones de Uso

Clonar el repositorio:
```bash
git clone https://github.com/OSCAR-MAIDANA/Herramienta-Enumeracion-AD.git
cd Herramienta-Enumeracion-AD
```
## Descargo de Responsabilidad
Este script ha sido desarrollado exclusivamente con fines educativos y de auditoría de seguridad autorizada. El uso de esta herramienta contra objetivos sin el consentimiento previo y por escrito de los propietarios es ilegal. El autor no se hace responsable del mal uso o de los daños causados por este software.
