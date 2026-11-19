# Guía: el chat del ej15 en Rust

Objetivo: que el front del ej15 funcione igual contra Rust que contra el PHP del profe. Es el ensayo de los ejercicios 1, 3 y 5 de openmoody, con las mismas piezas.

Antes: capítulos 1 a 6 y 9 del Book. El paso 3 necesita el 9 (`?`), y los pasos 4 a 6 necesitan el 5 (structs) y el 6 (`Option`, `match`). De async (capítulo 17) basta con saber que `.await` espera a que algo termine.

Regla para todos los pasos: nada de `unwrap()` en los handlers, y antes de enseñarme el código, pasa `cargo clippy`.

Así quedará la carpeta:

```
skel15/
  server/          el PHP y chat-sqlite.sql (no se tocan)
  chat-rs/
    Cargo.toml
    .env           DATABASE_URL para las macros de sqlx
    migrations/    el esquema
    static/        index.html, script.js, styles.css, bootstrap.css, bootstrap.js
    src/main.rs
    data/chat.db   la crea sqlx, no va a git
```

---

## 0. El front, primero contra el PHP

Si todavía no tienes el `script.js`, hazlo antes contra el PHP: es lo que evalúa el profe, y así sabrás que el front está bien antes de cambiar el servidor.

- Copia a `skel15/` el `index.html`, `styles.css`, `bootstrap.css` y `bootstrap.js` del ej15 del profe.
- `sqlite3 server/chat.db < server/chat-sqlite.sql` y `php -S localhost:8000` desde `skel15`.
- El POST, con `new URLSearchParams({ nick, mensaje })` como `body`, **no con `FormData`**. Al PHP le dan igual los dos, pero `FormData` viaja como multipart y el `Form` de axum lo rechaza con un 415. Si lo haces bien desde el principio, en el paso 6 no tendrás que tocar el front.

Funciona si: en `localhost:8000` mandas un mensaje y aparece, y en otra pestaña también.

## 1. El proyecto

```sh
cd skel15
cargo new chat-rs --name chat     # new crea la carpeta; init es para una que ya existe
cd chat-rs
cargo add axum@0.8
cargo add tokio@1 --features full
cargo add tower-http@0.7 --features fs
cargo add serde@1 --features derive
cargo add sqlx@0.9 --features runtime-tokio,sqlite
```

`cargo add` escribe en el `Cargo.toml` por ti. La `@` fija la versión mayor de la escalera de openmoody. `serde_json` no hace falta: el `Json` de axum ya lo usa por dentro.

Funciona si: `cargo build` compila (la primera vez tarda un rato).

## 2. La base de datos

```sh
echo 'DATABASE_URL=sqlite:data/chat.db' > .env
mkdir data migrations
cp ../server/chat-sqlite.sql "migrations/$(date +%Y%m%d%H%M%S)_mensajes.sql"
sqlite3 data/chat.db < migrations/*_mensajes.sql
```

- El nombre `<fecha>_mensajes.sql` es el que espera sqlx: el número de delante es la versión de la migración.
- Al arrancar (paso 4), `migrate!()` aplica esta migración otra vez. Como es `CREATE TABLE IF NOT EXISTS`, no hace nada y solo la apunta en `_sqlx_migrations`.
- Con `sqlx-cli` es lo mismo, y además apunta la migración desde ya (es lo que hace el ejercicio 3 de openmoody):

  ```sh
  cargo install sqlx-cli --no-default-features --features sqlite   # una vez, tarda unos minutos
  echo 'DATABASE_URL=sqlite:data/chat.db' > .env
  mkdir data
  sqlx database create
  sqlx migrate add mensajes    # crea migrations/<fecha>_mensajes.sql: pega dentro chat-sqlite.sql
  sqlx migrate run
  ```
- Crea `chat-rs/.gitignore` con `target/`, `data/` y `.env`. Como `js/` ya es un repo de git, `cargo new` no lo crea, y sin él subirías a git cientos de MB de `target/`.

¿Por qué este orden? Las macros `query!` y `query_as!` comprueban el SQL contra `data/chat.db` **al compilar**. Si la tabla no existe todavía, no compila (`no such table`).

Funciona si: `sqlite3 data/chat.db .tables` muestra `mensajes`.

## 3. Servir el front (= openmoody 1)

- Copia el front que funciona (los 5 archivos del paso 0) a `chat-rs/static/`. Así la base de datos y el código quedan fuera de lo que se sirve.
- `main` con `#[tokio::main]`, `async` y que devuelva `Result<(), Box<dyn std::error::Error>>` para poder usar `?`.
- `axum::Router::new().fallback_service(ServeDir::new("static"))`. `ServeDir` está en `tower_http::services` y sirve `index.html` cuando pides `/`.
- `tokio::net::TcpListener::bind("127.0.0.1:8080")` y `axum::serve(listener, app)`. Con `127.0.0.1` no te ve nadie de la red del instituto. `serve(...).await` no vuelve mientras el servidor esté vivo: todo lo demás va antes.

Las rutas son relativas a la carpeta desde la que lanzas el programa: `cargo run` desde `chat-rs`.

Funciona si:
- `localhost:8080` muestra el chat (los fetch fallan con 404; es normal de momento).
- `curl -i localhost:8080/bootstrap.css` da 200 con `content-type: text/css`.
- `curl -i localhost:8080/Cargo.toml` y `curl -i localhost:8080/data/chat.db` dan 404.

## 4. Conexión y estado (= openmoody 3)

- `SqlitePool::connect("sqlite:data/chat.db").await?`. La URL va escrita en el código: el `.env` solo lo leen `sqlx` y las macros, y este chat no se despliega. (Las opciones con WAL del ejercicio 3 de openmoody aquí sobran.)
- Después, `sqlx::migrate!().run(&pool).await?`: mete las migraciones en el binario y aplica las que falten al arrancar.
- `#[derive(Clone)] struct AppState { pool: SqlitePool }`, que se pasa con `.with_state(...)` al final del `Router` y se recibe en cada handler con `State(state): State<AppState>`. En openmoody el `AppState` llevará más cosas; aquí solo el pool, pero la forma es la misma.

Funciona si: `cargo run` arranca, después `sqlite3 data/chat.db .tables` muestra también `_sqlx_migrations`, y si renombras `data/` sale con un `Error: ...` legible, no con un pánico.

## 5. GET /api/mensajes?ultimo=N (= openmoody 5)

- La entrada: `#[derive(Deserialize)] struct Desde { ultimo: i64 }` y el extractor `Query<Desde>`. Si `ultimo` no es un número, axum ya responde 400 por su cuenta.
- La salida: `#[derive(Serialize)] struct Mensaje` con `id`, `nick`, `texto` y `fecha`, los mismos nombres que el JSON del PHP.
- La consulta: `sqlx::query_as!(Mensaje, "...", desde.ultimo)` y `.fetch_all(&state.pool).await`. Las columnas se llaman `mensaje` e `instante`, y el struct pide `texto` y `fecha`: renómbralas con `AS` en el SELECT. Añade `ORDER BY id`: el PHP no lo pone y funciona de casualidad.
- La respuesta: el handler devuelve `Result<Json<Vec<Mensaje>>, StatusCode>`. El error de sqlx lo conviertes con `.map_err(...)` en `StatusCode::INTERNAL_SERVER_ERROR`, y antes lo imprimes con `eprintln!`; si no, no sabrás qué ha fallado. (Lo de convertir errores bien es el ejercicio 4 de openmoody.)
- La ruta: `.route("/api/mensajes", get(listar))`, con `get` de `axum::routing`.

Funciona si (con un mensaje metido a mano con `sqlite3`):
- `curl 'localhost:8080/api/mensajes?ultimo=0'` devuelve una lista JSON con los cuatro campos.
- `?ultimo=` con el id del último mensaje devuelve `[]`.
- `?ultimo=abc` da 400.

## 6. POST /api/mensajes

- `#[derive(Deserialize)] struct Nuevo { nick: String, mensaje: String }` y el extractor `Form<Nuevo>`. Va el **último** entre los argumentos del handler, porque es el que se come el cuerpo.
- `sqlx::query!("INSERT ...", ...)` con `.execute(&state.pool).await`, y el error, igual que en el paso 5.
- Devuelve `StatusCode::CREATED` (201). Para el `res.ok` del front, es igual que el 200 del PHP.
- La ruta: el mismo `.route` del paso 5, con `.post(enviar)` encadenado.
- En `static/script.js`, cambia las dos URLs del PHP por `/api/mensajes`.

Funciona si:
- `curl -i -d 'nick=ana&mensaje=hola' localhost:8080/api/mensajes` da 201 y el mensaje sale en el GET.
- `curl -i -F nick=ana -F mensaje=hola localhost:8080/api/mensajes` da 415 (es lo que haría `FormData`).
- Sin el campo `mensaje`: 422.
- Un nick de 17 caracteres no entra en la base de datos. Por ahora vale con que dé 500, porque lo frena el `CHECK`.
- El chat del navegador funciona igual que en el paso 0, con dos pestañas.

## Extra (si te sobra tiempo)

- Que un nick o un mensaje demasiado largo dé 400 antes de llegar a la base de datos: `nick.chars().count() > 16`. Usa `chars().count()`, no `len()`, porque `len()` cuenta bytes y una `ñ` son 2. Y que un nick o un mensaje vacío también dé 400, después de `trim()`. El `CHECK` se queda como red de seguridad.
- El handler del POST devuelve el mensaje creado con `RETURNING` (el `query_as!` del ejercicio 5 de openmoody).

## Si te atascas

| Lo que ves | Qué pasa |
|---|---|
| `no such table: mensajes` al compilar | No has creado `data/chat.db` con `sqlite3` o el `.env` no está en `chat-rs/` |
| Todo da 404, también `/` | Has lanzado `cargo run` desde otra carpeta |
| 415 en el POST | El front manda `FormData` o el `curl` usa `-F` |
| 422 en el POST | Los nombres del formulario no coinciden con los campos de `Nuevo` |
| `Address already in use` | Otro `cargo run` sigue abierto en el 8080 |
