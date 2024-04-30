use axum::{body::Body, http::Response, http::StatusCode, response::IntoResponse};

#[derive(Debug, thiserror::Error)]
pub enum Error {
	#[error("validation error: {0}")]
	ValidationError(#[from] validator::ValidationErrors),
	#[error("auth error: {0}")]
	Auth(#[from] crate::routes::user::Error),
}

impl IntoResponse for Error {
	fn into_response(self) -> Response<Body> {
		let (status, error) = match self {
			Self::ValidationError(e) => (StatusCode::BAD_REQUEST, e.to_string().into_response()),
			Self::Auth(e) => (e.status(), e.to_string().into_response()),
		};

		(status, error).into_response()
	}
}
