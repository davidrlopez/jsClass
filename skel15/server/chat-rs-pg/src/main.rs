// El chat de chat-rs con Postgres en vez de SQLite, para compararlos (lo arranca comparar.sh).
// Cambia solo la base de datos:
// - PgPool en vez de SqlitePool, y la URL sale de DATABASE_URL.
// - $1, $2 en vez de ?, y json_agg en vez de json_group_array.
// - sqlx::query en vez de sqlx::query!: las macros necesitarían un Postgres en marcha al compilar.
use axum::{
    Form,
    extract::{Query, State},
    http::{StatusCode, header},
    response::IntoResponse,
    routing::get,
};
use serde::Deserialize;
use sqlx::PgPool;
use tokio::net::TcpListener;
use tower_http::services::ServeDir;

#[derive(Clone)]
struct AppState {
    pool: PgPool,
}

#[derive(Deserialize)]
struct Since {
    ultimo: i64,
}
#[derive(Deserialize)]
struct NewMessage {
    nick: String,
    mensaje: String,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let url = std::env::var("DATABASE_URL")?;
    let pool = PgPool::connect(&url).await?;
    sqlx::migrate!().run(&pool).await?;
    let state = AppState { pool };
    let app = axum::Router::new()
        .route("/api/mensajes", get(get_messages).post(send_message))
        .fallback_service(ServeDir::new("static"))
        .with_state(state);
    let listener = TcpListener::bind("127.0.0.1:8082").await?;
    axum::serve(listener, app).await?;
    Ok(())
}

async fn get_messages(
    State(state): State<AppState>,
    Query(from): Query<Since>,
) -> Result<impl IntoResponse, StatusCode> {
    // json_agg da NULL si no hay filas; json_group_array daba []
    let json: String = sqlx::query_scalar(
        "SELECT coalesce(json_agg(json_build_object('id', id, 'nick', nick, 'texto', mensaje, 'fecha', instante) ORDER BY id), '[]')::text
         FROM mensajes WHERE id > $1",
    )
    .bind(from.ultimo)
    .fetch_one(&state.pool)
    .await
    .map_err(|e| {
        eprintln!("{e}");
        StatusCode::INTERNAL_SERVER_ERROR
    })?;
    Ok(([(header::CONTENT_TYPE, "application/json")], json))
}

async fn send_message(
    State(state): State<AppState>,
    Form(message): Form<NewMessage>,
) -> Result<StatusCode, StatusCode> {
    sqlx::query("INSERT INTO mensajes (nick, mensaje) VALUES ($1, $2)")
        .bind(message.nick)
        .bind(message.mensaje)
        .execute(&state.pool)
        .await
        .map_err(|e| {
            eprintln!("{e}");
            StatusCode::INTERNAL_SERVER_ERROR
        })?;
    Ok(StatusCode::CREATED)
}
