pub mod routes;

use axum::{body::Body, http::Response, response::IntoResponse, Router};
use sqlx::{postgres::PgPoolOptions, Pool, Postgres};

type AppState = Pool<Postgres>;

enum ResponseError {
	ValidationError(validator::ValidationErrors),
	QueryError,
}

impl From<validator::ValidationErrors> for ResponseError {
	fn from(value: validator::ValidationErrors) -> Self {
		ResponseError::ValidationError(value)
	}
}

impl IntoResponse for ResponseError {
	fn into_response(self) -> Response<Body> {
		match self {
			Self::ValidationError(e) => e.to_string().into_response(),
			Self::QueryError => "Invalid Query".to_string().into_response(),
		}
	}
}

#[tokio::main]
async fn main() {
	let pool = PgPoolOptions::new()
		.max_connections(5)
		.connect("postgres://postgres:root@localhost:5432/straif")
		.await
		.unwrap();

	let app = Router::new()
		.nest("/user", routes::user::router().with_state(pool.clone()))
		.nest("/bhop", routes::bhop::router().with_state(pool.clone()))
		.nest(
			"/longjump",
			routes::longjump::router().with_state(pool.clone()),
		)
		.with_state(pool);

	let listener = tokio::net::TcpListener::bind("0.0.0.0:8000").await.unwrap();
	axum::serve(listener, app).await.unwrap();
}
