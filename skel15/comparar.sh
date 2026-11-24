#!/bin/bash
# Compara el chat en cuatro servidores: PHP con php -S, PHP como en producción (nginx + php-fpm + OPcache),
# Rust con SQLite (chat-rs) y Rust con Postgres (chat-rs-pg). Mide con ab, que viene con macOS, y con wrk.
# Uso, con el cargo run parado: ./comparar.sh   Más carga: C=50 ./comparar.sh
# Columnas opcionales: brew install nginx wrk postgresql@18 (php-fpm ya viene con el php de Homebrew).
cd "$(dirname "$0")" || exit 1
SKEL=$PWD
RS=$SKEL/server/chat-rs
RSPG=$SKEL/server/chat-rs-pg
N=${N:-2000}   # shortcut: sin keep-alive cada petición abre un puerto; con N muy alto macOS se queda sin puertos
C=${C:-10}
PG_SYNC=${PG_SYNC:-on}   # off = misma garantía que SQLite con WAL y synchronous NORMAL

fallo() { echo "FALLO: $1"; exit 1; }
for cmd in ab php sqlite3 cargo curl; do command -v "$cmd" >/dev/null || fallo "falta $cmd"; done
php -m | grep -qi '^pdo_sqlite$' || fallo "tu php no tiene pdo_sqlite"
for p in 8000 8001 8080 8082; do curl -s -o /dev/null "127.0.0.1:$p" && fallo "el $p está ocupado (¿el cargo run?)"; done

FPM_BIN=$(command -v php-fpm || echo "$(brew --prefix php 2>/dev/null)/sbin/php-fpm")
FPM=0
if command -v nginx >/dev/null && [ -x "$FPM_BIN" ]; then
  NGINX_PARAMS=$(dirname "$(nginx -V 2>&1 | grep -o -- '--conf-path=[^ ]*' | cut -d= -f2)")/fastcgi_params
  [ -f "$NGINX_PARAMS" ] && FPM=1
fi
[ $FPM = 1 ] || echo "AVISO: falta nginx o php-fpm; la columna de nginx + php-fpm saldrá vacía (brew install nginx)"

# Los postgresql@NN de Homebrew no se enlazan en el PATH, así que se buscan también en su carpeta.
# Se busca el binario del servidor (postgres): libpq trae pg_ctl e initdb pero no el servidor
PGB=$(dirname "$(command -v postgres 2>/dev/null || echo ./x)")
[ -x "$PGB/postgres" ] || PGB=$(ls -d "$(brew --prefix 2>/dev/null)"/opt/postgresql@*/bin 2>/dev/null | tail -1)
PG=1; for b in postgres pg_ctl initdb createdb psql; do [ -x "$PGB/$b" ] || PG=0; done
[ $PG = 1 ] || echo "AVISO: falta Postgres; la columna de Rust + Postgres saldrá vacía (brew install postgresql@18)"

echo "Compilando en release (la primera vez tarda)..."
(cd "$RS" && cargo build --release -q) || fallo "cargo build --release"
BIN=$RS/target/release/chat
if [ $PG = 1 ]; then
  (cd "$RSPG" && cargo build --release -q) || fallo "cargo build --release de chat-rs-pg"
  BIN_PG=$RSPG/target/release/chat-pg
fi

# Una base de datos nueva por servidor, en una carpeta temporal: las tuyas no se tocan
T=$(mktemp -d)
mkdir -p "$T/phps" "$T/fpm" "$T/rs/data" "$T/nginx" "$T/rspg"
cp "$SKEL"/chat_*.php "$T/phps/"
cp "$SKEL"/chat_*.php "$T/fpm/"
ln -s "$RS/static" "$T/rs/static"
ln -s "$RS/static" "$T/rspg/static"
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
RSPG_PID=; PG_UP=
PSQL=("$PGB/psql" -q -X -h 127.0.0.1 -p 5439 -U chat -d chat -v ON_ERROR_STOP=1)
if [ $PG = 1 ]; then
  # Un Postgres de usar y tirar en la carpeta temporal, con la configuración por defecto, por TCP como en compose
  if "$PGB/initdb" -D "$T/pg" -U chat --auth=trust -E UTF8 --no-locale >"$T/pg.log" 2>&1 \
    && "$PGB/pg_ctl" -D "$T/pg" -l "$T/pg.log" -w -o "-p 5439 -k $T -c listen_addresses=127.0.0.1 -c synchronous_commit=$PG_SYNC" start >/dev/null \
    && PG_UP=1 && "$PGB/createdb" -h 127.0.0.1 -p 5439 -U chat chat \
    && "${PSQL[@]}" -f "$(ls "$RSPG"/migrations/*_mensajes.sql)" \
    && "${PSQL[@]}" -c "INSERT INTO mensajes(nick, mensaje) SELECT 'bot', 'mensaje ' || i FROM generate_series(1, 50) i"; then
    (cd "$T/rspg" && DATABASE_URL=postgres://chat@127.0.0.1:5439/chat exec "$BIN_PG") >"$T/rspg.log" 2>&1 &
    RSPG_PID=$!; disown
  else
    echo "AVISO: Postgres no arranca, se mide sin él:"; tail -5 "$T/pg.log"; PG=0
  fi
fi
limpiar() {
  for p in $PHP_PID $FPM_PID $NGINX_PID $RS_PID $RSPG_PID; do pkill -P "$p" 2>/dev/null; kill "$p" 2>/dev/null; done
  [ -n "$PG_UP" ] && "$PGB/pg_ctl" -D "$T/pg" -m fast stop >/dev/null 2>&1
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
if [ $PG = 1 ]; then
  listo "http://127.0.0.1:8082/$G50_RS" \
    || { echo "AVISO: Rust + Postgres no responde, se mide sin él. Sus últimos errores:"; tail -5 "$T/rspg.log"; PG=0; }
fi

# Antes de medir, que todos devuelvan lo mismo
cuenta() { curl -s "$1" | grep -o '"id"' | wc -l | tr -d ' '; }
comprueba() { [ "$(cuenta "$2")" = 50 ] && echo "OK: $1 devuelve los 50 mensajes" || fallo "$1 no devuelve 50 mensajes"; }
comprueba "php -S" "http://127.0.0.1:8000/$G50_PHP"
comprueba "Rust + SQLite" "http://127.0.0.1:8080/$G50_RS"
[ $PG = 1 ] && comprueba "Rust + Postgres" "http://127.0.0.1:8082/$G50_RS"
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
  local nombre=$1 php=$2 rs=$3 fpm=- pg=- phps m=medir; shift 3
  if [ "${1:-}" = -k ] && command -v wrk >/dev/null; then m=medir_k; set --; phps="no reutiliza"; fi
  [ -z "${phps:-}" ] && phps=$(medir "http://127.0.0.1:8000/$php" "$@")
  [ $FPM = 1 ] && fpm=$($m "http://127.0.0.1:8001/$php" "$@")
  [ $PG = 1 ] && pg=$($m "http://127.0.0.1:8082/$rs" "$@")
  printf '%-16s %20s %20s %20s %20s\n' "$nombre" "$phps" "$fpm" "$($m "http://127.0.0.1:8080/$rs" "$@")" "$pg"
}

echo
echo "$N peticiones, $C a la vez. Cada celda: peticiones por segundo (p99 en ms)"
[ $PG = 1 ] && echo "Postgres con synchronous_commit=$PG_SYNC"
command -v wrk >/dev/null && echo "Filas -k: con wrk durante 5 s, HTTP/1.1 como el navegador; el p99 lleva su unidad" \
  || echo "AVISO: sin wrk, las filas -k usan ab (HTTP/1.0) y nginx no reutiliza la conexión (brew install wrk)"
printf '%-16s %20s %20s %20s %20s\n' "" "php -S" "nginx + php-fpm" "Rust + SQLite" "Rust + Postgres"
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
filas "Rust + SQLite" "$T/rs/data/chat.db"
if [ $PG = 1 ]; then
  n=$("${PSQL[@]}" -tAc 'SELECT count(*) FROM mensajes')
  [ "$n" = $((50 + N)) ] && echo "OK: Rust + Postgres guardó los $N POST" || echo "FALLO: Rust + Postgres tiene $n filas, esperaba $((50 + N))"
fi

mem() { ps -o rss= -p "$(echo "$@" | tr ' ' ,)" | awk '{s+=$1} END {printf "%.1f MB", s/1024}'; }
echo "Memoria (RSS): php -S $(mem $PHP_PID $(pgrep -P $PHP_PID))"
[ $FPM = 1 ] && echo "               nginx + php-fpm $(mem $FPM_PID $(pgrep -P $FPM_PID) $NGINX_PID $(pgrep -P $NGINX_PID))"
echo "               Rust + SQLite $(mem $RS_PID) (la base de datos va dentro del proceso)"
if [ $PG = 1 ]; then
  PG_PID=$(head -1 "$T/pg/postmaster.pid")
  echo "               Rust + Postgres $(mem $RSPG_PID) el binario, más Postgres $(mem $PG_PID $(pgrep -P $PG_PID))"
  echo "               (lo de Postgres es el RSS sumado de sus procesos: cuenta varias veces la memoria compartida y exagera)"
fi
# footprint (de macOS) mide lo mismo que la columna Memoria del Monitor de Actividad y, con varios
# procesos, cuenta una sola vez lo que comparten. Es la cifra buena; la salida entera queda en huella-*.txt
if command -v footprint >/dev/null; then
  huella() { # nombre pid...
    local nombre=$1 p; shift
    local args=()
    for p in "$@"; do args+=(-p "$p"); done
    footprint "${args[@]}" > "$SKEL/huella-$nombre.txt" 2>&1
    echo "  $nombre: $(grep -o 'Footprint: [0-9.]* [KMG]*B' "$SKEL/huella-$nombre.txt" | tail -1)"
  }
  echo "Huella sin contar dos veces lo compartido (footprint):"
  huella rust-sqlite $RS_PID
  if [ $PG = 1 ]; then
    huella rust-postgres-binario $RSPG_PID
    huella postgres $PG_PID $(pgrep -P $PG_PID)
  fi
  [ $FPM = 1 ] && huella php-fpm-nginx $FPM_PID $(pgrep -P $FPM_PID) $NGINX_PID $(pgrep -P $NGINX_PID)
fi
echo "Binario de Rust: $(du -h "$BIN" | cut -f1)"
