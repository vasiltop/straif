use axum::{extract::Json, routing::post, Router};
use serde::Deserialize;

use crate::State;

#[derive(Deserialize)]
struct Test {
	foo: String,
}
pub fn router() -> Router<State> {
	Router::new().route("/", post(test))
}

async fn test(Json(payload): Json<Test>) -> String {
	payload.foo
}
