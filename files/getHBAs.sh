#!/bin/bash

# Función para Linux
ProcesarLinux() { 
   if  [ -s "/sbin/lspci" ]; then
       CantidadPuertosHBA=$(/sbin/lspci -nn | grep -ci "Fibre Channel")
   else
        echo "Comando LSPCI no disponible."; echo
        if [ -d  "/sys/class/fc_host" ]; then
               CantidadPuertosHBA=$(ls /sys/class/fc_host/ | wc -l)
        else 
               CantidadPuertosHBA=0
        fi
   fi
   echo "Cantidad de puertos HBA: $CantidadPuertosHBA"; echo
   if [ "$CantidadPuertosHBA" -gt 0 ]; then
         for HostFIbra in /sys/class/fc_host/* ; do 
             echo "Ruta   : $HostFIbra"
             echo "WWN    : $(cat "$HostFIbra"/port_name)"
             echo "Estado : $(cat "$HostFIbra"/port_state)"; echo
         done
   fi
}


ProcesarSolaris() {
   if [ -s "/usr/sbin/luxadm" ] && [ -s "/usr/sbin/fcinfo" ]; then
       CantidadPuertosHBA=$(/usr/sbin/luxadm -e port | wc -l | sed 's/^[ \t]*//')
       echo "ImprimePuertosHBA $CantidadPuertosHBA"; echo
   if [ "$CantidadPuertosHBA" -gt 0 ]; then
       readlink > /dev/null 2>&1 # Readlink no esta presente en varios Solaris
       ReadLinkExiste=$? # Usalo como bandera
   for PuertoWWN in $(/usr/sbin/fcinfo hba-port | grep HBA | cut -d: -f2); do
       EstadoWWN=$(/usr/sbin/fcinfo hba-port "$PuertoWWN" | grep State | cut -d: -f2)
       RutaDisco=$(/usr/sbin/fcinfo hba-port "$PuertoWWN" | grep "/dev/*" | cut -d: -f2)
       RutaDisco="${RutaDisco#?}"
   [ "$ReadLinkExiste" -eq 0 ] && RutaHBA=$(readlink -f "$RutaDisco") || RutaHBA=$(ls -l "$RutaDisco" | awk -F"../" '{print $5}')
       echo "Ruta : $RutaHBA"
       echo "WWN : $PuertoWWN"
       echo "Estado : $EstadoWWN"; echo
   done
   fi
   else
       echo "Comandos LUXADM y/o FCINFO no estan disponibles."
       exit 1
   fi
}

ProcesarAIX() {
    # Obtener número total de puertos fcs*
    TotalPuertosHBA=$(lsdev -C -c adapter | grep -c '^fcs[0-9]')

    i=0
    while [ $i -lt "$TotalPuertosHBA" ]; do
        dev="fcs$i"
        fscsi="fscsi$i"

        # Verifica que ambos dispositivos existan
        if ! lsdev -C | grep -q "^$dev"; then
            i=$((i+1))
            continue
        fi

        Dispositivo="$dev --> /dev/$fscsi"

        # Obtener WWN del adaptador
        PuertoWWN=$(lscfg -vl "$dev" 2>/dev/null | awk -F. '/Network Address/ {gsub(" ", "", $NF); print $NF}')
        [ -z "$PuertoWWN" ] && PuertoWWN="Desconocido"

        # Estado de conexión
        TipoEstado=$(lsattr -El "$fscsi" 2>/dev/null | awk '/attach/ {print $2}')
        case "$TipoEstado" in
            none) EstadoWWN="Offline" ;;
            switch) EstadoWWN="Online (modo switch)" ;;
            al) EstadoWWN="Online (modo loop/ring)" ;;
            *) EstadoWWN="Desconocido" ;;
        esac

        # Determinar si es físico o virtual
        if lsdev -C | grep -i "^$dev" | grep -q "express"; then
            TipoPuerto="Físico"
        else
            TipoPuerto="Virtual"
        fi

        echo "Tipo   : $TipoPuerto"
        echo "Ruta   : $Dispositivo"
        echo "WWN    : $PuertoWWN"
        echo "Estado : $EstadoWWN"
        echo

        i=$((i+1))
    done
}

MostrarAyuda() {
    echo "Uso: $0 [sistema]"
    echo
    echo "Opciones para [sistema]:"
    echo "  linux    Ejecutar para sistemas Linux"
    echo "  solaris  Ejecutar para sistemas Solaris"
    echo "  aix      Ejecutar para sistemas aix"
    echo "  auto     Detectar automáticamente el sistema (por defecto)"
    echo
    echo "Ejemplos:"
    echo "  $0 linux    # Ejecuta solo para Linux"
    echo "  $0 solaris  # Ejecuta solo para Solaris"
    echo "  $0 aix      # Ejecuta solo para AIX"
    
}

# Procesar argumentos
case "$1" in
    linux)
        echo "Ejecutando para Linux..."
        ProcesarLinux
        ;;
    solaris)
        echo "Ejecutando para Solaris..."
        ProcesarSolaris
        ;;
    aix)
        echo "Ejecutando para AIX..."
        ProcesarAIX
        ;;
    -h|--help|help)
        MostrarAyuda
        ;;
    *)
        echo "Opción no válida: $1"
        MostrarAyuda
        exit 1
        ;;
esac

exit 0