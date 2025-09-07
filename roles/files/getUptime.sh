#!/bin/bash

os_family=$(uname)

case "$os_family" in
  Linux)
    # uptime output example: " 16:41:23 up 1 day,  2:34,  3 users,  load average: 0.00, 0.01, 0.05"
    # vamos a extraer el uptime usando uptime -p o procesando uptime tradicional
    
    if command -v uptime &> /dev/null; then
      # uptime -p muestra uptime en formato "up 1 day, 2 hours, 3 minutes"
      up=$(uptime -p 2>/dev/null)
      if [[ $? -eq 0 && -n "$up" ]]; then
        echo "$up" | sed 's/^up //'
        exit 0
      fi
    fi
    
    # fallback si no soporta uptime -p
    # usamos uptime | awk para extraer tiempo (ej: " 1 day, 2:34")
    up=$(uptime | sed 's/.*up //' | awk -F',' '{print $1","$2}')
    echo "$up"
    ;;

  SunOS)
    # Solaris uptime ejemplo: "  16:41  up 5 days, 23:03,  2 users,  load average: 0.00, 0.01, 0.05"
    # Extraemos uptime similar a Linux

    up=$(uptime | sed 's/.*up //' | awk -F',' '{print $1","$2}')
    echo "$up"
    ;;

  AIX)
    # AIX no tiene uptime -p
    # Se puede usar "uptime" o "who -b"
    # uptime ejemplo: " 16:41:23 up 1 day, 2:34, 3 users, load average: 0.00, 0.01, 0.05"
    up=$(uptime | sed 's/.*up //' | awk -F',' '{print $1","$2}')
    echo "$up"
    ;;

  *)
    echo "Sistema operativo no soportado"
    exit 1
    ;;
esac
