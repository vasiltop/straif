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
	#[error("invalid map name")]
	InvalidMapName,
	#[error("invalid submission")]
	InvalidSubmission,
}

#[derive(Serialize, Deserialize)]
struct RunOutput {
	name: String,
	run: Option<Vec<u8>>,
	time_ms: Option<i32>,
}

#[derive(Deserialize)]
struct RunInput {
	name: String,
	id: Uuid,
	run: Vec<u8>,
}

#[derive(Deserialize)]
struct Map {
	name: String,
}

struct MapId {
	id: Uuid,
}

pub fn router() -> Router<AppState> {
	Router::new()
		.route("/publish", post(publish))
		.route("/leaderboard", get(leaderboard))
}

async fn publish(
	State(pool): State<AppState>,
	Json(run): Json<RunInput>,
) -> Result<(), crate::error::Error> {
	let map_id = sqlx::query_as!(MapId, "SELECT id FROM map WHERE name = $1", run.name)
		.fetch_one(&pool)
		.await
		.map_err(|_| Error::InvalidMapName)?;

	sqlx::query!(
		"INSERT INTO placement_bhop VALUES ($1, $2, $3, $4) ON CONFLICT (user_id, map_id) DO UPDATE SET time_ms = $4 WHERE placement_bhop.time_ms > $4 ",
		run.id,
		map_id.id,
		run.run,
		9
		//TODO: Make the run parser to calculate time
	)
	.execute(&pool)
	.await
	.map_err(|_| Error::InvalidSubmission)?;

	Ok(())
}

async fn leaderboard(
	State(pool): State<AppState>,
	Json(map): Json<Map>,
) -> Result<impl IntoResponse, crate::error::Error> {
	let runs = sqlx::query_as!(
		RunOutput,
		"SELECT name, run, time_ms FROM bhop_leaderboard INNER JOIN map ON bhop_leaderboard.map_id = map.id WHERE map.name = $1 LIMIT 10",
		map.name
	)
	.fetch_all(&pool)
	.await.map_err(|_| Error::InvalidMapName)?;

	Ok(Json(runs))
}
