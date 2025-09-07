#!/bin/bash

# Función para Linux
get_asmdisk_linux() {
    
    local asm_disks=$(oracleasm listdisks 2>/dev/null)
    local found_disks=0
    
    if [ -n "$asm_disks" ]; then
        found_disks=1
        echo "=== Discos detectados via ASMLib ==="
        for asm_disk in $asm_disks; do
            (
                local devices=$(oracleasm querydisk -p "$asm_disk" 2>/dev/null | grep -o '/dev/[^ ]*')
                local mapper_dev=$(echo "$devices" | grep -m1 '/dev/mapper/')
                local phys_dev=$(echo "$devices" | grep -v -m1 '/dev/mapper/')
                
                printf "%-30s -> %-40s -> %-15s\n" "$asm_disk" "${mapper_dev:-N/A}" "${phys_dev:-N/A}"
            ) &
        done | sort
        wait
    fi

    if [ $found_disks -eq 0 ] || [ "$1" == "--all" ]; then
        echo -e "\n=== Buscando discos ASM en reglas UDEV ==="
        
        # Buscar en todas las reglas UDEV
        find /etc/udev/rules.d -type f -name '*.rules' -exec grep -l 'oracleasm' {} + 2>/dev/null | \
        while read -r rule_file; do
            awk '
            BEGIN {FS="=="; OFS=" -> "}
            /KERNEL=="sd[a-z]*[0-9]*"/ && /NAME==.*oracleasm/ {
                gsub(/"/, "", $2);
                split($2, parts, "==");
                asm_name = parts[2];
                dev_name = parts[1];
                
                # Obtener dispositivo físico real
                system("lsblk -no NAME,MAJ:MIN " dev_name " 2>/dev/null | while read -r name majmin; do \
                    printf \"%-30s -> %-40s -> /dev/%s\\n\", asm_name, \"/dev/mapper/$(lsblk -no PKNAME /dev/\" name \")\", name; \
                done")
            }' "$rule_file"
        done | sort | uniq
    fi
}

get_asmdisk_solaris(){
    RUTA="/dev/rdsk"

    # Trato de ubicar la ruta
    if [ ! -d "$RUTA" ]; then
        echo "La ruta $RUTA no existe."
        exit 1
    fi

    # Listar los archivos en orden inverso por tiempo de modificación,
    # con detalles largos, sin seguir enlaces simbólicos, y filtrar los que no son de root
    echo "Dispositivos potencialmente usados por ASM:"
    SALIDA=$(ls -ltralL "$RUTA" | grep -v '^.* root ')
    
    if [ -z "$SALIDA" ]; then
        echo "No se encontraron dispositivos ASM en $RUTA."
        exit 0
    else
        echo "$SALIDA"
    fi

}

get_asmdisk_aix() {
    RUTA="/dev"

    if [ ! -d "$RUTA" ]; then
        echo "La ruta $RUTA no existe."
        exit 1
    fi

    echo "Dispositivos potencialmente usados por ASM en AIX:"
    
    SALIDA=$(ls -l "$RUTA"/rhdisk* 2>/dev/null  )

    if [ -z "$SALIDA" ]; then
        echo "No se encontraron dispositivos ASM en $RUTA."
        exit 0
    else
        echo "$SALIDA"
    fi
}

if [ $# -ne 1 ]; then
    echo "Uso: $0 [linux|solaris|aix]"
    exit 1
fi

case "$1" in
    linux)
        get_asmdisk_linux
        ;;
    solaris)
        get_asmdisk_solaris
        ;;
    aix)
        get_asmdisk_aix
        ;;
    *)
        echo "SO no soportado. Use 'linux' | 'solaris' | 'aix' "
        exit 1
        ;;
esac