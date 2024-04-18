use axum::{
	extract::Json,
	routing::{get, post},
	Router,
};

use serde::Deserialize;
use sqlx::{postgres::PgPoolOptions, query};

#[derive(Deserialize)]
struct Test {
	foo: String,
}

#[tokio::main]
async fn main() {
	let pool = PgPoolOptions::new()
		.max_connections(5)
		.connect("postgres://postgres:root@localhost:5432/straif")
		.await
		.unwrap();

	let app = Router::new().route("/", post(test)).with_state(pool);

	let listener = tokio::net::TcpListener::bind("0.0.0.0:8000").await.unwrap();
	axum::serve(listener, app).await.unwrap();
}

async fn test(Json(payload): Json<Test>) -> String {
	payload.foo
}
