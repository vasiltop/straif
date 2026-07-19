class_name Palette extends RefCounted

const BACKGROUND := Color(0.0196, 0.0196, 0.0196)
const SURFACE := Color(0.0394, 0.0394, 0.0394)
const SURFACE_HIGH := Color(0.0773, 0.0773, 0.0773)

const TEXT := Color(0.9516, 0.9487, 0.9281)
const MUTED := Color(0.6007, 0.5976, 0.5761)
const SUBTLE := Color(0.4602, 0.4572, 0.4366)

const BORDER := Color(0.1599, 0.1599, 0.1599)
const BORDER_STRONG := Color(0.2729, 0.2709, 0.2568)

const PANEL_FILL := Color(0.0394, 0.0394, 0.0394, 0.82)
const PANEL_FILL_SOFT := Color(0.0394, 0.0394, 0.0394, 0.66)
const SCRIM := Color(0.0196, 0.0196, 0.0196, 0.55)

const HOVER_FILL := Color(0.9516, 0.9487, 0.9281, 0.06)
const PRESSED_FILL := Color(0.9516, 0.9487, 0.9281, 0.1)

static func with_alpha(color: Color, a: float) -> Color:
	return Color(color.r, color.g, color.b, a)
