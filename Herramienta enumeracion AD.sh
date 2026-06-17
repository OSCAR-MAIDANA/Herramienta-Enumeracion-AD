#!/bin/bash


# Colores

greenColour="\e[0;32m\033[1m"

endColour="\033[0m\e[0m"

redColour="\e[0;31m\033[1m"

blueColour="\e[0;34m\033[1m"

yellowColour="\e[0;33m\033[1m"

purpleColour="\e[0;35m\033[1m"

turquoiseColour="\e[0;36m\033[1m"

grayColour="\e[0;37m\033[1m"


# Ctrl+C

trap ctrl_c INT


function ctrl_c(){

    echo -e "\n${redColour}[!] Saliendo...${endColour}\n"

    tput cnorm; exit 1

}


# Banner

echo -e "${purpleColour}"

echo "  ____   ____   ____  _                _   "

echo " |   \ / __| |   \()_   _____  ___| |_ "

echo " | | | | |     | |_) | \ \ / /  \/ _| __|"

echo " | |_| | |___  |  __/| |\ V / (_) | |_| |_ "

echo " |____/ \____| |_|   |_| \_/ \___/ \__|\__|"

echo -e "        ${yellowColour}[SIN PING - Port Based Discovery]${purpleColour}"

echo -e "${endColour}"


# Variables

RED=$1

declare -a HOSTS_ACTIVOS


if [ $# -eq 0 ]; then

    echo -e "${redColour}[!] Uso: $0 <red_objetivo>${endColour}"

    echo -e "${yellowColour}[*] Ejemplo: $0 172.16.1.0/24${endColour}\n"

    exit 1

fi


tput civis


# Función para descubrir hosts SIN PING (por puertos comunes)

function descubrir_hosts_sin_ping(){

    echo -e "${blueColour}[*] Descubriendo hosts en $RED (sin ICMP, usando puertos)...${endColour}\n"

    echo -e "${grayColour}[*] Escaneando puertos: 80,443,445,139,22,21,3389,88,389${endColour}\n"

    

    HOSTS_ACTIVOS=()

    

    for i in $(seq 1 254); do

        ip="${RED%.*}.$i"

        (

            # Probar múltiples puertos comunes

            for puerto in 80 443 445 139 22 21 3389 88 389; do

                timeout 1 bash -c "echo '' > /dev/tcp/$ip/$puerto" 2>/dev/null && {

                    echo -e "${greenColour}[+] Host activo: $ip (puerto $puerto responde)${endColour}"

                    echo "$ip" >> /tmp/hosts_activos_$$.tmp

                    break

                }

            done

        ) &

    done

    wait

    

    # Leer hosts únicos

    if [ -f /tmp/hosts_activos_$$.tmp ]; then

        HOSTS_ACTIVOS=($(sort -u /tmp/hosts_activos_$$.tmp))

        rm /tmp/hosts_activos_$$.tmp

        echo -e "\n${turquoiseColour}[*] Total de hosts activos encontrados: ${#HOSTS_ACTIVOS[@]}${endColour}\n"

    else

        echo -e "\n${redColour}[!] No se encontraron hosts activos${endColour}\n"

    fi

}


# Función para escanear puertos típicos de DC

function escanear_dc(){

    local ip=$1

    echo -e "\n${yellowColour}[*] Escaneando puertos de DC en $ip...${endColour}\n"

    

    puertos_abiertos=0

    

    for puerto in 53 88 135 139 389 445 464 593 636 3268 3269 5985 5986 9389; do

        (timeout 1 bash -c "echo '' > /dev/tcp/$ip/$puerto" 2>/dev/null && {

            echo -e "${greenColour}[+] Puerto $puerto abierto en $ip${endColour}"

            ((puertos_abiertos++))

        }) &

    done

    wait

    

    return $puertos_abiertos

}


# Función para identificar DC (SIN PING)

function identificar_dc_sin_ping(){

    echo -e "\n${purpleColour}[*] Identificando Domain Controllers (método sin PING)...${endColour}\n"

    

    for i in $(seq 1 254); do

        ip="${RED%.*}.$i"

        (

            puertos_dc=0

            es_dc=false

            

            # Verificar puertos CRÍTICOS de DC (orden de importancia)

            # Kerberos (88) - MUY importante

            timeout 1 bash -c "echo '' > /dev/tcp/$ip/88" 2>/dev/null && {

                ((puertos_dc++))

                es_dc=true

            }

            

            # LDAP (389) - MUY importante

            timeout 1 bash -c "echo '' > /dev/tcp/$ip/389" 2>/dev/null && {

                ((puertos_dc++))

                es_dc=true

            }

            

            # SMB (445) - Común en DCs

            timeout 1 bash -c "echo '' > /dev/tcp/$ip/445" 2>/dev/null && {

                ((puertos_dc++))

            }

            

            # DNS (53) - Común en DCs

            timeout 1 bash -c "echo '' > /dev/tcp/$ip/53" 2>/dev/null && {

                ((puertos_dc++))

            }

            

            # Si tiene Kerberos O LDAP, es muy probable que sea DC

            if [ "$es_dc" = true ]; then

                echo -e "${greenColour}${greenColour}[++] ██ DOMAIN CONTROLLER ENCONTRADO: $ip ██${endColour}"

                escanear_dc $ip

            elif [ $puertos_dc -ge 2 ]; then

                echo -e "${yellowColour}[+] Posible Windows Server: $ip (revisar manualmente)${endColour}"

            fi

        ) &

    done

    wait

}


# Función para escaneo agresivo de puertos

function escanear_top_ports(){

    local ip=$1

    echo -e "\n${turquoiseColour}[*] Escaneando top 100 puertos en $ip...${endColour}\n"

    

    # Top puertos comunes

    top_ports=(21 22 23 25 53 80 88 110 111 135 139 143 389 443 445 464 593 636 993 995 1433 1521 3268 3269 3306 3389 5432 5800 5900 5985 5986 8080 8443 9389)

    

    for puerto in "${top_ports[@]}"; do

        (timeout 1 bash -c "echo '' > /dev/tcp/$ip/$puerto" 2>/dev/null && \

            echo -e "${greenColour}[+] Puerto $puerto abierto${endColour}") &

    done

    wait

}


# Función para escaneo completo de puertos

function escanear_todos_puertos(){

    local ip=$1

    echo -e "\n${turquoiseColour}[*] Escaneando TODOS los puertos en $ip (1-65535)...${endColour}\n"

    echo -e "${yellowColour}[!] Esto puede tardar varios minutos...${endColour}\n"

    

    for puerto in $(seq 1 65535); do

        (timeout 1 bash -c "echo '' > /dev/tcp/$ip/$puerto" 2>/dev/null && \

            echo -e "${greenColour}[+] Puerto $puerto abierto${endColour}") &

        

        # Limitar procesos concurrentes

        if [ $(jobs -r | wc -l) -ge 100 ]; then

            wait -n

        fi

    done

    wait

}


# Función para detectar versiones de servicios

function detectar_versiones(){

    local ip=$1

    echo -e "\n${purpleColour}[*] Detectando versiones de servicios en $ip...${endColour}\n"

    

    # Array de puertos comunes a verificar

    declare -A puertos_servicios=(

        [21]="FTP"

        [22]="SSH"

        [25]="SMTP"

        [53]="DNS"

        [80]="HTTP"

        [88]="Kerberos"

        [110]="POP3"

        [135]="RPC"

        [139]="NetBIOS"

        [143]="IMAP"

        [389]="LDAP"

        [443]="HTTPS"

        [445]="SMB"

        [464]="Kerberos-change"

        [587]="SMTP-TLS"

        [593]="RPC-HTTP"

        [636]="LDAPS"

        [993]="IMAPS"

        [995]="POP3S"

        [1433]="MSSQL"

        [3268]="LDAP-GC"

        [3269]="LDAPS-GC"

        [3306]="MySQL"

        [3389]="RDP"

        [5432]="PostgreSQL"

        [5985]="WinRM-HTTP"

        [5986]="WinRM-HTTPS"

        [8080]="HTTP-Alt"

        [8443]="HTTPS-Alt"

        [9389]="ADWS"

    )

    

    echo -e "${blueColour}[*] Escaneando puertos y capturando banners...${endColour}\n"

    

    for puerto in "${!puertos_servicios[@]}"; do

        (

            # Verificar si el puerto está abierto

            timeout 2 bash -c "echo '' > /dev/tcp/$ip/$puerto" 2>/dev/null && {

                servicio="${puertos_servicios[$puerto]}"

                echo -e "${greenColour}[+] Puerto $puerto ($servicio) - ABIERTO${endColour}"

                

                # Intentar capturar banner

                banner=$(timeout 3 bash -c "echo -e '\r\n' | nc -w 2 $ip $puerto 2>/dev/null | head -n 5 | tr -d '\0' | strings")

                

                if [ ! -z "$banner" ]; then

                    echo -e "${turquoiseColour}    └─ Banner: ${banner:0:200}${endColour}"

                fi

                

                # Detecciones específicas por servicio

                case $puerto in

                    21) # FTP

                        ftp_banner=$(echo -e "QUIT\r\n" | timeout 3 nc -w 2 $ip 21 2>/dev/null | head -n 1)

                        [ ! -z "$ftp_banner" ] && echo -e "${yellowColour}    └─ FTP: $ftp_banner${endColour}"

                        ;;

                    22) # SSH

                        ssh_banner=$(timeout 3 nc -w 2 $ip 22 2>/dev/null | head -n 1)

                        [ ! -z "$ssh_banner" ] && echo -e "${yellowColour}    └─ SSH: $ssh_banner${endColour}"

                        ;;

                    80|8080) # HTTP

                        http_response=$(echo -e "GET / HTTP/1.0\r\n\r\n" | timeout 3 nc -w 2 $ip $puerto 2>/dev/null | head -n 10)

                        server=$(echo "$http_response" | grep -i "^Server:" | cut -d' ' -f2-)

                        [ ! -z "$server" ] && echo -e "${yellowColour}    └─ HTTP Server: $server${endColour}"

                        ;;

                    445) # SMB

                        echo -e "${yellowColour}    └─ SMB detectado (usa: smbclient -L //$ip -N para versión)${endColour}"

                        ;;

                    3389) # RDP

                        echo -e "${yellowColour}    └─ RDP activo (usa: nmap --script rdp-ntlm-info para más info)${endColour}"

                        ;;

                    5985|5986) # WinRM

                        echo -e "${yellowColour}    └─ WinRM activo (posible administración remota Windows)${endColour}"

                        ;;

                esac

            }

        ) &

    done

    wait

    

    echo -e "\n${turquoiseColour}[*] Intentando identificar SO por TTL...${endColour}"

    # Intentar ping para detectar TTL (si ICMP está habilitado)

    ttl=$(timeout 2 ping -c 1 $ip 2>/dev/null | grep "ttl=" | awk -F"ttl=" '{print $2}' | awk '{print $1}')

    

    if [ ! -z "$ttl" ]; then

        if [ $ttl -ge 64 ] && [ $ttl -le 65 ]; then

            echo -e "${greenColour}[+] TTL=$ttl → Probablemente Linux/Unix${endColour}"

        elif [ $ttl -ge 127 ] && [ $ttl -le 129 ]; then

            echo -e "${greenColour}[+] TTL=$ttl → Probablemente Windows${endColour}"

        elif [ $ttl -ge 254 ]; then

            echo -e "${greenColour}[+] TTL=$ttl → Probablemente Cisco/Network Device${endColour}"

        else

            echo -e "${yellowColour}[+] TTL=$ttl → SO desconocido${endColour}"

        fi

    else

        echo -e "${grayColour}[-] ICMP bloqueado, no se pudo determinar TTL${endColour}"

    fi

}


# Función para escaneo intensivo con versiones

function escaneo_intensivo_versiones(){

    local ip=$1

    echo -e "\n${purpleColour}[*] ESCANEO INTENSIVO con detección de versiones en $ip${endColour}\n"

    

    # Primero escanear puertos DC

    escanear_dc $ip

    

    # Luego detectar versiones

    detectar_versiones $ip

}


# Función para enumeración SMB completa

function enum_smb(){

    local ip=$1

    echo -e "\n${purpleColour}[*] ENUMERACIÓN SMB en $ip${endColour}\n"

    

    # Crear directorio de resultados

    mkdir -p enum_results_$ip 2>/dev/null

    

    echo -e "${yellowColour}[>] Listando shares SMB...${endColour}"

    timeout 30 smbclient -L //$ip -N 2>/dev/null | tee enum_results_$ip/smb_shares.txt

    [ ${PIPESTATUS[0]} -eq 0 ] && echo -e "${greenColour}[✓] Shares guardados${endColour}" || echo -e "${redColour}[✗] Error en smbclient${endColour}"

    

    echo -e "\n${yellowColour}[>] Ejecutando enum4linux...${endColour}"

    if command -v enum4linux &> /dev/null; then

        timeout 60 enum4linux -a $ip 2>/dev/null | tee enum_results_$ip/enum4linux.txt

        echo -e "${greenColour}[✓] enum4linux completado${endColour}"

    else

        echo -e "${redColour}[!] enum4linux no instalado${endColour}"

    fi

    

    echo -e "\n${yellowColour}[>] CrackMapExec - Shares...${endColour}"

    if command -v crackmapexec &> /dev/null || command -v nxc &> /dev/null; then

        CMD=$(command -v nxc &> /dev/null && echo "nxc" || echo "crackmapexec")

        timeout 30 $CMD smb $ip --shares 2>/dev/null | tee enum_results_$ip/cme_shares.txt

        echo -e "${greenColour}[✓] CME shares completado${endColour}"

    else

        echo -e "${redColour}[!] CrackMapExec/NetExec no instalado${endColour}"

    fi

    

    echo -e "\n${yellowColour}[>] Intentando null session con rpcclient...${endColour}"

    if command -v rpcclient &> /dev/null; then

        echo -e "enumdomusers\nquit" | timeout 30 rpcclient -U "" -N $ip 2>/dev/null | tee enum_results_$ip/rpcclient_users.txt

        echo -e "${greenColour}[✓] rpcclient completado${endColour}"

    else

        echo -e "${redColour}[!] rpcclient no instalado${endColour}"

    fi

    

    echo -e "\n${turquoiseColour}[*] Resultados guardados en: enum_results_$ip/${endColour}"

}


# Función para enumeración LDAP/AD

function enum_ldap(){

    local ip=$1

    echo -e "\n${purpleColour}[*] ENUMERACIÓN LDAP/AD en $ip${endColour}\n"

    

    mkdir -p enum_results_$ip 2>/dev/null

    

    echo -e "${yellowColour}[>] ldapsearch - RootDSE...${endColour}"

    if command -v ldapsearch &> /dev/null; then

        timeout 30 ldapsearch -x -h $ip -s base namingcontexts 2>/dev/null | tee enum_results_$ip/ldap_rootdse.txt

        

        # Intentar extraer el dominio

        domain=$(grep "defaultNamingContext" enum_results_$ip/ldap_rootdse.txt 2>/dev/null | awk '{print $2}')

        if [ ! -z "$domain" ]; then

            echo -e "${greenColour}[+] Dominio encontrado: $domain${endColour}"

            

            echo -e "\n${yellowColour}[>] Enumerando usuarios del dominio...${endColour}"

            timeout 60 ldapsearch -x -h $ip -b "$domain" "(objectClass=user)" sAMAccountName 2>/dev/null | grep "sAMAccountName" | tee enum_results_$ip/ldap_users.txt

        fi

        echo -e "${greenColour}[✓] LDAP enum completado${endColour}"

    else

        echo -e "${redColour}[!] ldapsearch no instalado${endColour}"

    fi

    

    echo -e "\n${yellowColour}[>] Intentando GetADUsers.py (Impacket)...${endColour}"

    if command -v GetADUsers.py &> /dev/null; then

        timeout 30 GetADUsers.py -all -dc-ip $ip 'DOMAIN/' 2>/dev/null | tee enum_results_$ip/impacket_users.txt

        echo -e "${greenColour}[✓] GetADUsers completado${endColour}"

    else

        echo -e "${redColour}[!] Impacket GetADUsers.py no instalado${endColour}"

    fi

}


# Función para enumeración Kerberos

function enum_kerberos(){

    local ip=$1

    echo -e "\n${purpleColour}[*] ENUMERACIÓN KERBEROS en $ip${endColour}\n"

    

    mkdir -p enum_results_$ip 2>/dev/null

    

    read -p "$(echo -e ${yellowColour}"[?] Dominio (ej: DOMAIN.LOCAL): "${endColour})" domain

    

    if [ -z "$domain" ]; then

        echo -e "${redColour}[!] Dominio requerido para enumeración Kerberos${endColour}"

        return

    fi

    

    echo -e "\n${yellowColour}[>] ASREPRoast - GetNPUsers.py...${endColour}"

    if command -v GetNPUsers.py &> /dev/null; then

        timeout 60 GetNPUsers.py $domain/ -dc-ip $ip -no-pass -usersfile /usr/share/wordlists/usernames.txt 2>/dev/null | tee enum_results_$ip/asreproast.txt

        echo -e "${greenColour}[✓] ASREPRoast completado${endColour}"

    else

        echo -e "${redColour}[!] GetNPUsers.py no instalado${endColour}"

    fi

    

    echo -e "\n${yellowColour}[>] Enumerando SPNs - GetUserSPNs.py...${endColour}"

    if command -v GetUserSPNs.py &> /dev/null; then

        read -p "$(echo -e ${yellowColour}"[?] Usuario (dejar vacío para guest): "${endColour})" username

        read -sp "$(echo -e ${yellowColour}"[?] Password (Enter para vacío): "${endColour})" password

        echo

        

        if [ -z "$username" ]; then

            timeout 60 GetUserSPNs.py $domain/ -dc-ip $ip -no-preauth 2>/dev/null | tee enum_results_$ip/spns.txt

        else

            timeout 60 GetUserSPNs.py $domain/$username:$password -dc-ip $ip 2>/dev/null | tee enum_results_$ip/spns.txt

        fi

        echo -e "${greenColour}[✓] SPN enum completado${endColour}"

    else

        echo -e "${redColour}[!] GetUserSPNs.py no instalado${endColour}"

    fi

    

    echo -e "\n${yellowColour}[>] Kerbrute - User enumeration...${endColour}"

    if command -v kerbrute &> /dev/null; then

        if [ -f /usr/share/wordlists/usernames.txt ]; then

            timeout 120 kerbrute userenum --dc $ip -d $domain /usr/share/wordlists/usernames.txt 2>/dev/null | tee enum_results_$ip/kerbrute.txt

            echo -e "${greenColour}[✓] Kerbrute completado${endColour}"

        else

            echo -e "${redColour}[!] Wordlist /usr/share/wordlists/usernames.txt no encontrado${endColour}"

        fi

    else

        echo -e "${redColour}[!] kerbrute no instalado${endColour}"

    fi

}


# Función para enumeración HTTP/Web

function enum_web(){

    local ip=$1

    echo -e "\n${purpleColour}[*] ENUMERACIÓN WEB en $ip${endColour}\n"

    

    mkdir -p enum_results_$ip 2>/dev/null

    

    # Detectar puertos HTTP

    puertos_http=()

    for puerto in 80 443 8080 8443; do

        timeout 2 bash -c "echo '' > /dev/tcp/$ip/$puerto" 2>/dev/null && puertos_http+=($puerto)

    done

    

    if [ ${#puertos_http[@]} -eq 0 ]; then

        echo -e "${redColour}[!] No se encontraron puertos HTTP abiertos${endColour}"

        return

    fi

    

    echo -e "${greenColour}[+] Puertos HTTP encontrados: ${puertos_http[@]}${endColour}\n"

    

    for puerto in "${puertos_http[@]}"; do

        protocolo="http"

        [ $puerto -eq 443 ] || [ $puerto -eq 8443 ] && protocolo="https"

        

        echo -e "${yellowColour}[>] Whatweb en $protocolo://$ip:$puerto${endColour}"

        if command -v whatweb &> /dev/null; then

            timeout 30 whatweb $protocolo://$ip:$puerto 2>/dev/null | tee enum_results_$ip/whatweb_$puerto.txt

        else

            echo -e "${redColour}[!] whatweb no instalado${endColour}"

        fi

        

        echo -e "\n${yellowColour}[>] Nikto en $protocolo://$ip:$puerto${endColour}"

        if command -v nikto &> /dev/null; then

            timeout 120 nikto -h $protocolo://$ip:$puerto 2>/dev/null | tee enum_results_$ip/nikto_$puerto.txt

        else

            echo -e "${redColour}[!] nikto no instalado${endColour}"

        fi

        

        echo -e "\n${yellowColour}[>] Capturando cabeceras HTTP...${endColour}"

        timeout 10 curl -I -k $protocolo://$ip:$puerto 2>/dev/null | tee enum_results_$ip/headers_$puerto.txt

    done

    

    echo -e "\n${greenColour}[✓] Enumeración web completada${endColour}"

}


# Función para enumeración RDP

function enum_rdp(){

    local ip=$1

    echo -e "\n${purpleColour}[*] ENUMERACIÓN RDP en $ip${endColour}\n"

    

    mkdir -p enum_results_$ip 2>/dev/null

    

    echo -e "${yellowColour}[>] Verificando RDP con nmap...${endColour}"

    if command -v nmap &> /dev/null; then

        timeout 60 nmap -p 3389 --script rdp-ntlm-info,rdp-enum-encryption $ip 2>/dev/null | tee enum_results_$ip/rdp_info.txt

        echo -e "${greenColour}[✓] RDP enum completado${endColour}"

    else

        echo -e "${redColour}[!] nmap no instalado${endColour}"

    fi

}


# Función de enumeración automática completa

function enum_automatico(){

    local ip=$1

    echo -e "\n${purpleColour}╔════════════════════════════════════════════╗${endColour}"

    echo -e "${purpleColour}║  ENUMERACIÓN AUTOMÁTICA COMPLETA          ║${endColour}"

    echo -e "${purpleColour}╚════════════════════════════════════════════╝${endColour}\n"

    

    mkdir -p enum_results_$ip 2>/dev/null

    

    echo -e "${blueColour}[*] Detectando servicios activos...${endColour}\n"

    

    # Detectar qué servicios están activos

    servicios_activos=()

    

    # SMB (445)

    timeout 2 bash -c "echo '' > /dev/tcp/$ip/445" 2>/dev/null && {

        servicios_activos+=("SMB")

        echo -e "${greenColour}[+] SMB detectado (445)${endColour}"

    }

    

    # LDAP (389)

    timeout 2 bash -c "echo '' > /dev/tcp/$ip/389" 2>/dev/null && {

        servicios_activos+=("LDAP")

        echo -e "${greenColour}[+] LDAP detectado (389)${endColour}"

    }

    

    # Kerberos (88)

    timeout 2 bash -c "echo '' > /dev/tcp/$ip/88" 2>/dev/null && {

        servicios_activos+=("KERBEROS")

        echo -e "${greenColour}[+] Kerberos detectado (88)${endColour}"

    }

    

    # HTTP (80, 443, 8080, 8443)

    for puerto in 80 443 8080 8443; do

        timeout 2 bash -c "echo '' > /dev/tcp/$ip/$puerto" 2>/dev/null && {

            if [[ ! " ${servicios_activos[@]} " =~ " WEB " ]]; then

                servicios_activos+=("WEB")

                echo -e "${greenColour}[+] HTTP/HTTPS detectado${endColour}"

            fi

            break

        }

    done

    

    # RDP (3389)

    timeout 2 bash -c "echo '' > /dev/tcp/$ip/3389" 2>/dev/null && {

        servicios_activos+=("RDP")

        echo -e "${greenColour}[+] RDP detectado (3389)${endColour}"

    }

    

    if [ ${#servicios_activos[@]} -eq 0 ]; then

        echo -e "\n${redColour}[!] No se detectaron servicios enumerables${endColour}"

        return

    fi

    

    echo -e "\n${turquoiseColour}[*] Servicios a enumerar: ${servicios_activos[@]}${endColour}\n"

    sleep 2

    

    # Ejecutar enumeraciones según servicios detectados

    for servicio in "${servicios_activos[@]}"; do

        case $servicio in

            SMB)

                enum_smb $ip

                ;;

            LDAP)

                enum_ldap $ip

                ;;

            KERBEROS)

                enum_kerberos $ip

                ;;

            WEB)

                enum_web $ip

                ;;

            RDP)

                enum_rdp $ip

                ;;

        esac

        echo -e "\n${grayColour}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${endColour}\n"

    done

    

    echo -e "\n${greenColour}╔════════════════════════════════════════════╗${endColour}"

    echo -e "${greenColour}║  ✓ ENUMERACIÓN COMPLETA FINALIZADA        ║${endColour}"

    echo -e "${greenColour}╚════════════════════════════════════════════╝${endColour}"

    echo -e "${turquoiseColour}[*] Todos los resultados en: enum_results_$ip/${endColour}\n"

}


# Menú principal

echo -e "${yellowColour}[?] Selecciona una opción:${endColour}\n"

echo -e "${grayColour}1) Descubrimiento de hosts SIN PING (recomendado)${endColour}"

echo -e "${grayColour}2) Identificar Domain Controllers SIN PING${endColour}"

echo -e "${grayColour}3) Escanear puertos DC de una IP específica${endColour}"

echo -e "${grayColour}4) Escaneo COMPLETO (descubrir + identificar DCs)${endColour}"

echo -e "${grayColour}5) Escanear TOP 100 puertos de una IP${endColour}"

echo -e "${grayColour}6) Escanear TODOS los puertos (1-65535) de una IP${endColour}"

echo -e "${grayColour}7) Detectar VERSIONES de servicios de una IP${endColour}"

echo -e "${grayColour}8) Escaneo INTENSIVO (puertos + versiones + banners)${endColour}"

echo -e "${purpleColour}--- SCRIPTS DE ENUMERACIÓN ---${endColour}"

echo -e "${grayColour}9) Enumeración SMB completa${endColour}"

echo -e "${grayColour}10) Enumeración LDAP/Active Directory${endColour}"

echo -e "${grayColour}11) Enumeración Kerberos (ASREPRoast/Kerberoasting)${endColour}"

echo -e "${grayColour}12) Enumeración HTTP/Web${endColour}"

echo -e "${grayColour}13) Enumeración RDP${endColour}"

echo -e "${greenColour}14) ENUMERACIÓN AUTOMÁTICA (detecta y ejecuta todo)${endColour}"

read -p "$(echo -e ${turquoiseColour}"> "${endColour})" opcion


case $opcion in

    1)

        descubrir_hosts_sin_ping

        ;;

    2)

        identificar_dc_sin_ping

        ;;

    3)

        read -p "$(echo -e ${yellowColour}"[?] IP del DC: "${endColour})" target_ip

        escanear_dc $target_ip

        ;;

    4)

        echo -e "${blueColour}[*] Iniciando escaneo completo...${endColour}\n"

        identificar_dc_sin_ping

        ;;

    5)

        read -p "$(echo -e ${yellowColour}"[?] IP del objetivo: "${endColour})" target_ip

        escanear_top_ports $target_ip

        ;;

    6)

        read -p "$(echo -e ${yellowColour}"[?] IP del objetivo: "${endColour})" target_ip

        escanear_todos_puertos $target_ip

        ;;

    7)

        read -p "$(echo -e ${yellowColour}"[?] IP del objetivo: "${endColour})" target_ip

        detectar_versiones $target_ip

        ;;

    8)

        read -p "$(echo -e ${yellowColour}"[?] IP del objetivo: "${endColour})" target_ip

        escaneo_intensivo_versiones $target_ip

        ;;

    9)

        read -p "$(echo -e ${yellowColour}"[?] IP del objetivo: "${endColour})" target_ip

        enum_smb $target_ip

        ;;

    10)

        read -p "$(echo -e ${yellowColour}"[?] IP del objetivo: "${endColour})" target_ip

        enum_ldap $target_ip

        ;;

    11)

        read -p "$(echo -e ${yellowColour}"[?] IP del objetivo: "${endColour})" target_ip

        enum_kerberos $target_ip

        ;;

    12)

        read -p "$(echo -e ${yellowColour}"[?] IP del objetivo: "${endColour})" target_ip

        enum_web $target_ip

        ;;

    13)

        read -p "$(echo -e ${yellowColour}"[?] IP del objetivo: "${endColour})" target_ip

        enum_rdp $target_ip

        ;;

    14)

        read -p "$(echo -e ${yellowColour}"[?] IP del objetivo: "${endColour})" target_ip

        enum_automatico $target_ip

        ;;

    *)

        echo -e "${redColour}[!] Opción inválida${endColour}"

        tput cnorm

        exit 1

        ;;

esac


tput cnorm

echo -e "\n${greenColour}[✓] Escaneo completado${endColour}\n"

#!/bin/bash


# Colores

greenColour="\e[0;32m\033[1m"

endColour="\033[0m\e[0m"

redColour="\e[0;31m\033[1m"

blueColour="\e[0;34m\033[1m"

yellowColour="\e[0;33m\033[1m"

purpleColour="\e[0;35m\033[1m"

turquoiseColour="\e[0;36m\033[1m"

grayColour="\e[0;37m\033[1m"


# Ctrl+C

trap ctrl_c INT


function ctrl_c(){

    echo -e "\n${redColour}[!] Saliendo...${endColour}\n"

    tput cnorm; exit 1

}


# Banner

echo -e "${purpleColour}"

echo "  ____   ____   ____  _                _   "

echo " |   \ / __| |   \()_   _____  ___| |_ "

echo " | | | | |     | |_) | \ \ / /  \/ _| __|"

echo " | |_| | |___  |  __/| |\ V / (_) | |_| |_ "

echo " |____/ \____| |_|   |_| \_/ \___/ \__|\__|"

echo -e "        ${yellowColour}[SIN PING - Port Based Discovery]${purpleColour}"

echo -e "${endColour}"


# Variables

RED=$1

declare -a HOSTS_ACTIVOS


if [ $# -eq 0 ]; then

    echo -e "${redColour}[!] Uso: $0 <red_objetivo>${endColour}"

    echo -e "${yellowColour}[*] Ejemplo: $0 172.16.1.0/24${endColour}\n"

    exit 1

fi


tput civis


# Función para descubrir hosts SIN PING (por puertos comunes)

function descubrir_hosts_sin_ping(){

    echo -e "${blueColour}[*] Descubriendo hosts en $RED (sin ICMP, usando puertos)...${endColour}\n"

    echo -e "${grayColour}[*] Escaneando puertos: 80,443,445,139,22,21,3389,88,389${endColour}\n"

    

    HOSTS_ACTIVOS=()

    

    for i in $(seq 1 254); do

        ip="${RED%.*}.$i"

        (

            # Probar múltiples puertos comunes

            for puerto in 80 443 445 139 22 21 3389 88 389; do

                timeout 1 bash -c "echo '' > /dev/tcp/$ip/$puerto" 2>/dev/null && {

                    echo -e "${greenColour}[+] Host activo: $ip (puerto $puerto responde)${endColour}"

                    echo "$ip" >> /tmp/hosts_activos_$$.tmp

                    break

                }

            done

        ) &

    done

    wait

    

    # Leer hosts únicos

    if [ -f /tmp/hosts_activos_$$.tmp ]; then

        HOSTS_ACTIVOS=($(sort -u /tmp/hosts_activos_$$.tmp))

        rm /tmp/hosts_activos_$$.tmp

        echo -e "\n${turquoiseColour}[*] Total de hosts activos encontrados: ${#HOSTS_ACTIVOS[@]}${endColour}\n"

    else

        echo -e "\n${redColour}[!] No se encontraron hosts activos${endColour}\n"

    fi

}


# Función para escanear puertos típicos de DC

function escanear_dc(){

    local ip=$1

    echo -e "\n${yellowColour}[*] Escaneando puertos de DC en $ip...${endColour}\n"

    

    puertos_abiertos=0

    

    for puerto in 53 88 135 139 389 445 464 593 636 3268 3269 5985 5986 9389; do

        (timeout 1 bash -c "echo '' > /dev/tcp/$ip/$puerto" 2>/dev/null && {

            echo -e "${greenColour}[+] Puerto $puerto abierto en $ip${endColour}"

            ((puertos_abiertos++))

        }) &

    done

    wait

    

    return $puertos_abiertos

}


# Función para identificar DC (SIN PING)

function identificar_dc_sin_ping(){

    echo -e "\n${purpleColour}[*] Identificando Domain Controllers (método sin PING)...${endColour}\n"

    

    for i in $(seq 1 254); do

        ip="${RED%.*}.$i"

        (

            puertos_dc=0

            es_dc=false

            

            # Verificar puertos CRÍTICOS de DC (orden de importancia)

            # Kerberos (88) - MUY importante

            timeout 1 bash -c "echo '' > /dev/tcp/$ip/88" 2>/dev/null && {

                ((puertos_dc++))

                es_dc=true

            }

            

            # LDAP (389) - MUY importante

            timeout 1 bash -c "echo '' > /dev/tcp/$ip/389" 2>/dev/null && {

                ((puertos_dc++))

                es_dc=true

            }

            

            # SMB (445) - Común en DCs

            timeout 1 bash -c "echo '' > /dev/tcp/$ip/445" 2>/dev/null && {

                ((puertos_dc++))

            }

            

            # DNS (53) - Común en DCs

            timeout 1 bash -c "echo '' > /dev/tcp/$ip/53" 2>/dev/null && {

                ((puertos_dc++))

            }

            

            # Si tiene Kerberos O LDAP, es muy probable que sea DC

            if [ "$es_dc" = true ]; then

                echo -e "${greenColour}${greenColour}[++] ██ DOMAIN CONTROLLER ENCONTRADO: $ip ██${endColour}"

                escanear_dc $ip

            elif [ $puertos_dc -ge 2 ]; then

                echo -e "${yellowColour}[+] Posible Windows Server: $ip (revisar manualmente)${endColour}"

            fi

        ) &

    done

    wait

}


# Función para escaneo agresivo de puertos

function escanear_top_ports(){

    local ip=$1

    echo -e "\n${turquoiseColour}[*] Escaneando top 100 puertos en $ip...${endColour}\n"

    

    # Top puertos comunes

    top_ports=(21 22 23 25 53 80 88 110 111 135 139 143 389 443 445 464 593 636 993 995 1433 1521 3268 3269 3306 3389 5432 5800 5900 5985 5986 8080 8443 9389)

    

    for puerto in "${top_ports[@]}"; do

        (timeout 1 bash -c "echo '' > /dev/tcp/$ip/$puerto" 2>/dev/null && \

            echo -e "${greenColour}[+] Puerto $puerto abierto${endColour}") &

    done

    wait

}


# Función para escaneo completo de puertos

function escanear_todos_puertos(){

    local ip=$1

    echo -e "\n${turquoiseColour}[*] Escaneando TODOS los puertos en $ip (1-65535)...${endColour}\n"

    echo -e "${yellowColour}[!] Esto puede tardar varios minutos...${endColour}\n"

    

    for puerto in $(seq 1 65535); do

        (timeout 1 bash -c "echo '' > /dev/tcp/$ip/$puerto" 2>/dev/null && \

            echo -e "${greenColour}[+] Puerto $puerto abierto${endColour}") &

        

        # Limitar procesos concurrentes

        if [ $(jobs -r | wc -l) -ge 100 ]; then

            wait -n

        fi

    done

    wait

}


# Función para detectar versiones de servicios

function detectar_versiones(){

    local ip=$1

    echo -e "\n${purpleColour}[*] Detectando versiones de servicios en $ip...${endColour}\n"

    

    # Array de puertos comunes a verificar

    declare -A puertos_servicios=(

        [21]="FTP"

        [22]="SSH"

        [25]="SMTP"

        [53]="DNS"

        [80]="HTTP"

        [88]="Kerberos"

        [110]="POP3"

        [135]="RPC"

        [139]="NetBIOS"

        [143]="IMAP"

        [389]="LDAP"

        [443]="HTTPS"

        [445]="SMB"

        [464]="Kerberos-change"

        [587]="SMTP-TLS"

        [593]="RPC-HTTP"

        [636]="LDAPS"

        [993]="IMAPS"

        [995]="POP3S"

        [1433]="MSSQL"

        [3268]="LDAP-GC"

        [3269]="LDAPS-GC"

        [3306]="MySQL"

        [3389]="RDP"

        [5432]="PostgreSQL"

        [5985]="WinRM-HTTP"

        [5986]="WinRM-HTTPS"

        [8080]="HTTP-Alt"

        [8443]="HTTPS-Alt"

        [9389]="ADWS"

    )

    

    echo -e "${blueColour}[*] Escaneando puertos y capturando banners...${endColour}\n"

    

    for puerto in "${!puertos_servicios[@]}"; do

        (

            # Verificar si el puerto está abierto

            timeout 2 bash -c "echo '' > /dev/tcp/$ip/$puerto" 2>/dev/null && {

                servicio="${puertos_servicios[$puerto]}"

                echo -e "${greenColour}[+] Puerto $puerto ($servicio) - ABIERTO${endColour}"

                

                # Intentar capturar banner

                banner=$(timeout 3 bash -c "echo -e '\r\n' | nc -w 2 $ip $puerto 2>/dev/null | head -n 5 | tr -d '\0' | strings")

                

                if [ ! -z "$banner" ]; then

                    echo -e "${turquoiseColour}    └─ Banner: ${banner:0:200}${endColour}"

                fi

                

                # Detecciones específicas por servicio

                case $puerto in

                    21) # FTP

                        ftp_banner=$(echo -e "QUIT\r\n" | timeout 3 nc -w 2 $ip 21 2>/dev/null | head -n 1)

                        [ ! -z "$ftp_banner" ] && echo -e "${yellowColour}    └─ FTP: $ftp_banner${endColour}"

                        ;;

                    22) # SSH

                        ssh_banner=$(timeout 3 nc -w 2 $ip 22 2>/dev/null | head -n 1)

                        [ ! -z "$ssh_banner" ] && echo -e "${yellowColour}    └─ SSH: $ssh_banner${endColour}"

                        ;;

                    80|8080) # HTTP

                        http_response=$(echo -e "GET / HTTP/1.0\r\n\r\n" | timeout 3 nc -w 2 $ip $puerto 2>/dev/null | head -n 10)

                        server=$(echo "$http_response" | grep -i "^Server:" | cut -d' ' -f2-)

                        [ ! -z "$server" ] && echo -e "${yellowColour}    └─ HTTP Server: $server${endColour}"

                        ;;

                    445) # SMB

                        echo -e "${yellowColour}    └─ SMB detectado (usa: smbclient -L //$ip -N para versión)${endColour}"

                        ;;

                    3389) # RDP

                        echo -e "${yellowColour}    └─ RDP activo (usa: nmap --script rdp-ntlm-info para más info)${endColour}"

                        ;;

                    5985|5986) # WinRM

                        echo -e "${yellowColour}    └─ WinRM activo (posible administración remota Windows)${endColour}"

                        ;;

                esac

            }

        ) &

    done

    wait

    

    echo -e "\n${turquoiseColour}[*] Intentando identificar SO por TTL...${endColour}"

    # Intentar ping para detectar TTL (si ICMP está habilitado)

    ttl=$(timeout 2 ping -c 1 $ip 2>/dev/null | grep "ttl=" | awk -F"ttl=" '{print $2}' | awk '{print $1}')

    

    if [ ! -z "$ttl" ]; then

        if [ $ttl -ge 64 ] && [ $ttl -le 65 ]; then

            echo -e "${greenColour}[+] TTL=$ttl → Probablemente Linux/Unix${endColour}"

        elif [ $ttl -ge 127 ] && [ $ttl -le 129 ]; then

            echo -e "${greenColour}[+] TTL=$ttl → Probablemente Windows${endColour}"

        elif [ $ttl -ge 254 ]; then

            echo -e "${greenColour}[+] TTL=$ttl → Probablemente Cisco/Network Device${endColour}"

        else

            echo -e "${yellowColour}[+] TTL=$ttl → SO desconocido${endColour}"

        fi

    else

        echo -e "${grayColour}[-] ICMP bloqueado, no se pudo determinar TTL${endColour}"

    fi

}


# Función para escaneo intensivo con versiones

function escaneo_intensivo_versiones(){

    local ip=$1

    echo -e "\n${purpleColour}[*] ESCANEO INTENSIVO con detección de versiones en $ip${endColour}\n"

    

    # Primero escanear puertos DC

    escanear_dc $ip

    

    # Luego detectar versiones

    detectar_versiones $ip

}


# Función para enumeración SMB completa

function enum_smb(){

    local ip=$1

    echo -e "\n${purpleColour}[*] ENUMERACIÓN SMB en $ip${endColour}\n"

    

    # Crear directorio de resultados

    mkdir -p enum_results_$ip 2>/dev/null

    

    echo -e "${yellowColour}[>] Listando shares SMB...${endColour}"

    timeout 30 smbclient -L //$ip -N 2>/dev/null | tee enum_results_$ip/smb_shares.txt

    [ ${PIPESTATUS[0]} -eq 0 ] && echo -e "${greenColour}[✓] Shares guardados${endColour}" || echo -e "${redColour}[✗] Error en smbclient${endColour}"

    

    echo -e "\n${yellowColour}[>] Ejecutando enum4linux...${endColour}"

    if command -v enum4linux &> /dev/null; then

        timeout 60 enum4linux -a $ip 2>/dev/null | tee enum_results_$ip/enum4linux.txt

        echo -e "${greenColour}[✓] enum4linux completado${endColour}"

    else

        echo -e "${redColour}[!] enum4linux no instalado${endColour}"

    fi

    

    echo -e "\n${yellowColour}[>] CrackMapExec - Shares...${endColour}"

    if command -v crackmapexec &> /dev/null || command -v nxc &> /dev/null; then

        CMD=$(command -v nxc &> /dev/null && echo "nxc" || echo "crackmapexec")

        timeout 30 $CMD smb $ip --shares 2>/dev/null | tee enum_results_$ip/cme_shares.txt

        echo -e "${greenColour}[✓] CME shares completado${endColour}"

    else

        echo -e "${redColour}[!] CrackMapExec/NetExec no instalado${endColour}"

    fi

    

    echo -e "\n${yellowColour}[>] Intentando null session con rpcclient...${endColour}"

    if command -v rpcclient &> /dev/null; then

        echo -e "enumdomusers\nquit" | timeout 30 rpcclient -U "" -N $ip 2>/dev/null | tee enum_results_$ip/rpcclient_users.txt

        echo -e "${greenColour}[✓] rpcclient completado${endColour}"

    else

        echo -e "${redColour}[!] rpcclient no instalado${endColour}"

    fi

    

    echo -e "\n${turquoiseColour}[*] Resultados guardados en: enum_results_$ip/${endColour}"

}


# Función para enumeración LDAP/AD

function enum_ldap(){

    local ip=$1

    echo -e "\n${purpleColour}[*] ENUMERACIÓN LDAP/AD en $ip${endColour}\n"

    

    mkdir -p enum_results_$ip 2>/dev/null

    

    echo -e "${yellowColour}[>] ldapsearch - RootDSE...${endColour}"

    if command -v ldapsearch &> /dev/null; then

        timeout 30 ldapsearch -x -h $ip -s base namingcontexts 2>/dev/null | tee enum_results_$ip/ldap_rootdse.txt

        

        # Intentar extraer el dominio

        domain=$(grep "defaultNamingContext" enum_results_$ip/ldap_rootdse.txt 2>/dev/null | awk '{print $2}')

        if [ ! -z "$domain" ]; then

            echo -e "${greenColour}[+] Dominio encontrado: $domain${endColour}"

            

            echo -e "\n${yellowColour}[>] Enumerando usuarios del dominio...${endColour}"

            timeout 60 ldapsearch -x -h $ip -b "$domain" "(objectClass=user)" sAMAccountName 2>/dev/null | grep "sAMAccountName" | tee enum_results_$ip/ldap_users.txt

        fi

        echo -e "${greenColour}[✓] LDAP enum completado${endColour}"

    else

        echo -e "${redColour}[!] ldapsearch no instalado${endColour}"

    fi

    

    echo -e "\n${yellowColour}[>] Intentando GetADUsers.py (Impacket)...${endColour}"

    if command -v GetADUsers.py &> /dev/null; then

        timeout 30 GetADUsers.py -all -dc-ip $ip 'DOMAIN/' 2>/dev/null | tee enum_results_$ip/impacket_users.txt

        echo -e "${greenColour}[✓] GetADUsers completado${endColour}"

    else

        echo -e "${redColour}[!] Impacket GetADUsers.py no instalado${endColour}"

    fi

}


# Función para enumeración Kerberos

function enum_kerberos(){

    local ip=$1

    echo -e "\n${purpleColour}[*] ENUMERACIÓN KERBEROS en $ip${endColour}\n"

    

    mkdir -p enum_results_$ip 2>/dev/null

    

    read -p "$(echo -e ${yellowColour}"[?] Dominio (ej: DOMAIN.LOCAL): "${endColour})" domain

    

    if [ -z "$domain" ]; then

        echo -e "${redColour}[!] Dominio requerido para enumeración Kerberos${endColour}"

        return

    fi

    

    echo -e "\n${yellowColour}[>] ASREPRoast - GetNPUsers.py...${endColour}"

    if command -v GetNPUsers.py &> /dev/null; then

        timeout 60 GetNPUsers.py $domain/ -dc-ip $ip -no-pass -usersfile /usr/share/wordlists/usernames.txt 2>/dev/null | tee enum_results_$ip/asreproast.txt

        echo -e "${greenColour}[✓] ASREPRoast completado${endColour}"

    else

        echo -e "${redColour}[!] GetNPUsers.py no instalado${endColour}"

    fi

    

    echo -e "\n${yellowColour}[>] Enumerando SPNs - GetUserSPNs.py...${endColour}"

    if command -v GetUserSPNs.py &> /dev/null; then

        read -p "$(echo -e ${yellowColour}"[?] Usuario (dejar vacío para guest): "${endColour})" username

        read -sp "$(echo -e ${yellowColour}"[?] Password (Enter para vacío): "${endColour})" password

        echo

        

        if [ -z "$username" ]; then

            timeout 60 GetUserSPNs.py $domain/ -dc-ip $ip -no-preauth 2>/dev/null | tee enum_results_$ip/spns.txt

        else

            timeout 60 GetUserSPNs.py $domain/$username:$password -dc-ip $ip 2>/dev/null | tee enum_results_$ip/spns.txt

        fi

        echo -e "${greenColour}[✓] SPN enum completado${endColour}"

    else

        echo -e "${redColour}[!] GetUserSPNs.py no instalado${endColour}"

    fi

    

    echo -e "\n${yellowColour}[>] Kerbrute - User enumeration...${endColour}"

    if command -v kerbrute &> /dev/null; then

        if [ -f /usr/share/wordlists/usernames.txt ]; then

            timeout 120 kerbrute userenum --dc $ip -d $domain /usr/share/wordlists/usernames.txt 2>/dev/null | tee enum_results_$ip/kerbrute.txt

            echo -e "${greenColour}[✓] Kerbrute completado${endColour}"

        else

            echo -e "${redColour}[!] Wordlist /usr/share/wordlists/usernames.txt no encontrado${endColour}"

        fi

    else

        echo -e "${redColour}[!] kerbrute no instalado${endColour}"

    fi

}


# Función para enumeración HTTP/Web

function enum_web(){

    local ip=$1

    echo -e "\n${purpleColour}[*] ENUMERACIÓN WEB en $ip${endColour}\n"

    

    mkdir -p enum_results_$ip 2>/dev/null

    

    # Detectar puertos HTTP

    puertos_http=()

    for puerto in 80 443 8080 8443; do

        timeout 2 bash -c "echo '' > /dev/tcp/$ip/$puerto" 2>/dev/null && puertos_http+=($puerto)

    done

    

    if [ ${#puertos_http[@]} -eq 0 ]; then

        echo -e "${redColour}[!] No se encontraron puertos HTTP abiertos${endColour}"

        return

    fi

    

    echo -e "${greenColour}[+] Puertos HTTP encontrados: ${puertos_http[@]}${endColour}\n"

    

    for puerto in "${puertos_http[@]}"; do

        protocolo="http"

        [ $puerto -eq 443 ] || [ $puerto -eq 8443 ] && protocolo="https"

        

        echo -e "${yellowColour}[>] Whatweb en $protocolo://$ip:$puerto${endColour}"

        if command -v whatweb &> /dev/null; then

            timeout 30 whatweb $protocolo://$ip:$puerto 2>/dev/null | tee enum_results_$ip/whatweb_$puerto.txt

        else

            echo -e "${redColour}[!] whatweb no instalado${endColour}"

        fi

        

        echo -e "\n${yellowColour}[>] Nikto en $protocolo://$ip:$puerto${endColour}"

        if command -v nikto &> /dev/null; then

            timeout 120 nikto -h $protocolo://$ip:$puerto 2>/dev/null | tee enum_results_$ip/nikto_$puerto.txt

        else

            echo -e "${redColour}[!] nikto no instalado${endColour}"

        fi

        

        echo -e "\n${yellowColour}[>] Capturando cabeceras HTTP...${endColour}"

        timeout 10 curl -I -k $protocolo://$ip:$puerto 2>/dev/null | tee enum_results_$ip/headers_$puerto.txt

    done

    

    echo -e "\n${greenColour}[✓] Enumeración web completada${endColour}"

}


# Función para enumeración RDP

function enum_rdp(){

    local ip=$1

    echo -e "\n${purpleColour}[*] ENUMERACIÓN RDP en $ip${endColour}\n"

    

    mkdir -p enum_results_$ip 2>/dev/null

    

    echo -e "${yellowColour}[>] Verificando RDP con nmap...${endColour}"

    if command -v nmap &> /dev/null; then

        timeout 60 nmap -p 3389 --script rdp-ntlm-info,rdp-enum-encryption $ip 2>/dev/null | tee enum_results_$ip/rdp_info.txt

        echo -e "${greenColour}[✓] RDP enum completado${endColour}"

    else

        echo -e "${redColour}[!] nmap no instalado${endColour}"

    fi

}


# Función de enumeración automática completa

function enum_automatico(){

    local ip=$1

    echo -e "\n${purpleColour}╔════════════════════════════════════════════╗${endColour}"

    echo -e "${purpleColour}║  ENUMERACIÓN AUTOMÁTICA COMPLETA          ║${endColour}"

    echo -e "${purpleColour}╚════════════════════════════════════════════╝${endColour}\n"

    

    mkdir -p enum_results_$ip 2>/dev/null

    

    echo -e "${blueColour}[*] Detectando servicios activos...${endColour}\n"

    

    # Detectar qué servicios están activos

    servicios_activos=()

    

    # SMB (445)

    timeout 2 bash -c "echo '' > /dev/tcp/$ip/445" 2>/dev/null && {

        servicios_activos+=("SMB")

        echo -e "${greenColour}[+] SMB detectado (445)${endColour}"

    }

    

    # LDAP (389)

    timeout 2 bash -c "echo '' > /dev/tcp/$ip/389" 2>/dev/null && {

        servicios_activos+=("LDAP")

        echo -e "${greenColour}[+] LDAP detectado (389)${endColour}"

    }

    

    # Kerberos (88)

    timeout 2 bash -c "echo '' > /dev/tcp/$ip/88" 2>/dev/null && {

        servicios_activos+=("KERBEROS")

        echo -e "${greenColour}[+] Kerberos detectado (88)${endColour}"

    }

    

    # HTTP (80, 443, 8080, 8443)

    for puerto in 80 443 8080 8443; do

        timeout 2 bash -c "echo '' > /dev/tcp/$ip/$puerto" 2>/dev/null && {

            if [[ ! " ${servicios_activos[@]} " =~ " WEB " ]]; then

                servicios_activos+=("WEB")

                echo -e "${greenColour}[+] HTTP/HTTPS detectado${endColour}"

            fi

            break

        }

    done

    

    # RDP (3389)

    timeout 2 bash -c "echo '' > /dev/tcp/$ip/3389" 2>/dev/null && {

        servicios_activos+=("RDP")

        echo -e "${greenColour}[+] RDP detectado (3389)${endColour}"

    }

    

    if [ ${#servicios_activos[@]} -eq 0 ]; then

        echo -e "\n${redColour}[!] No se detectaron servicios enumerables${endColour}"

        return

    fi

    

    echo -e "\n${turquoiseColour}[*] Servicios a enumerar: ${servicios_activos[@]}${endColour}\n"

    sleep 2

    

    # Ejecutar enumeraciones según servicios detectados

    for servicio in "${servicios_activos[@]}"; do

        case $servicio in

            SMB)

                enum_smb $ip

                ;;

            LDAP)

                enum_ldap $ip

                ;;

            KERBEROS)

                enum_kerberos $ip

                ;;

            WEB)

                enum_web $ip

                ;;

            RDP)

                enum_rdp $ip

                ;;

        esac

        echo -e "\n${grayColour}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${endColour}\n"

    done

    

    echo -e "\n${greenColour}╔════════════════════════════════════════════╗${endColour}"

    echo -e "${greenColour}║  ✓ ENUMERACIÓN COMPLETA FINALIZADA        ║${endColour}"

    echo -e "${greenColour}╚════════════════════════════════════════════╝${endColour}"

    echo -e "${turquoiseColour}[*] Todos los resultados en: enum_results_$ip/${endColour}\n"

}


# Menú principal

echo -e "${yellowColour}[?] Selecciona una opción:${endColour}\n"

echo -e "${grayColour}1) Descubrimiento de hosts SIN PING (recomendado)${endColour}"

echo -e "${grayColour}2) Identificar Domain Controllers SIN PING${endColour}"

echo -e "${grayColour}3) Escanear puertos DC de una IP específica${endColour}"

echo -e "${grayColour}4) Escaneo COMPLETO (descubrir + identificar DCs)${endColour}"

echo -e "${grayColour}5) Escanear TOP 100 puertos de una IP${endColour}"

echo -e "${grayColour}6) Escanear TODOS los puertos (1-65535) de una IP${endColour}"

echo -e "${grayColour}7) Detectar VERSIONES de servicios de una IP${endColour}"

echo -e "${grayColour}8) Escaneo INTENSIVO (puertos + versiones + banners)${endColour}"

echo -e "${purpleColour}--- SCRIPTS DE ENUMERACIÓN ---${endColour}"

echo -e "${grayColour}9) Enumeración SMB completa${endColour}"

echo -e "${grayColour}10) Enumeración LDAP/Active Directory${endColour}"

echo -e "${grayColour}11) Enumeración Kerberos (ASREPRoast/Kerberoasting)${endColour}"

echo -e "${grayColour}12) Enumeración HTTP/Web${endColour}"

echo -e "${grayColour}13) Enumeración RDP${endColour}"

echo -e "${greenColour}14) ENUMERACIÓN AUTOMÁTICA (detecta y ejecuta todo)${endColour}"

read -p "$(echo -e ${turquoiseColour}"> "${endColour})" opcion


case $opcion in

    1)

        descubrir_hosts_sin_ping

        ;;

    2)

        identificar_dc_sin_ping

        ;;

    3)

        read -p "$(echo -e ${yellowColour}"[?] IP del DC: "${endColour})" target_ip

        escanear_dc $target_ip

        ;;

    4)

        echo -e "${blueColour}[*] Iniciando escaneo completo...${endColour}\n"

        identificar_dc_sin_ping

        ;;

    5)

        read -p "$(echo -e ${yellowColour}"[?] IP del objetivo: "${endColour})" target_ip

        escanear_top_ports $target_ip

        ;;

    6)

        read -p "$(echo -e ${yellowColour}"[?] IP del objetivo: "${endColour})" target_ip

        escanear_todos_puertos $target_ip

        ;;

    7)

        read -p "$(echo -e ${yellowColour}"[?] IP del objetivo: "${endColour})" target_ip

        detectar_versiones $target_ip

        ;;

    8)

        read -p "$(echo -e ${yellowColour}"[?] IP del objetivo: "${endColour})" target_ip

        escaneo_intensivo_versiones $target_ip

        ;;

    9)

        read -p "$(echo -e ${yellowColour}"[?] IP del objetivo: "${endColour})" target_ip

        enum_smb $target_ip

        ;;

    10)

        read -p "$(echo -e ${yellowColour}"[?] IP del objetivo: "${endColour})" target_ip

        enum_ldap $target_ip

        ;;

    11)

        read -p "$(echo -e ${yellowColour}"[?] IP del objetivo: "${endColour})" target_ip

        enum_kerberos $target_ip

        ;;

    12)

        read -p "$(echo -e ${yellowColour}"[?] IP del objetivo: "${endColour})" target_ip

        enum_web $target_ip

        ;;

    13)

        read -p "$(echo -e ${yellowColour}"[?] IP del objetivo: "${endColour})" target_ip

        enum_rdp $target_ip

        ;;

    14)

        read -p "$(echo -e ${yellowColour}"[?] IP del objetivo: "${endColour})" target_ip

        enum_automatico $target_ip

        ;;

    *)

        echo -e "${redColour}[!] Opción inválida${endColour}"

        tput cnorm

        exit 1

        ;;

esac


tput cnorm

echo -e "\n${greenColour}[✓] Escaneo completado${endColour}\n"

