use crate::AppState;
use axum::{
	extract::{Json, State},
	response::IntoResponse,
	routing::{get, post},
	Router,
};
use serde::Deserialize;
use serde::Serialize;
use sqlx::types::Uuid;

#[derive(Debug, thiserror::Error)]
pub enum Error {
	#[error("internal error")]
	InternalError,
	#[error("invalid submission")]
	InvalidSubmission,
}

#[derive(Serialize, Deserialize)]
struct LongjumpOutput {
	username: Option<String>,
	length: Option<i16>,
}

#[derive(Deserialize)]
struct LongjumpInput {
	user_id: Uuid,
	length: i16,
}

pub fn router() -> Router<AppState> {
	Router::new()
		.route("/publish", post(publish))
		.route("/leaderboard", get(leaderboard))
}

async fn publish(
	State(pool): State<AppState>,
	Json(jump): Json<LongjumpInput>,
) -> Result<(), crate::error::Error> {
	sqlx::query!(
		"INSERT INTO placement_longjump VALUES ($1, $2) ON CONFLICT (user_id) DO UPDATE SET length = $2 WHERE placement_longjump.length< $2 ",
		jump.user_id,
		jump.length
	)
	.execute(&pool)
	.await
	.map_err(|_| Error::InvalidSubmission)?;

	Ok(())
}

async fn leaderboard(
	State(pool): State<AppState>,
) -> Result<impl IntoResponse, crate::error::Error> {
	let runs = sqlx::query_as!(
		LongjumpOutput,
		"SELECT username, length FROM longjump_leaderboard LIMIT 10"
	)
	.fetch_all(&pool)
	.await
	.map_err(|_| Error::InternalError)?;

	Ok(Json(runs))
}
