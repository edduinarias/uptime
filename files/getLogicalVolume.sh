#!/bin/bash
getLogicalVolumeLinux() {
    echo "=========================================="
    echo "        Informacion de Volumenes LVM      "
    echo "=========================================="
    
    # Mostrar Physical Volumes
    echo -e "Physical Volumes (PV):"
    pvs --units g --separator ' | ' --noheadings -o pv_name,vg_name,pv_size,pv_free | column -t
    
    # Mostrar Volume Groups
    echo -e "Volume Groups (VG):"
    vgs --units g --separator ' | ' --noheadings -o vg_name,vg_size,vg_free,vg_attr | column -t
    
    # Mostrar Logical Volumes
    echo -e "Logical Volumes (LV):"
    lvs --units g --separator ' | ' --noheadings -o lv_name,vg_name,lv_size,lv_attr,lv_path | column -t
    
    echo -e "Finalizado.\n"

}

getLogicalVolumeSolaris(){

    echo "=========================================="
    echo "     Informacion de Volumenes en Solaris  "
    echo "=========================================="
    
    # Verificar si zfs está disponible
    if command -v zpool >/dev/null 2>&1 && command -v zfs >/dev/null 2>&1; then
      echo -e "Detected: ZFS"
    
      echo -e "ZFS Pools:"
      zpool list
    
      echo -e "Estado de Pools:"
      zpool status
    
    else
      echo -e "ZFS no detectado o no disponible."
    fi
    
    # Verificar si SVM está disponible
    if command -v metastat >/dev/null 2>&1; then
      echo -e "Detected: Solaris Volume Manager (SVM)"
    
      echo -e "Metastat:"
      metastat
    
      echo -e "Metadb:"
      metadb
    
      echo -e "Filesystems montados:"
      df -h | grep -E '^/dev/md'
    else
      echo -e "SVM no detectado o no disponible."
    fi
    
    echo -e "Finalizado."
    
}

getLogicalVolumeAIX(){
    
    echo "==============================================="
    echo "        Informacion de Volomenes en AIX        "
    echo "==============================================="
    
    # Physical Volumes
    echo "Physical Volumes (PVs):"
    lspv | awk '{printf "%-20s %-20s %-20s\n", $1, $2, $3}'
    
    # Volume Groups
    echo "Volume Groups (VGs):"
    for vg in $(lsvg); do
      echo "VG: $vg"
      lsvg $vg
    done
    
    # Logical Volumes
    echo "Logical Volumes (LVs):"
    for vg in $(lsvg); do
      echo "LVs en $vg:"
      lsvg -l $vg
    done
    
    echo "Finalizado."

}

if [ $# -ne 1 ]; then
    echo "Uso: $0 [linux|solaris|aix]"
    exit 1
fi

case "$1" in
    linux)
        getLogicalVolumeLinux
        ;;
    solaris)
        getLogicalVolumeSolaris
        ;;
    aix)
        getLogicalVolumeAIX
        ;;
    *)
        echo "SO no soportado. Use 'linux' | 'solaris' | 'aix' "
        exit 1
        ;;
esac