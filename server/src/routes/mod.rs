pub mod bhop;
pub mod longjump;

fn format_option_display<S, D>(value: &Option<D>, serializer: S) -> Result<S::Ok, S::Error>
where
	D: std::fmt::Display,
	S: serde::Serializer,
{
	if let Some(value) = value {
		serializer.serialize_str(&format!("{}", &value))
	} else {
		serializer.serialize_none()
	}
}
