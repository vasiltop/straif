mod routes;

use axum::Router;
use sqlx::{postgres::PgPoolOptions, Pool, Postgres};

type State = Pool<Postgres>;

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
