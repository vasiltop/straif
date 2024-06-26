use crate::run::Run;
use crate::steam::SteamAuth;
use crate::AppState;
use axum::{
	body::Bytes,
	extract::{Json, State},
	http::HeaderMap,
	http::HeaderValue,
	http::StatusCode,
	response::IntoResponse,
	routing::{get, post},
	Router,
};
use prost::Message;
use serde::Deserialize;
use serde::Serialize;
use sqlx::types::Uuid;

#[derive(Debug, thiserror::Error)]
pub enum Error {
	#[error("invalid map name")]
	InvalidMapName,
	#[error("invalid submission")]
	InvalidSubmission,
	#[error("Invalid Header")]
	InvalidHeader,
}

impl Error {
	pub fn status(&self) -> StatusCode {
		match self {
			Self::InvalidMapName | Self::InvalidSubmission | Self::InvalidHeader => {
				StatusCode::BAD_REQUEST
			}
		}
	}
}

pub fn router() -> Router<AppState> {
	Router::new()
		.route("/publish", post(publish))
		.route("/leaderboard", get(leaderboard))
		.route("/demo", post(demo))
}

struct MapId {
	id: Uuid,
}

async fn publish(
	State(pool): State<AppState>,
	headers: HeaderMap,
	run_bytes: Bytes,
) -> Result<(), crate::error::Error> {
	if Some(HeaderValue::from_static(dotenv!("PASSWORD"))) != headers.get("password").cloned() {
		return Err(Error::InvalidSubmission.into());
	}

	let run: Run = Message::decode(run_bytes.clone()).unwrap();

	if let Some(auth_ticket) = headers.get("auth_ticket") {
		let steam_id: SteamAuth = reqwest::Client::default()
			.get("https://api.steampowered.com/ISteamUserAuth/AuthenticateUserTicket/v1/")
			.query(&[
				("key", dotenv!("STEAM_API_KEY")),
				("appid", "480"),
				(
					"ticket",
					auth_ticket.to_str().map_err(|_| Error::InvalidHeader)?,
				),
				("identity", "munost"),
			])
			.send()
			.await?
			.json()
			.await?;

		let steam_id = steam_id.response.params.steamid.parse::<i64>().unwrap();

		if steam_id != run.steam_id {
			println!("invalid steam id");
			return Err(Error::InvalidSubmission.into());
		}

		let map_id = sqlx::query_as!(MapId, "SELECT id FROM map WHERE name = $1", run.map_name)
			.fetch_one(&pool)
			.await
			.map_err(|_| Error::InvalidMapName)?;
		sqlx::query!(
			"INSERT INTO placement_bhop VALUES ($1, $2, $3, $4, $5) ON CONFLICT (user_id, map_id) DO UPDATE SET time_ms = $4, run = $3, username = $5 WHERE placement_bhop.time_ms > $4 ",
			run.steam_id,
			map_id.id,
			run_bytes.as_ref(),
			run.value,
			run.username
		)
		.execute(&pool)
		.await?;
	}
	Ok(())
}

#[derive(Deserialize)]
struct Map {
	map_name: String,
}

#[derive(Serialize, Deserialize)]
struct RunOutput {
	username: Option<String>,
	#[serde(serialize_with = "super::format_option_display")]
	user_id: Option<i64>,
	time_ms: Option<i32>,
}

async fn leaderboard(
	State(pool): State<AppState>,
	Json(map): Json<Map>,
) -> Result<impl IntoResponse, crate::error::Error> {
	let runs = sqlx::query_as!(
		RunOutput,
		"SELECT username, time_ms, user_id FROM bhop_leaderboard INNER JOIN map ON bhop_leaderboard.map_id = map.id WHERE map.name = $1 LIMIT 10",
		map.map_name
	)
	.fetch_all(&pool)
	.await.map_err(|_| Error::InvalidMapName)?;

	Ok(Json(runs))
}

#[derive(Deserialize)]
struct DemoInput {
	map_name: String,
	steam_id: i64,
}

async fn demo(
	State(pool): State<AppState>,
	Json(input): Json<DemoInput>,
) -> Result<impl IntoResponse, crate::error::Error> {
	let runs = sqlx::query_scalar!(
		"SELECT run FROM bhop_leaderboard INNER JOIN map ON bhop_leaderboard.map_id = map.id WHERE map.name = $1 AND user_id = $2",
		input.map_name,
		input.steam_id
	)
	.fetch_all(&pool)
	.await.map_err(|_| Error::InvalidMapName)?;

	Ok(Json(runs))
}
