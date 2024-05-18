use axum::{body::Body, http::Response, http::StatusCode, response::IntoResponse};

#[derive(Debug, thiserror::Error)]
pub enum Error {
	#[error("validation error: {0}")]
	ValidationError(#[from] validator::ValidationErrors),
	#[error("bhop error: {0}")]
	Bhop(#[from] crate::routes::bhop::Error),
	#[error("longjump error: {0}")]
	Longjump(#[from] crate::routes::longjump::Error),
	#[error("invalid steam request")]
	SteamRequest(#[from] reqwest::Error),
	#[error("sql error")]
	SqlError(#[from] sqlx::Error),
}

impl IntoResponse for Error {
	fn into_response(self) -> Response<Body> {
		let (status, error) = match self {
			Self::ValidationError(e) => (StatusCode::BAD_REQUEST, e.to_string()),
			Self::Bhop(e) => (e.status(), e.to_string()),
			Self::Longjump(e) => (e.status(), e.to_string()),
			Self::SteamRequest(_) => (StatusCode::INTERNAL_SERVER_ERROR, "lol".into()),
			Self::SqlError(e) => (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()),
		};

		(status, error).into_response()
	}
}
