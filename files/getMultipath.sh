#!/bin/bash

# Script unificado para listar dispositivos multipath en todas las distribuciones
# Compatible con: RedHat, Debian, SUSE, AlmaLinux, Rocky Linux, etc.

get_multipath_linux() {
    # Verificar si multipath está instalado
    if ! command -v multipath &> /dev/null; then
        echo "Multipath no está instalado en este sistema."
        return 1
    fi

    # Crear directorio temporal único
    local tmp_dir=$(mktemp -d)
    trap 'rm -rf "$tmp_dir"' EXIT

    # Capturar datos necesarios
    multipath -ll -v2 > "$tmp_dir/multipath_full.txt" 2>/dev/null
    blkid > "$tmp_dir/blkid.txt" 2>/dev/null
    lsblk -o NAME,SIZE,MODEL > "$tmp_dir/disks.txt" 2>/dev/null

    # Extraer identificadores de dispositivos
    grep -oP '(?<=\().*(?=\))' "$tmp_dir/multipath_full.txt" | awk -F")" '{print $1}' > "$tmp_dir/identifiers.txt"

    # Mostrar encabezado
    printf "%-35s | %-20s | %-4s | %-8s | %-12s | %-15s | %-10s\n" \
           "ID" "Device" "Paths" "DM" "Policy" "Storage" "Size"
    printf "%-35s-+-%-20s-+-%-4s-+-%-8s-+-%-12s-+-%-15s-+-%-10s\n" \
           "-----------------------------------" "--------------------" "----" "--------" "------------" "---------------" "----------"

    # Procesar cada dispositivo
    while read -r id; do
        local device_info=$(grep -A1 "$id" "$tmp_dir/multipath_full.txt")
        
        local paths=$(grep -c "sd[a-z]" <<< "$device_info")
        local dm=$(grep -oP "dm-\d+" <<< "$device_info" | head -1)
        local storage=$(grep -oP "(?<=dm-\d{1,2} ).*(?= size)" <<< "$device_info")
        local policy=$(grep -oP "policy='?\K\w+" <<< "$device_info")
        local size=$(grep -oP "size=\K[\d\.]+[GT]" <<< "$device_info")
        
        # Obtener nombre del dispositivo compatible con todas las distros
        local dev_name="/dev/mapper/$(grep -oP "^[a-z]+\d*" <<< "$device_info")"
        [[ -e "$dev_name" ]] || dev_name="/dev/$dm"

        printf "%-35s | %-20s | %-4s | %-8s | %-12s | %-15s | %-10s\n" \
               "$id" "$dev_name" "$paths" "$dm" "$policy" "$storage" "$size"
    done < "$tmp_dir/identifiers.txt"
}

get_multipath_solaris() {
    # Verificar si MPxIO está habilitado
    mpxio_status=$(svcprop -p config/enabled svc:/system/device/mpxio-upgrade:default 2>/dev/null)
    
    if [ "$mpxio_status" != "true" ]; then
        echo "MPxIO (Multipath nativo de Solaris) no está habilitado."
        return 1
    fi

    # Mostrar encabezado
    printf "%-35s | %-20s | %-4s | %-15s | %-10s\n" \
           "WWN" "Device" "Paths" "Storage" "Size"
    printf "%-35s-+-%-20s-+-%-4s-+-%-15s-+-%-10s\n" \
           "-----------------------------------" "--------------------" "----" "---------------" "----------"

    # Obtener lista de dispositivos
    luxadm probe 2>/dev/null | while read -r line; do
        if [[ "$line" =~ /dev/rdsk/ ]]; then
            device=$(echo "$line" | awk '{print $1}')
            wwn=$(echo "$line" | awk '{print $NF}')
            
            # Contar paths para este dispositivo
            path_count=$(luxadm display "$device" 2>/dev/null | grep -c "Path enabled")
            
            # Obtener información del dispositivo
            dev_info=$(luxadm display "$device" 2>/dev/null)
            vendor=$(echo "$dev_info" | grep -i "Vendor" | cut -d: -f2 | xargs)
            product=$(echo "$dev_info" | grep -i "Product" | cut -d: -f2 | xargs)
            size=$(echo "$dev_info" | grep -i "Capacity" | cut -d: -f2 | xargs)
            
            printf "%-35s | %-20s | %-4s | %-15s | %-10s\n" \
                   "$wwn" "$device" "$path_count" "$vendor $product" "$size"
        fi
    done
}


if [ $# -ne 1 ]; then
    echo "Uso: $0 [linux|solaris|aix]"
    exit 1
fi

case "$1" in
    linux)
        get_multipath_linux
        ;;
    solaris)
        get_multipath_solaris
        ;;
    aix)
        get_multipath_aix
        ;;
    *)
        echo "SO no soportado. Use 'linux' | 'solaris' | 'aix' "
        exit 1
        ;;
esac



exit 0