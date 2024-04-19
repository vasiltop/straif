use axum::{
	extract::{Json, State},
	routing::post,
	Router,
};
use serde::Deserialize;
use validator::Validate;

use crate::{AppState, ResponseError};

#[derive(Deserialize, Validate)]
struct User {
	#[validate(length(min = 3, max = 32))]
	username: String,
	#[validate(length(min = 8, max = 128))]
	password: String,
}

pub fn router() -> Router<AppState> {
	Router::new()
		.route("/login", post(login))
		.route("/register", post(register))
}

async fn login(State(pool): State<AppState>, Json(user): Json<User>) -> String {
	user.username
}

#[axum::debug_handler]
async fn register(Json(user): Json<User>) -> Result<String, ResponseError> {
	user.validate()?;
	Ok(user.username)
}
