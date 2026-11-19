#!/bin/bash
# Compara el chat en tres servidores: PHP con php -S, PHP como en producción (nginx + php-fpm + OPcache)
# y Rust (release). Mide con ab, que viene con macOS.
# Uso, con el cargo run parado: ./comparar.sh   Más carga: C=50 ./comparar.sh
# Para la columna de nginx + php-fpm: brew install nginx (php-fpm ya viene con el php de Homebrew).
cd "$(dirname "$0")" || exit 1
SKEL=$PWD
RS=$SKEL/server/chat-rs
N=${N:-2000}   # shortcut: sin keep-alive cada petición abre un puerto; con N muy alto macOS se queda sin puertos
C=${C:-10}

fallo() { echo "FALLO: $1"; exit 1; }
for cmd in ab php sqlite3 cargo curl; do command -v "$cmd" >/dev/null || fallo "falta $cmd"; done
php -m | grep -qi '^pdo_sqlite$' || fallo "tu php no tiene pdo_sqlite"
for p in 8000 8001 8080; do curl -s -o /dev/null "127.0.0.1:$p" && fallo "el $p está ocupado (¿el cargo run?)"; done

FPM_BIN=$(command -v php-fpm || echo "$(brew --prefix php 2>/dev/null)/sbin/php-fpm")
FPM=0
if command -v nginx >/dev/null && [ -x "$FPM_BIN" ]; then
  NGINX_PARAMS=$(dirname "$(nginx -V 2>&1 | grep -o -- '--conf-path=[^ ]*' | cut -d= -f2)")/fastcgi_params
  [ -f "$NGINX_PARAMS" ] && FPM=1
fi
[ $FPM = 1 ] || echo "AVISO: falta nginx o php-fpm; la columna de nginx + php-fpm saldrá vacía (brew install nginx)"

echo "Compilando en release (la primera vez tarda)..."
(cd "$RS" && cargo build --release -q) || fallo "cargo build --release"
BIN=$RS/target/release/chat

# Una base de datos nueva por servidor, en una carpeta temporal: las tuyas no se tocan
T=$(mktemp -d)
mkdir -p "$T/phps" "$T/fpm" "$T/rs/data" "$T/nginx"
cp "$SKEL"/chat_*.php "$T/phps/"
cp "$SKEL"/chat_*.php "$T/fpm/"
ln -s "$RS/static" "$T/rs/static"
SEMILLA="WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i+1 FROM n WHERE i<50)
INSERT INTO mensajes(nick, mensaje) SELECT 'bot', 'mensaje ' || i FROM n;"
for db in "$T/phps/chat.db" "$T/fpm/chat.db" "$T/rs/data/chat.db"; do
  { sqlite3 "$db" < "$SKEL/chat-sqlite.sql" && sqlite3 "$db" "$SEMILLA"; } || fallo "crear $db"
done
printf 'nick=bot&mensaje=hola' > "$T/post.txt"
printf '<?php echo json_encode((opcache_get_status(false)["opcache_enabled"] ?? false) === true);' > "$T/fpm/opcache.php"

# php -S con 4 procesos: a secas atiende de una en una
PHP_CLI_SERVER_WORKERS=4 php -S 127.0.0.1:8000 -t "$T/phps" >/dev/null 2>&1 &
PHP_PID=$!; disown
(cd "$T/rs" && exec "$BIN") >/dev/null 2>&1 &
RS_PID=$!; disown
FPM_PID=; NGINX_PID=
if [ $FPM = 1 ]; then
  # Un proceso de PHP por núcleo, como tokio con Rust, y OPcache sin revisar los archivos, como en producción
  cat > "$T/fpm.conf" <<EOF
[global]
error_log = $T/fpm.log
daemonize = no
[www]
listen = $T/fpm.sock
pm = static
pm.max_children = $(sysctl -n hw.ncpu)
EOF
  "$FPM_BIN" -y "$T/fpm.conf" -d opcache.enable=1 -d opcache.validate_timestamps=0 >/dev/null 2>&1 &
  FPM_PID=$!; disown
  cat > "$T/nginx.conf" <<EOF
daemon off;
worker_processes auto;
pid $T/nginx/nginx.pid;
error_log $T/nginx/error.log;
events { worker_connections 1024; }
http {
  access_log off;
  client_body_temp_path $T/nginx/body;
  fastcgi_temp_path $T/nginx/fastcgi;
  proxy_temp_path $T/nginx/proxy;
  uwsgi_temp_path $T/nginx/uwsgi;
  scgi_temp_path $T/nginx/scgi;
  server {
    listen 127.0.0.1:8001;
    root $T/fpm;
    location ~ \.php\$ {
      include $NGINX_PARAMS;
      fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
      fastcgi_pass unix:$T/fpm.sock;
    }
  }
}
EOF
  nginx -c "$T/nginx.conf" -p "$T/nginx/" -e "$T/nginx/error.log" >/dev/null 2>&1 &
  NGINX_PID=$!; disown
fi
limpiar() {
  for p in $PHP_PID $FPM_PID $NGINX_PID $RS_PID; do pkill -P "$p" 2>/dev/null; kill "$p" 2>/dev/null; done
  rm -rf "$T"
}
trap limpiar EXIT

G50_PHP="chat_select_get_json.php?ultimo=0";  G50_RS="api/mensajes?ultimo=0"
G0_PHP="chat_select_get_json.php?ultimo=50";  G0_RS="api/mensajes?ultimo=50"

listo() { for _ in $(seq 50); do curl -sf -o /dev/null "$1" && return 0; sleep 0.2; done; return 1; }
espera() { listo "$1" || fallo "no arranca $1"; }
espera "http://127.0.0.1:8000/$G50_PHP"
espera "http://127.0.0.1:8080/$G50_RS"
if [ $FPM = 1 ]; then
  listo "http://127.0.0.1:8001/$G50_PHP" \
    || { echo "AVISO: nginx + php-fpm no responde, se mide sin él. Sus últimos errores:"; cat "$T/nginx/error.log" "$T/fpm.log" 2>/dev/null | tail -5; FPM=0; }
fi

# Antes de medir, que todos devuelvan lo mismo
cuenta() { curl -s "$1" | grep -o '"id"' | wc -l | tr -d ' '; }
comprueba() { [ "$(cuenta "$2")" = 50 ] && echo "OK: $1 devuelve los 50 mensajes" || fallo "$1 no devuelve 50 mensajes"; }
comprueba "php -S" "http://127.0.0.1:8000/$G50_PHP"
comprueba "Rust" "http://127.0.0.1:8080/$G50_RS"
if [ $FPM = 1 ]; then
  comprueba "nginx + php-fpm" "http://127.0.0.1:8001/$G50_PHP"
  [ "$(curl -s http://127.0.0.1:8001/opcache.php)" = true ] && echo "OK: OPcache activo en php-fpm" \
    || echo "AVISO: OPcache no está activo en php-fpm; PHP sale peor de lo que sería en producción"
fi

medir() { # url [opciones de ab] -> "pet/s (p99 ms)", con *N si hubo N fallos y "sin reusar" si -k no reutilizó
  local url=$1 out bad ka; shift
  out=$(ab -q -n "$N" -c "$C" "$@" "$url" 2>&1) || { echo "ab falló"; return; }
  bad=$(echo "$out" | awk '/Failed requests|Non-2xx responses/ {s+=$3} END {print s+0}')
  ka=$(echo "$out" | awk '/Keep-Alive requests/ {print $3}')
  printf '%s (%s)%s%s' \
    "$(echo "$out" | awk '/Requests per second/ {printf "%d", $4}')" \
    "$(echo "$out" | awk '$1=="99%" {print $2}')" \
    "$([ "$bad" != 0 ] && echo " *$bad")" \
    "$([ "$ka" = 0 ] && echo " sin reusar")"
}
# ab habla HTTP/1.0: sin Content-Length, nginx cierra la conexión porque no puede usar chunked, y la
# respuesta de PHP no lo lleva. El navegador habla HTTP/1.1, así que con -k se mide con wrk si está.
medir_k() { # url -> "pet/s (p99 con su unidad)"
  local out bad; out=$(wrk -t 4 -c "$C" -d 5s --latency "$1" 2>&1) || { echo "wrk falló"; return; }
  bad=$(echo "$out" | awk '/Non-2xx or 3xx responses/ {print $5}')
  printf '%s (%s)%s' "$(echo "$out" | awk '/^Requests\/sec/ {printf "%d", $2}')" \
    "$(echo "$out" | awk '$1=="99%" {print $2}')" "$([ -n "$bad" ] && echo " *$bad")"
}
fila() { # nombre ruta_php ruta_rust [opciones de ab]
  local nombre=$1 php=$2 rs=$3 fpm=- phps m=medir; shift 3
  if [ "${1:-}" = -k ] && command -v wrk >/dev/null; then m=medir_k; set --; phps="no reutiliza"; fi
  [ -z "${phps:-}" ] && phps=$(medir "http://127.0.0.1:8000/$php" "$@")
  [ $FPM = 1 ] && fpm=$($m "http://127.0.0.1:8001/$php" "$@")
  printf '%-16s %20s %20s %20s\n' "$nombre" "$phps" "$fpm" "$($m "http://127.0.0.1:8080/$rs" "$@")"
}

echo
echo "$N peticiones, $C a la vez. Cada celda: peticiones por segundo (p99 en ms)"
command -v wrk >/dev/null && echo "Filas -k: con wrk durante 5 s, HTTP/1.1 como el navegador; el p99 lleva su unidad" \
  || echo "AVISO: sin wrk, las filas -k usan ab (HTTP/1.0) y nginx no reutiliza la conexión (brew install wrk)"
printf '%-16s %20s %20s %20s\n' "" "php -S" "nginx + php-fpm" "Rust"
# -k: reutilizar la conexión, como hace el navegador entre un fetch y el siguiente
# 0 filas: lo que pide el chat cada 2 s cuando no hay mensajes nuevos
fila "GET 50 filas" "$G50_PHP" "$G50_RS"
fila "GET 50 filas -k" "$G50_PHP" "$G50_RS" -k
fila "GET 0 filas" "$G0_PHP" "$G0_RS"
fila "GET 0 filas -k" "$G0_PHP" "$G0_RS" -k
fila "POST" chat_insert_post.php api/mensajes -p "$T/post.txt" -T application/x-www-form-urlencoded

echo
filas() { sqlite3 "$2" 'SELECT count(*) FROM mensajes' | { read -r n; [ "$n" = $((50 + N)) ] && echo "OK: $1 guardó los $N POST" || echo "FALLO: $1 tiene $n filas, esperaba $((50 + N))"; }; }
filas "php -S" "$T/phps/chat.db"
[ $FPM = 1 ] && filas "nginx + php-fpm" "$T/fpm/chat.db"
filas "Rust" "$T/rs/data/chat.db"

mem() { ps -o rss= -p "$(echo "$@" | tr ' ' ,)" | awk '{s+=$1} END {printf "%.1f MB", s/1024}'; }
echo "Memoria (RSS): php -S $(mem $PHP_PID $(pgrep -P $PHP_PID))"
[ $FPM = 1 ] && echo "               nginx + php-fpm $(mem $FPM_PID $(pgrep -P $FPM_PID) $NGINX_PID $(pgrep -P $NGINX_PID))"
echo "               Rust $(mem $RS_PID)"
echo "Binario de Rust: $(du -h "$BIN" | cut -f1)"
