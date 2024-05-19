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

#[derive(Debug, thiserror::Error)]
pub enum Error {
	#[error("internal error")]
	InternalError,
	#[error("invalid submission")]
	InvalidSubmission,
}

impl Error {
	pub fn status(&self) -> StatusCode {
		match self {
			Self::InvalidSubmission => StatusCode::BAD_REQUEST,
			Self::InternalError => StatusCode::INTERNAL_SERVER_ERROR,
		}
	}
}

pub fn router() -> Router<AppState> {
	Router::new()
		.route("/publish", post(publish))
		.route("/leaderboard", get(leaderboard))
}

async fn publish(
	State(pool): State<AppState>,
	headers: HeaderMap,
	jump_bytes: Bytes,
) -> Result<(), crate::error::Error> {
	if Some(HeaderValue::from_static(dotenv!("PASSWORD"))) != headers.get("password").cloned() {
		return Err(crate::error::Error::Longjump(Error::InvalidSubmission));
	}

	if let Some(auth_ticket) = headers.get("auth_ticket") {
		let jump: Run = Message::decode(jump_bytes.clone()).unwrap();
		let steam_id: SteamAuth = reqwest::Client::default()
			.get("https://api.steampowered.com/ISteamUserAuth/AuthenticateUserTicket/v1/")
			.query(&[
				("key", dotenv!("STEAM_API_KEY")),
				("appid", "480"),
				(
					"ticket",
					auth_ticket.to_str().map_err(|_| Error::InvalidSubmission)?,
				),
				("identity", "munost"),
			])
			.send()
			.await?
			.json()
			.await?;

		let steam_id = steam_id.response.params.steamid.parse::<i64>().unwrap();

		if steam_id != jump.steam_id {
			return Err(Error::InvalidSubmission.into());
		}
		sqlx::query!(
		"INSERT INTO placement_longjump VALUES ($1, $2, $3, $4) ON CONFLICT (user_id) DO UPDATE SET length = $2, jump = $4 WHERE placement_longjump.length< $2 ",
		jump.steam_id,
		i16::try_from(jump.value).map_err(|_| Error::InvalidSubmission)?,
		jump.username,
		jump_bytes.as_ref()
	)
	.execute(&pool)
	.await
	.map_err(|_| Error::InvalidSubmission)?;
	}
	Ok(())
}

async fn leaderboard(
	State(pool): State<AppState>,
) -> Result<impl IntoResponse, crate::error::Error> {
	let runs = sqlx::query_scalar!("SELECT jump FROM longjump_leaderboard LIMIT 10")
		.fetch_all(&pool)
		.await
		.map_err(|_| Error::InternalError)?;

	Ok(Json(runs))
}
