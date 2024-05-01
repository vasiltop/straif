use axum::{body::Body, http::Response, http::StatusCode, response::IntoResponse};

#[derive(Debug, thiserror::Error)]
pub enum Error {
	#[error("validation error: {0}")]
	ValidationError(#[from] validator::ValidationErrors),
	#[error("auth error: {0}")]
	Auth(#[from] crate::routes::user::Error),
	#[error("bhop error: {0}")]
	Bhop(#[from] crate::routes::bhop::Error),
	#[error("longjump error: {0}")]
	Longjump(#[from] crate::routes::longjump::Error),
}

impl IntoResponse for Error {
	fn into_response(self) -> Response<Body> {
		let (status, error) = match self {
			Self::ValidationError(e) => (StatusCode::BAD_REQUEST, e.to_string()),
			Self::Auth(e) => (e.status(), e.to_string()),
			Self::Bhop(e) => (StatusCode::REQUEST_TIMEOUT, e.to_string()),
			Self::Longjump(e) => (StatusCode::REQUEST_TIMEOUT, e.to_string()),
		};

		(status, error).into_response()
	}
}
