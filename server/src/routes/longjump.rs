use axum::{extract::Json, routing::post, Router};
use serde::Deserialize;

use crate::AppState;

#[derive(Deserialize)]
struct Test {
	foo: String,
}
pub fn router() -> Router<AppState> {
	Router::new().route("/", post(test))
}

async fn test(Json(payload): Json<Test>) -> String {
	payload.foo
}
