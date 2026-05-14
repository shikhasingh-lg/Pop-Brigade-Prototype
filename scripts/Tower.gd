# Tower — the player's stronghold visual. Dome cap + stone body wrap around
# the cannon. Drawn entirely in _draw so adding details (banner, runes, etc.)
# doesn't need new art files.
#
# Placement: under HUDBottom at position (360, 0) — local origin sits at the
# HUDBottom top edge, world (360, 1390). The dome rises into the parapet band
# (world y=1310..1390) so it visually punches up through the wall like a
# turret. Body fills the upper portion of HUDBottom; cannon nests inside.

extends Node2D

const DOME_RADIUS := 80.0
const BODY_WIDTH := 160.0
const BODY_HEIGHT := 170.0   # spans full HUDBottom

# Stone palette — warm browns tuned to read as fortress masonry without
# competing with the bright bubble colors.
const BODY_FILL  := Color(0.30, 0.24, 0.17, 1.0)
const BODY_SHADE := Color(0.22, 0.18, 0.13, 1.0)
const BODY_LIGHT := Color(0.40, 0.32, 0.24, 1.0)
const DOME_FILL  := Color(0.34, 0.27, 0.20, 1.0)
const DOME_LIGHT := Color(0.52, 0.42, 0.32, 1.0)
const STONE_LINE := Color(0, 0, 0, 0.22)
const OUTLINE    := Color(0, 0, 0, 0.65)

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	_draw_dome()
	_draw_dome_highlight()
	_draw_finial()
	_draw_body()
	_draw_stone_pattern()
	_draw_battlement()

# Half-sphere dome — upper half-circle, base at local (±radius, 0).
func _draw_dome() -> void:
	var n := 36
	var pts := PackedVector2Array()
	for i in n + 1:
		var t: float = float(i) / float(n)
		var a: float = PI + t * PI   # PI..TAU traces the upper semicircle
		pts.append(Vector2(cos(a) * DOME_RADIUS, sin(a) * DOME_RADIUS))
	draw_colored_polygon(pts, DOME_FILL)
	# Outline arc for definition against the sky.
	draw_arc(Vector2.ZERO, DOME_RADIUS, PI, TAU, 36, OUTLINE, 2.5, true)

# Crescent of light on the upper-left of the dome — sells the rounded form.
func _draw_dome_highlight() -> void:
	draw_arc(Vector2.ZERO, DOME_RADIUS - 14.0,
		PI + 0.18, PI + 1.10, 18,
		Color(DOME_LIGHT.r, DOME_LIGHT.g, DOME_LIGHT.b, 0.55), 9.0, true)

# Brass-style finial at the dome apex.
func _draw_finial() -> void:
	draw_circle(Vector2(0, -DOME_RADIUS - 4), 5.5, Color(0.78, 0.65, 0.32, 1))
	draw_circle(Vector2(0, -DOME_RADIUS - 4), 2.5, Color(1, 0.92, 0.62, 1))
	# Tiny stem connecting finial to dome.
	draw_line(Vector2(0, -DOME_RADIUS + 1), Vector2(0, -DOME_RADIUS - 9),
		Color(0.78, 0.65, 0.32, 1), 2.0, true)

# Tower body — rectangle below the dome, with side shading for depth.
func _draw_body() -> void:
	var hw: float = BODY_WIDTH * 0.5
	draw_rect(Rect2(-hw, 0, BODY_WIDTH, BODY_HEIGHT), BODY_FILL, true)
	# Right-side shadow strip.
	draw_rect(Rect2(hw - 14.0, 0, 14.0, BODY_HEIGHT), BODY_SHADE, true)
	# Left-side highlight strip.
	draw_rect(Rect2(-hw, 0, 4.0, BODY_HEIGHT), BODY_LIGHT, true)
	# Outline.
	draw_rect(Rect2(-hw, 0, BODY_WIDTH, BODY_HEIGHT), OUTLINE, false, 2.0)

# Mortar lines for stone-block feel. Horizontal courses + offset vertical seams.
func _draw_stone_pattern() -> void:
	var hw: float = BODY_WIDTH * 0.5
	var courses := [30.0, 60.0, 90.0, 120.0, 150.0]
	for y in courses:
		draw_line(Vector2(-hw + 4.0, y), Vector2(hw - 4.0, y),
			STONE_LINE, 1.5, true)
	# Vertical seams alternate per course for an offset stone pattern.
	var seam_rows := [
		{"y": 15.0, "xs": [-50.0, 0.0, 50.0]},
		{"y": 45.0, "xs": [-30.0, 25.0]},
		{"y": 75.0, "xs": [-50.0, 0.0, 50.0]},
		{"y": 105.0, "xs": [-30.0, 25.0]},
		{"y": 135.0, "xs": [-50.0, 0.0, 50.0]},
	]
	for row in seam_rows:
		var ys: float = row.y
		for xv in row.xs:
			draw_line(Vector2(xv, ys), Vector2(xv, ys + 30.0),
				STONE_LINE, 1.5, true)

# Crenellation row across the top of the body, just below the dome's base.
func _draw_battlement() -> void:
	var hw: float = BODY_WIDTH * 0.5
	var notch_h: float = 9.0
	var notch_w: float = 14.0
	var gap: float = 12.0
	var x: float = -hw + 8.0
	while x + notch_w < hw - 8.0:
		draw_rect(Rect2(x, -notch_h * 0.5, notch_w, notch_h),
			BODY_LIGHT, true)
		draw_rect(Rect2(x, -notch_h * 0.5, notch_w, notch_h),
			OUTLINE, false, 1.0)
		x += notch_w + gap
