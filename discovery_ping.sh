#!/bin/bash
# Discovery Ping Script (CIDR-aware)
# Autor: Angel J. Reynoso (KernelPanic01)
# Uso: ./discovery_ping.sh redes.txt

set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Uso: $0 archivo_redes.txt"
  exit 1
fi

archivo="$1"
if [ ! -f "$archivo" ]; then
  echo "❌ El archivo '$archivo' no existe."
  exit 1
fi

# === Helper: broadcast de una red CIDR usando Python (ipaddress) ===
get_broadcast() {
  local cidr="$1"
  python3 - "$cidr" <<'PY'
import sys, ipaddress
cidr = sys.argv[1]
net = ipaddress.ip_network(cidr, strict=False)
print(net.broadcast_address)
PY
}

alcanzadas=()
no_alcanzadas=()

INTENTOS=5
TIMEOUT=1   # segundos

while IFS= read -r linea; do
  # Saltar vacías/comentarios
  [[ -z "${linea// }" || "$linea" =~ ^# ]] && continue

  objetivo="$linea"

  if [[ "$objetivo" == */* ]]; then
    # --- Es una red CIDR ---
    # Validar/obtener broadcast
    if ! bcast="$(get_broadcast "$objetivo" 2>/dev/null)"; then
      echo "⚠️  CIDR inválido: $objetivo"
      no_alcanzadas+=("$objetivo (CIDR inválido)")
      continue
    fi

    echo "🔍 Probando red $objetivo (broadcast $bcast) ..."
    ok=0
    for ((i=1; i<=INTENTOS; i++)); do
      if ping -b -c 1 -W "$TIMEOUT" "$bcast" >/dev/null 2>&1; then
        echo "✅ Respuesta en la red $objetivo (via broadcast $bcast)"
        alcanzadas+=("$objetivo")
        ok=1
        break
      fi
    done
    if [ $ok -eq 0 ]; then
      echo "❌ Sin respuesta en la red $objetivo (broadcast $bcast)"
      no_alcanzadas+=("$objetivo")
    fi

  else
    # --- Es una IP ---
    echo "🔍 Probando host $objetivo ..."
    ok=0
    for ((i=1; i<=INTENTOS; i++)); do
      if ping -c 1 -W "$TIMEOUT" "$objetivo" >/dev/null 2>&1; then
        echo "✅ Host vivo $objetivo"
        alcanzadas+=("$objetivo")
        ok=1
        break
      fi
    done
    if [ $ok -eq 0 ]; then
      echo "❌ No responde $objetivo"
      no_alcanzadas+=("$objetivo")
    fi
  fi

done < "$archivo"

echo
mkdir -p informes
reporte="informes/informe_ping_$(date +%Y%m%d_%H%M%S).txt"

{
  echo "📄 ===== INFORME FINAL ====="
  echo
  echo "✅ Objetivos alcanzados:"
  if [ ${#alcanzadas[@]} -eq 0 ]; then
    echo "  (ninguno)"
  else
    for x in "${alcanzadas[@]}"; do echo "  - $x"; done
  fi
  echo
  echo "❌ Objetivos NO alcanzados:"
  if [ ${#no_alcanzadas[@]} -eq 0 ]; then
    echo "  (ninguno)"
  else
    for x in "${no_alcanzadas[@]}"; do echo "  - $x"; done
  fi
} | tee "$reporte"

echo "📂 Informe guardado en: $reporte"
