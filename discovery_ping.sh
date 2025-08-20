#!/bin/bash

# Discovery Ping Script
# Autor: Angel J. Reynoso
# Descripción:
#   Lee un archivo de texto con una lista de IPs (una por línea),
#   realiza ping broadcast (-b) a cada una,
#   marca si responde o no, y al final genera un informe.

if [ $# -ne 1 ]; then
    echo "Uso: $0 network.txt"
    exit 1
fi

archivo="$1"

if [ ! -f "$archivo" ]; then
    echo "❌ El archivo $archivo no existe."
    exit 1
fi

alcanzadas=()
no_alcanzadas=()

while IFS= read -r ip; do
    [[ -z "$ip" || "$ip" =~ ^# ]] && continue

    echo "🔍 Probando $ip ..."
    ok=0
    for i in {1..5}; do
        if ping -b -c 1 -W 1 "$ip" >/dev/null 2>&1; then
            echo "✅ Host vivo encontrado en $ip"
            alcanzadas+=("$ip")
            ok=1
            break
        fi
    done

    if [ $ok -eq 0 ]; then
        echo "❌ No responde $ip"
        no_alcanzadas+=("$ip")
    fi
done < "$archivo"

# Carpeta de reportes
reporte="informe_ping_$(date +%Y%m%d_%H%M%S).txt"

{
echo "📄 ===== INFORME FINAL ====="
echo
echo "✅ Redes alcanzadas:"
for ip in "${alcanzadas[@]}"; do
    echo "  - $ip"
done

echo
echo "❌ Redes NO alcanzadas:"
for ip in "${no_alcanzadas[@]}"; do
    echo "  - $ip"
done
} | tee "$reporte"

echo
echo "📂 Informe guardado en: $reporte"
