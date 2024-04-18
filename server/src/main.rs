use axum::{
	extract::Json,
	routing::{get, post},
	Router,
};
use postgres::{Client, NoTls};
use serde::Deserialize;

#[derive(Deserialize)]
struct Test {
	foo: String,
}

#[tokio::main]
async fn main() {
	let app = Router::new().route("/", post(test));

	let listener = tokio::net::TcpListener::bind("0.0.0.0:8000").await.unwrap();
	axum::serve(listener, app).await.unwrap();

	let mut client = Client::configure()
		.user("postgres")
		.password("root")
		.host("localhost")
		.dbname("straif")
		.connect(NoTls)
		.unwrap();
}

async fn test(Json(payload): Json<Test>) -> String {
	payload.foo
}
