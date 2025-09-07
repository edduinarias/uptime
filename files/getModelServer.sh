#!/bin/bash

# Redirigir todos los errores a /dev/null
exec 2>/dev/null

# Función para Linux
get_linux_model() {
    # 1. Intentar desde /sys/class/dmi/id
    if [ -f /sys/class/dmi/id/product_name ]; then
        model=$(tr -d '\0' < /sys/class/dmi/id/product_name)
        [ -n "$model" ] && [ "$model" != "Not Specified" ] && echo "$model" && return
    fi

    # 2. Intentar desde dmidecode (requiere root)
    if [ "$(id -u)" -eq 0 ] && command -v dmidecode >/dev/null; then
        model=$(dmidecode -s system-product-name)
        [ -n "$model" ] && [ "$model" != "Not Specified" ] && echo "$model" && return
    fi

    # 3. Para servidores IBM POWER
    if [ -f /proc/device-tree/model ]; then
        model=$(tr -d '\0' < /proc/device-tree/model)
        [ -n "$model" ] && echo "$model" && return
    fi

    # 4. Para máquinas virtuales (usar product_name como fallback)
    if [ -f /sys/class/dmi/id/product_name ]; then
        model=$(tr -d '\0' < /sys/class/dmi/id/product_name)
        echo "${model:-Unknown}"
        return
    fi
}

# Función para Solaris
get_solaris_model() {
    # 1. Usar smbios (Solaris 10+)
    if command -v smbios >/dev/null; then
        model=$(smbios -t SMB_TYPE_SYSTEM | awk -F: '/Product/ {print $2}' | sed 's/^[ \t]*//')
        [ -n "$model" ] && echo "$model" && return
    fi

    # 2. Usar prtconf (método antiguo)
    model=$(prtconf -vp | awk -F= '/model/ {print $2}' | tr -d "'" | head -1)
    [ -n "$model" ] && echo "$model" && return

    # 3. Para LDOMs
    if command -v virtinfo >/dev/null; then
        model=$(virtinfo -a | awk '/Domain role/ {print "Oracle LDOM " $3}')
        [ -n "$model" ] && echo "$model" && return
    fi
}

get_aix_model() {
    # 1. Obtener modelo del hardware físico
    if command -v lscfg >/dev/null; then
        model=$(lscfg -vp | awk -F: '/System Model/ {print $2}' | sed 's/^ *//')
        [ -n "$model" ] && echo "$model" && return
    fi

    # 2. Verificar si es una LPAR (partición lógica)
    if command -v lparstat >/dev/null; then
        lparstat_output=$(lparstat -i 2>/dev/null)
        if [ $? -eq 0 ]; then
            # Es una LPAR (virtual)
            lpar_name=$(echo "$lparstat_output" | awk -F: '/Partition Name/ {print $2}' | sed 's/^ *//')
            lpar_id=$(echo "$lparstat_output" | awk -F: '/Partition Number/ {print $2}' | sed 's/^ *//')
            echo "IBM PowerVM LPAR ($model) - Name: $lpar_name, ID: $lpar_id"
            return
        else
            # Es un sistema físico
            echo "$model (Physical)"
            return
        fi
    fi

    # 3. Método alternativo con prtconf
    if command -v prtconf >/dev/null; then
        model=$(prtconf | awk '/System Model/ {print $3,$4,$5}')
        [ -n "$model" ] && echo "$model" && return
    fi
}
# Validar argumento
if [ $# -ne 1 ]; then
    echo "Uso: $0 [linux|solaris|aix]"
    exit 1
fi

# Obtener modelo según SO especificado
case "$1" in
    linux)
        get_linux_model
        ;;
    solaris)
        get_solaris_model
        ;;
    aix)
        get_aix_model
        ;;
    *)
        echo "Error: SO no soportado. Use 'linux' o 'solaris'"
        exit 1
        ;;
esac

# Si no se encontró modelo
[ -z "$model" ] && echo "Unknown"