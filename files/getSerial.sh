#!/bin/bash

# Silenciar errores
exec 2>/dev/null

get_linux_serial() {
    # 1. Intentar desde dmidecode (requiere root)
    if [ "$(id -u)" -eq 0 ] && command -v dmidecode >/dev/null; then
        serial=$(dmidecode -s system-serial-number)
        [ -n "$serial" ] && [ "$serial" != "Not Specified" ] && echo "$serial" && return
    fi

    # 2. Intentar desde /sys/class/dmi/id
    if [ -f /sys/class/dmi/id/product_serial ]; then
        serial=$(tr -d '\0' < /sys/class/dmi/id/product_serial)
        [ -n "$serial" ] && [ "$serial" != "Not Specified" ] && echo "$serial" && return
    fi

    # 3. Para servidores IBM POWER
    if [ -f /proc/device-tree/system-id ]; then
        serial=$(hexdump -C /proc/device-tree/system-id | head -1)
        [ -n "$serial" ] && echo "$serial" && return
    fi

    # 4. Para máquinas virtuales (VMware)
    if [ -f /sys/class/dmi/id/product_uuid ]; then
        serial=$(cat /sys/class/dmi/id/product_uuid)
        [ -n "$serial" ] && echo "$serial" && return
    fi
}

get_solaris_serial() {
    # 1. Usar smbios (Solaris 10+)
    if command -v smbios >/dev/null; then
        serial=$(smbios -t SMB_TYPE_SYSTEM | awk '/Serial Number:/ {print $3}')
        [ -n "$serial" ] && echo "$serial" && return
    fi

    # 2. Usar prtconf (método antiguo)
    serial=$(prtconf -vp | awk '/serial#/ {print $2}' | tr -d "'")
    [ -n "$serial" ] && echo "$serial" && return

    # 3. Para LDOMs
    if command -v virtinfo >/dev/null; then
        serial=$(virtinfo -a | awk '/serial/ {print $3}')
        [ -n "$serial" ] && echo "$serial" && return
    fi
}

get_aix_serial() {
    # 1. Usar lscfg para obtener el número de serie del sistema
    if command -v lscfg >/dev/null; then
        serial=$(lscfg -vp | awk '/Machine Serial Number/{print $4}')
        [ -n "$serial" ] && echo "$serial" && return
    fi

    # 2. Usar prtconf como alternativa
    if command -v prtconf >/dev/null; then
        serial=$(prtconf | awk '/Machine Serial Number/{print $4}')
        [ -n "$serial" ] && echo "$serial" && return
    fi

    # 3. Para sistemas virtualizados (LPAR)
    if command -v lparstat >/dev/null; then
        serial=$(lparstat -i | awk '/Partition Number/{print $3}')
        [ -n "$serial" ] && echo "$serial" && return
    fi
}

# Determinar SO y obtener serial
case "$1" in
    solaris) get_solaris_serial ;;
    linux)   get_linux_serial ;;
    aix)     get_aix_serial ;;
esac