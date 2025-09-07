#!/bin/bash

# Redirigir todos los errores a /dev/null
exec 2>/dev/null

check_linux() {
    # 1. Verificar systemd-detect-virt
    if command -v systemd-detect-virt >/dev/null; then
        [ "$(systemd-detect-virt)" != "none" ] && { printf "Virtual"; exit; }
    fi

    # 2. Verificar /sys/class/dmi/id
    if [ -f /sys/class/dmi/id/product_name ]; then
        grep -qiE "vmware|virtual|kvm|qemu|xen|amazon|ec2|microsoft|hyper-v|google|gcp" /sys/class/dmi/id/product_name && { printf "Virtual"; exit; }
    fi

    # 3. Verificar dmidecode (solo root)
    if [ "$(id -u)" -eq 0 ] && command -v dmidecode >/dev/null; then
        dmidecode -s system-product-name | grep -qiE "vmware|virtual|kvm|qemu|xen" && { printf "Virtual"; exit; }
    fi

    # 4. Verificar /proc/cpuinfo (si existe)
    [ -f /proc/cpuinfo ] && grep -qi "hypervisor" /proc/cpuinfo && { printf "Virtual"; exit; }

    # 5. Verificar lspci (si existe)
    command -v lspci >/dev/null && lspci | grep -qi "virtualbox|vmware|xen|qemu" && { printf "Virtual"; exit; }

    printf  "Fisico"
}

check_solaris() {
    if command -v virtinfo >/dev/null; then
        DOMAIN_NAME=$(virtinfo -a | awk -F': ' '/Domain name:/ {print $2}' | xargs)
        DOMAIN_ROLE=$(virtinfo -a | awk -F': ' '/Domain role:/ {print $2}' | xargs)

        if [[ "$DOMAIN_NAME" == "primary" && "$DOMAIN_ROLE" == *control* ]]; then
            printf  "Fisico"
            exit
        else
            printf  "Virtual"
            exit
        fi
    fi

    if command -v smbios >/dev/null; then
        if smbios -t SMB_TYPE_SYSTEM | grep -qi "virtual"; then
            printf  "Virtual"
            exit
        fi
    fi

    printf  "No se pudo determinar con certeza. Posiblemente físico."
}


check_aix() {
    # 1. Verificar lparstat (si existe)
    command -v lparstat >/dev/null && lparstat -i | grep -q "Partition\ Mode.*shared" && { printf "Virtual"; exit; }

    # 2. Verificar prtconf (si existe)
    command -v prtconf >/dev/null && prtconf | grep -qi "LPAR" && { printf "Virtual"; exit; }

    # 3. Verificar el modelo de CPU (PowerVM)
    command -v uname >/dev/null && uname -W 2>/dev/null | grep -q -v '^0$' && { printf "Virtual"; exit; }
}

# Detección automática del SO
case "$1" in
    solaris) check_solaris ;;
    aix) check_aix ;;
    *) check_linux ;;
esac


