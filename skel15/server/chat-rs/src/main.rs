use axum::{
    Form,
    extract::{Query, State},
    http::{StatusCode, header},
    response::IntoResponse,
    routing::get,
};
use serde::Deserialize;
use sqlx::SqlitePool;
use tokio::net::TcpListener;
use tower_http::services::ServeDir;

#[derive(Clone)]
struct AppState {
    pool: SqlitePool,
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
    let pool = SqlitePool::connect("sqlite:data/chat.db").await?;
    sqlx::migrate!().run(&pool).await?;
    let state = AppState { pool };
    let app = axum::Router::new()
        .route("/api/mensajes", get(get_messages).post(send_message))
        .fallback_service(ServeDir::new("static"))
        .with_state(state);
    let listener = TcpListener::bind("0.0.0.0:8080").await?;
    axum::serve(listener, app).await?;
    Ok(())
}

async fn get_messages(
    State(state): State<AppState>,
    Query(from): Query<Since>,
) -> Result<impl IntoResponse, StatusCode> {
    let json = sqlx::query_scalar!(
    r#"SELECT json_group_array(json_object('id', id, 'nick', nick, 'texto', mensaje, 'fecha', instante) ORDER BY id) AS "json!: String"
       FROM mensajes WHERE id > ?"#,
    from.ultimo
)
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
    sqlx::query!(
        "INSERT INTO mensajes (nick, mensaje) VALUES (?, ?)",
        message.nick,
        message.mensaje
    )
    .execute(&state.pool)
    .await
    .map_err(|e| {
        eprintln!("{e}");
        StatusCode::INTERNAL_SERVER_ERROR
    })?;
    Ok(StatusCode::CREATED)
}
