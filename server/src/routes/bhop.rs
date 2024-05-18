use crate::steam::SteamAuth;
use crate::AppState;
use axum::{
	extract::{Json, State},
	http::HeaderMap,
	http::HeaderValue,
	http::StatusCode,
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
	#[error("password not provided")]
	InvalidPasswordHeader,
}

impl Error {
	pub fn status(&self) -> StatusCode {
		match self {
			Self::InvalidMapName | Self::InvalidSubmission | Self::InvalidPasswordHeader => {
				StatusCode::BAD_REQUEST
			}
		}
	}
}

#[derive(Serialize, Deserialize)]
struct RunOutput {
	username: Option<String>,
	run: Option<Vec<u8>>,
	time_ms: Option<i32>,
}

#[derive(Deserialize)]
struct RunInput {
	map_name: String,
	user_id: i64,
	username: String,
	auth_ticket: String,
	time: i32,
}

#[derive(Deserialize)]
struct Map {
	map_name: String,
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
	headers: HeaderMap,
	Json(run): Json<RunInput>,
) -> Result<(), crate::error::Error> {
	if Some(HeaderValue::from_static(dotenv!("PASSWORD"))) != headers.get("password").cloned() {
		return Err(Error::InvalidSubmission.into());
	}

	let steam_id: SteamAuth = reqwest::Client::default()
		.get("https://api.steampowered.com/ISteamUserAuth/AuthenticateUserTicket/v1/")
		.query(&[
			("key", dotenv!("STEAM_API_KEY")),
			("appid", "480"),
			("ticket", &run.auth_ticket),
			("identity", "munost"),
		])
		.send()
		.await?
		.json()
		.await?;

	let steam_id = steam_id.response.params.steamid.parse::<i64>().unwrap();

	if steam_id != run.user_id {
		return Err(Error::InvalidSubmission.into());
	}

	let map_id = sqlx::query_as!(MapId, "SELECT id FROM map WHERE name = $1", run.map_name)
		.fetch_one(&pool)
		.await
		.map_err(|_| Error::InvalidMapName)?;
	sqlx::query!(
		"INSERT INTO placement_bhop VALUES ($1, $2, $3, $4, $5) ON CONFLICT (user_id, map_id) DO UPDATE SET time_ms = $4 WHERE placement_bhop.time_ms > $4 ",
		run.user_id,
		map_id.id,
		//TODO: Make this Vector an actual viewable run
		Vec::new(),
		run.time,
		run.username
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
		"SELECT username, run, time_ms FROM bhop_leaderboard INNER JOIN map ON bhop_leaderboard.map_id = map.id WHERE map.name = $1 LIMIT 10",
		map.map_name
	)
	.fetch_all(&pool)
	.await.map_err(|_| Error::InvalidMapName)?;

	Ok(Json(runs))
}
