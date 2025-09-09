# 🛰️ Discovery Net Script

Script en **Bash** para realizar un descubrimiento de hosts activos dentro de una lista de redes/IPs.  
Permite identificar rápidamente direcciones alcanzables y generar un **informe automático**.

## 📌 Características
- Entrada desde un archivo `.txt` con las IPs/redes (una por línea).  
- Soporta **IPs individuales** (`192.168.1.10`) y **redes CIDR** (`192.168.1.0/24`).  
- Por defecto utiliza **fping** y se detiene en el **primer host vivo** encontrado en cada red.  
- Opcionalmente puede recorrer el **100% de la red** y listar todos los hosts activos.  
- Permite usar **nmap discovery** como motor alternativo en caso de que ICMP/fping esté bloqueado.  
- Muestra progreso con IPs probadas y porcentaje de avance.  
- Genera un **informe final** en pantalla y en un archivo con fecha (`informe_ping_YYYYMMDD_HHMMSS.txt`).  
- Salta líneas vacías o comentarios con `#`.  

## 🚀 Instalación
Clona el repositorio y da permisos de ejecución al script:

```bash
git clone https://github.com/kp01aj/discovery_ping.git
cd discovery_ping
chmod +x discovery_ping.sh
```

## ▶️ Uso

Edita el archivo `redes.txt` con tus IPs/redes (una por línea).

### Ejecución básica (modo por defecto)
Usa **fping** y se detiene en el primer host encontrado en cada red:
```bash
./discovery_ping.sh redes.txt
```

### Revisar el 100% de la red
Escanea todos los hosts de cada red y lista los activos:
```bash
./discovery_ping.sh -m full redes.txt
```

### Usar nmap discovery
Cuando ICMP está bloqueado y fping no funciona, usa `nmap -sn`:
```bash
./discovery_ping.sh -e nmap redes.txt
```

### Ajustar sensibilidad de fping
Aumentar el timeout a 800ms y permitir 1 reintento por host:
```bash
./discovery_ping.sh -t 800 -r 1 redes.txt
```

## ⚠️ Requisitos
- Linux / Unix con `bash`  
- Dependencias:
  - [`fping`](https://fping.org/) (por defecto) → `sudo apt-get install -y fping`  
  - [`nmap`](https://nmap.org/) (si eliges motor `-e nmap`) → `sudo apt-get install -y nmap`  
  - `python3` (para expandir redes CIDR a hosts)  

## 📄 Ejemplo de salida

```
===== [1/3 — 33%] Objetivo: 192.168.1.0/24 =====
  → Probando 192.168.1.1       [  1/254 —   0%]
  → Probando 192.168.1.2       [  2/254 —   1%]
✅ Host vivo encontrado: 192.168.1.2 (red 192.168.1.0/24)

===== [2/3 — 66%] Objetivo: 10.10.10.0/24 =====
  → Probando 10.10.10.1        [  1/254 —   0%]
❌ Ningún host respondió en 10.10.10.0/24

📄 ===== INFORME FINAL =====

✅ Objetivos alcanzados:
  - 192.168.1.0/24 (192.168.1.2)

❌ Objetivos NO alcanzados:
  - 10.10.10.0/24
```

## ✍️ Autor
**Angel J. Reynoso**  
Alias: *KernelPanic01*  
📧 Email: `kp01aj@gmail.com`
