#!/bin/bash

# Script para obtener la tabla de rutas de red de forma compatible

echo "Detectando herramienta disponible para mostrar rutas..."

if command -v ip >/dev/null 2>&1; then
    echo "Usando 'ip route show'"
    ip route show
elif command -v netstat >/dev/null 2>&1; then
    echo "[INFO] Usando 'netstat -rn'"
    netstat -rn
else
    echo "No se encontraron los comandos 'ip' ni 'netstat'."
    echo "Por favor instala 'iproute2' o 'net-tools'."
    exit 1
fi