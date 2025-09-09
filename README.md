# 🛰️ Discovery Ping Script

Script en **Bash** para realizar un ping de descubrimiento sobre una lista de redes/IPs.  
Permite identificar qué direcciones están activas y genera un **informe automático**.

## 📌 Características
- Entrada desde un archivo `.txt` con las IPs/redes (una por línea).  
- Hace hasta 5 intentos por host usando `ping -b`.  
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

Edita el archivo `redes.txt` con tus IPs (una por línea).

Ejecuta el script indicando el archivo de entrada:

```bash
./discovery_ping.sh redes.txt
```

## ⚠️ Requisitos
```
Linux / Unix con bash
```

Permisos para usar ping -b (puede requerir sudo en algunas distros)

## ✍️ Autor:
```
Angel J. Reynoso
KernelPanic01
kp01aj@gmail.com
```
