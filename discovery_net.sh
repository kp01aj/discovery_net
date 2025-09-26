#!/bin/bash
# Discovery Ping Script (fping por defecto, nmap opcional)
# Autor: Angel J. Reynoso (KernelPanic01)
# Uso: ./discovery_ping.sh [opciones] archivo_redes.txt
#
# Entradas del archivo:
#   - CIDR: 192.168.150.0/24
#   - IP:   192.168.150.254
#
# Modos:
#   (default) -m first  -> fping, detener en el primer host vivo por red (con progreso)
#   -m full             -> fping, revisar 100% de la red y listar todos los vivos (con progreso)
# Engines:
#   (default) -e fping  -> ICMP echo directo
#   -e nmap             -> nmap -sn (útil si ICMP/echo bloqueado para fping)
#
# Parámetros:
#   -m {first|full}   Modo de escaneo (default: first)
#   -e {fping|nmap}   Motor de escaneo (default: fping)
#   -t <ms>           Timeout por host en fping (ms) (default: 300)
#   -r <N>            Reintentos por host en fping (default: 0)
#   -h, --help        Ayuda y ejemplos

set -euo pipefail

# ===== Defaults =====
MODE="first"       # first | full
ENGINE="fping"     # fping | nmap
TIMEOUT_MS=300
RETRIES=0

usage() {
  cat <<EOF
🛰️ Discovery Ping Script

Uso: $0 [opciones] archivo_redes.txt

Opciones:
  -m {first|full}   Modo de escaneo (default: first)
                    first = se detiene en el primer host vivo por red
                    full  = revisa 100% de la red y lista todos los vivos
  -e {fping|nmap}   Motor de escaneo (default: fping)
                    fping = rápido, ICMP echo
                    nmap  = alternativo si ICMP/echo está bloqueado
  -t <ms>           Timeout por host en fping (ms) (default: 300)
  -r <N>            Reintentos por host en fping (default: 0)
  -h, --help        Mostrar esta ayuda

Ejemplos:
  # Por defecto: fping, detener en el primer host vivo por red
  $0 redes.txt

  # Revisar 100% de la red con fping
  $0 -m full redes.txt

  # Usar nmap discovery (cuando ICMP/echo está bloqueado para fping)
  $0 -e nmap redes.txt

  # Aumentar sensibilidad de fping
  $0 -t 800 -r 1 redes.txt
EOF
}

# ===== Ayuda cuando no hay args o se pide --help =====
if [ $# -eq 0 ]; then usage; exit 0; fi
while getopts ":m:e:t:r:-:h" opt; do
  case "$opt" in
    m) MODE="$OPTARG" ;;
    e) ENGINE="$OPTARG" ;;
    t) TIMEOUT_MS="$OPTARG" ;;
    r) RETRIES="$OPTARG" ;;
    h) usage; exit 0 ;;
    -)
      case "$OPTARG" in
        help) usage; exit 0 ;;
        *) echo "Opción desconocida --$OPTARG"; usage; exit 1 ;;
      esac ;;
    \?) echo "Opción inválida: -$OPTARG" >&2; usage; exit 1 ;;
    :) echo "La opción -$OPTARG requiere un valor." >&2; usage; exit 1 ;;
  esac
done
shift $((OPTIND -1))

if [ $# -ne 1 ]; then usage; exit 1; fi
archivo="$1"
if [ ! -f "$archivo" ]; then echo "❌ El archivo '$archivo' no existe."; exit 1; fi

# ===== Checks =====
have_cmd(){ command -v "$1" >/dev/null 2>&1; }
if [ "$ENGINE" = "fping" ] && ! have_cmd fping; then
  echo "❌ fping no está instalado. Instala: sudo apt-get install -y fping"; exit 1; fi
if [ "$ENGINE" = "nmap" ] && ! have_cmd nmap; then
  echo "❌ nmap no está instalado. Instala: sudo apt-get install -y nmap"; exit 1; fi
if ! have_cmd python3; then
  echo "❌ Python3 es necesario para expandir redes CIDR."; exit 1; fi

# ===== Utils =====
is_ip(){ [[ "$1" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; }

expand_cidr_hosts() {
  local cidr="$1"
  python3 - "$cidr" <<'PY'
import sys, ipaddress
net = ipaddress.ip_network(sys.argv[1], strict=False)
for h in net.hosts():
    print(str(h))
PY
}

fping_one() { # unicast 1 host
  local ip="$1"
  fping -r "$RETRIES" -t "$TIMEOUT_MS" "$ip" >/dev/null 2>&1
}

nmap_discovery() { # devuelve IPs vivas
  local target="$1"
  nmap -sn "$target" --max-retries 1 --max-rtt-timeout 800ms 2>/dev/null \
    | awk '/Nmap scan report/{print $5}'
}

# ===== Cargar objetivos =====
mapfile -t objetivos < <(grep -Ev '^\s*(#|$)' "$archivo")
TOTAL=${#objetivos[@]}
if [ "$TOTAL" -eq 0 ]; then echo "⚠️ No hay objetivos válidos en '$archivo'."; exit 0; fi

alcanzadas=(); no_alcanzadas=()

# ===== Bucle principal =====
idx=0
for objetivo in "${objetivos[@]}"; do
  idx=$((idx+1)); percent=$(( idx * 100 / TOTAL ))
  echo
  echo "===== [$idx/$TOTAL — ${percent}%] Objetivo: $objetivo ====="

  if [[ "$objetivo" == */* ]]; then
    # ----- CIDR -----
    if [ "$ENGINE" = "nmap" ]; then
      echo "🔧 Método: nmap -sn (descubrimiento ICMP/ARP/otros)"
      mapfile -t vivos < <(nmap_discovery "$objetivo")
      if [ "${#vivos[@]}" -gt 0 ]; then
        if [ "$MODE" = "first" ]; then
          echo "✅ Primer host vivo: ${vivos[0]} (red $objetivo)"
          alcanzadas+=("$objetivo (${vivos[0]})")
        else
          echo "✅ ${#vivos[@]} hosts vivos en $objetivo:"; for ip in "${vivos[@]}"; do echo "  - $ip"; done
          alcanzadas+=("$objetivo (${#vivos[@]} hosts)")
        fi
      else
        echo "❌ Ningún host respondió en $objetivo"
        no_alcanzadas+=("$objetivo")
      fi
    else
      # ENGINE = fping (progreso por host)
      mapfile -t hosts < <(expand_cidr_hosts "$objetivo" 2>/dev/null || true)
      if [ "${#hosts[@]}" -eq 0 ]; then
        echo "⚠️ CIDR inválido o sin hosts: $objetivo"; no_alcanzadas+=("$objetivo (CIDR inválido)"); continue
      fi
      total_hosts=${#hosts[@]}; count=0; found=""
      if [ "$MODE" = "first" ]; then
        for ip in "${hosts[@]}"; do
          count=$((count+1)); p=$(( count * 100 / total_hosts ))
          printf "  → Probando %-15s [%4d/%4d — %3d%%]\r" "$ip" "$count" "$total_hosts" "$p"
          if fping_one "$ip"; then
            printf "\n"; echo "✅ Host vivo encontrado: $ip (red $objetivo)"
            alcanzadas+=("$objetivo ($ip)"); found="yes"; break
          fi
        done
        if [ -z "$found" ]; then printf "\n"; echo "❌ Ningún host respondió en $objetivo"; no_alcanzadas+=("$objetivo"); fi
      else
        vivos_list=()
        for ip in "${hosts[@]}"; do
          count=$((count+1)); p=$(( count * 100 / total_hosts ))
          printf "  → Probando %-15s [%4d/%4d — %3d%%]\r" "$ip" "$count" "$total_hosts" "$p"
          if fping_one "$ip"; then vivos_list+=( "$ip" ); fi
        done
        printf "\n"
        if [ "${#vivos_list[@]}" -gt 0 ]; then
          echo "✅ ${#vivos_list[@]} hosts vivos en $objetivo:"; for ip in "${vivos_list[@]}"; do echo "  - $ip"; done
          alcanzadas+=("$objetivo (${#vivos_list[@]} hosts)")
        else
          echo "❌ Ningún host respondió en $objetivo"; no_alcanzadas+=("$objetivo")
        fi
      fi
    fi
  else
    # ----- IP -----
    if is_ip "$objetivo"; then
      printf "  → Probando %-15s [  1/  1 — 100%%]\r" "$objetivo"
      if [ "$ENGINE" = "nmap" ]; then
        printf "\n"; mapfile -t vivos < <(nmap_discovery "$objetivo")
        if [ "${#vivos[@]}" -gt 0 ]; then echo "✅ Host vivo $objetivo"; alcanzadas+=("$objetivo")
        else echo "❌ No responde $objetivo"; no_alcanzadas+=("$objetivo"); fi
      else
        if fping_one "$objetivo"; then printf "\n"; echo "✅ Host vivo $objetivo"; alcanzadas+=("$objetivo")
        else printf "\n"; echo "❌ No responde $objetivo"; no_alcanzadas+=("$objetivo"); fi
      fi
    else
      echo "⚠️ Línea inválida (ni IP ni CIDR): $objetivo"; no_alcanzadas+=("$objetivo (inválido)")
    fi
  fi
done

# ===== Informe =====
echo
mkdir -p informes
reporte="informes/informe_ping_$(date +%Y%m%d_%H%M%S).txt"
{
  echo "📄 ===== INFORME FINAL ====="
  echo
  echo "✅ Objetivos alcanzados:"
  if [ ${#alcanzadas[@]} -eq 0 ]; then echo "  (ninguno)"; else for x in "${alcanzadas[@]}"; do echo "  - $x"; done; fi
  echo
  echo "❌ Objetivos NO alcanzados:"
  if [ ${#no_alcanzadas[@]} -eq 0 ]; then echo "  (ninguno)"; else for x in "${no_alcanzadas[@]}"; do echo "  - $x"; done; fi
} | tee "$reporte"
echo "📂 Informe guardado en: $reporte"
