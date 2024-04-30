use axum::{
	extract::{Json, State},
	http::StatusCode,
	routing::post,
	Router,
};
use serde::Deserialize;
use validator::Validate;

use crate::AppState;

#[derive(Deserialize, Validate)]
struct User {
	#[validate(length(min = 3, max = 32))]
	username: String,
	#[validate(length(min = 8, max = 128))]
	password: String,
}

#[derive(Debug, thiserror::Error)]
pub enum Error {
	#[error("error while hashing")]
	InvalidHashing,
	#[error("invalid information provided")]
	InvalidInformation,
	#[error("invalid utf8")]
	InvalidUtf8,
	#[error("username is taken")]
	UsernameTaken,
	#[error("internal server error")]
	InternalError,
}

impl Error {
	pub fn status(&self) -> StatusCode {
		match self {
			Self::InvalidHashing | Self::InternalError | Self::InvalidUtf8 => {
				StatusCode::INTERNAL_SERVER_ERROR
			}
			Self::InvalidInformation => StatusCode::UNAUTHORIZED,
			Self::UsernameTaken => StatusCode::CONFLICT,
		}
	}
}

pub fn router() -> Router<AppState> {
	Router::new()
		.route("/login", post(login))
		.route("/register", post(register))
}

async fn login(
	State(pool): State<AppState>,
	Json(input): Json<User>,
) -> Result<String, crate::error::Error> {
	input.validate()?;

	let user = sqlx::query!(
		r#"SELECT * FROM "user" WHERE username = $1"#,
		input.username
	)
	.fetch_one(&pool)
	.await
	.map_err(|_| Error::InvalidInformation)?;

	let valid = bcrypt::verify(
		input.password,
		std::str::from_utf8(&user.password).map_err(|_| Error::InvalidUtf8)?,
	)
	.map_err(|_| Error::InvalidHashing)?;

	if valid {
		Ok(user.id.to_string())
	} else {
		Err(Error::InvalidInformation.into())
	}
}

#[axum::debug_handler]
async fn register(
	State(pool): State<AppState>,
	Json(input): Json<User>,
) -> Result<String, crate::error::Error> {
	input.validate()?;

	let user = sqlx::query!(
		r#"SELECT * FROM "user" WHERE username = $1"#,
		input.username
	)
	.fetch_all(&pool)
	.await
	.map_err(|_| Error::InternalError)?;

	if !user.is_empty() {
		return Err(Error::UsernameTaken.into());
	}

	let hashed =
		bcrypt::hash(input.password, bcrypt::DEFAULT_COST).map_err(|_| Error::InvalidHashing)?;

	let user = sqlx::query!(
		r#"INSERT INTO "user" (username, password, admin) VALUES ($1, $2, FALSE) RETURNING id"#,
		input.username,
		hashed.as_bytes()
	)
	.fetch_one(&pool)
	.await
	.map_err(|_| Error::InternalError)?;

	Ok(user.id.to_string())
}
