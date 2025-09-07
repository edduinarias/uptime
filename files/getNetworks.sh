#!/bin/bash

getNetowrksLinux(){
    echo "============================================"
    echo "    Interfaces de Red en Linux             "
    echo "============================================"
    
    # Mostrar interfaces con su IP y MAC
    echo -e "\n Interfaces de red:"
    for iface in $(ls /sys/class/net); do
        echo "Interfaz: $iface"
        
        # Dirección MAC
        MAC=$(cat /sys/class/net/$iface/address)
        echo "    MAC: $MAC"
    
        # Dirección IP
        IP=$(ip -o -4 addr show $iface | awk '{print $4}')
        [[ -z "$IP" ]] && IP="No tiene IP asignada"
        echo "    IP: $IP"
    
        # Tipo de interfaz
        TYPE=$(cat /sys/class/net/$iface/type 2>/dev/null)
        [[ "$TYPE" == "1" ]] && echo "    Tipo: Ethernet" || echo "    Tipo: Otro"
    
        echo ""
    done
    
    # Verificar y mostrar Bonds
    echo -e "Bonds detectados:"
    if [ -d /proc/net/bonding ]; then
        for bond in /proc/net/bonding/*; do
            echo -e "Bond: $(basename $bond)"
            cat $bond
        done
    else
        echo "    No hay bonds configurados."
    fi
    
    echo -e "\nFinalizado."
}

getNetowrksSolaris(){
     
     echo "============================================"
     echo "     Interfaces de Red en Solaris           "
     echo "============================================"
     
     # Mostrar interfaces e IPs
     echo -e "Interfaces con IP:"
     ipadm show-addr
     
     # Mostrar interfaces y MAC
     echo -e "MAC Address:"
     dladm show-phys -m
     
     # Mostrar agregaciones si existen
     echo -e "Interfaces agregadas (bonding):"
     if dladm show-aggr 2>/dev/null; then
         dladm show-aggr -L
     else
         echo "    No se detectaron agregaciones."
     fi
     
     echo -e "Finalizado."

}

getNetowrksAIX() {
    echo "============================================"
    echo "     Interfaces de Red en AIX               "
    echo "============================================"

    for ent in $(lsdev -Cc adapter | awk '/ent[0-9]+/ {print $1}'); do
        echo -e "Interfaz física: $ent"

        # Extraer MAC completa
        mac=$(entstat $ent 2>/dev/null | grep -i "Hardware Address" | sed 's/^.*Hardware Address:[[:space:]]*//')
        echo "    MAC: ${mac:-No disponible}"

        ent_num=$(echo "$ent" | sed 's/ent//')
        for en in $(lsdev -Cc if | awk '{print $1}' | grep "^en$ent_num"); do
            ip=$(ifconfig $en 2>/dev/null | grep "inet " | awk '{print $2}')
            echo "    Lógica: $en -> IP: ${ip:-No asignada}"
        done
    done

    echo -e "EtherChannel / Agregaciones:"
    lsdev -Cc adapter | grep -i etherchannel | while read line; do
        dev=$(echo $line | awk '{print $1}')
        echo -e "Agregado: $dev"
        lsattr -El $dev
    done

    echo -e "Finalizado."
}
#getNetowrksAIX(){
#
#     echo "============================================"
#     echo "   🌐 Interfaces de Red en AIX               "
#     echo "============================================"
#     
#     # Listar interfaces físicas con MAC y IP
#     for iface in $(lsdev -Cc adapter | grep -E "ent[0-9]+" | awk '{print $1}'); do
#         echo "\n🔸 Interfaz: $iface"
#     
#         # Mostrar dirección MAC
#         entstat $iface | grep -i "Hardware Address" | awk -F: '{print "    MAC:" $2}'
#     
#         # Mostrar dirección IP si tiene (si hay una en en*)
#         en_iface=$(lsdev -Cc if | grep "^en.*$iface" | awk '{print $1}')
#         if [ -n "$en_iface" ]; then
#             IP=$(ifconfig $en_iface 2>/dev/null | grep "inet " | awk '{print $2}')
#             echo "    IP: ${IP:-No asignada}"
#         else
#             echo "    IP: No asignada"
#         fi
#     done
#     
#     # Mostrar EtherChannel
#     echo "\n🔗 EtherChannel / Agregaciones:"
#     lsdev -Cc adapter | grep -i etherchannel | while read line; do
#         dev=$(echo $line | awk '{print $1}')
#         echo "\n🔸 Agregado: $dev"
#         lsattr -El $dev
#     done
#     
#     echo "\n✅ Finalizado."
#
#}


if [ $# -ne 1 ]; then
    echo "Uso: $0 [linux|solaris|aix]"
    exit 1
fi

case "$1" in
    linux)
        getNetowrksLinux
        ;;
    solaris)
        getNetowrksSolaris
        ;;
    aix)
        getNetowrksAIX
        ;;
    *)
        echo "SO no soportado. Use 'linux' | 'solaris' | 'aix' "
        exit 1
        ;;
esac
