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
async fn register(
	State(pool): State<AppState>,
	Json(input): Json<User>,
) -> Result<String, ResponseError> {
	input.validate()?;

	let user = sqlx::query!(
		r#"SELECT * FROM "user" WHERE username = $1"#,
		input.username
	)
	.fetch_all(&pool)
	.await
	.map_err(|_| ResponseError::QueryError)?;

	if !user.is_empty() {
		return Err(ResponseError::QueryError);
	}

	let hashed = bcrypt::hash(input.password, bcrypt::DEFAULT_COST)
		.map_err(|_| ResponseError::QueryError)?;

	let query = sqlx::query!(
		r#"INSERT INTO "user" (username, password, admin) VALUES ($1, $2, FALSE)"#,
		input.username,
		hashed.as_bytes()
	)
	.execute(&pool)
	.await
	.map_err(|_| ResponseError::QueryError)?;

	println!("{:?}", user);

	Ok(input.username)
}
