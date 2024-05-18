use serde::Deserialize;

#[derive(Debug, Deserialize)]
pub struct SteamAuth {
	pub response: SteamAuthResponse,
}

#[derive(Debug, Deserialize)]
pub struct SteamAuthResponse {
	pub params: SteamAuthParams,
}

#[derive(Debug, Deserialize)]
pub struct SteamAuthParams {
	pub steamid: String,
}
