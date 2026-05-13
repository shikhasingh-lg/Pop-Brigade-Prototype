# AimOverlay — draws the cannon's aim preview as a fading dotted polyline +
# ghost bubble at the predicted landing point. Replaces the old solid Line2D so
# the trajectory reads as a prediction (not a debug ray).
#
# Cannon sets:
#   polyline      — world-space points returned by _compute_aim_polyline()
#   bubble_color  — current_color from the cannon (BubbleColor enum)
#
# Lives as a child of MatchScene root (same parent the old aim_line used),
# so its local space == world space.

class_name AimOverlay
extends Node2D

const DOT_SPACING_PX: float = 28.0
const DOT_BASE_RADIUS: float = 5.0
const DOT_TIP_RADIUS: float = 3.0
const GHOST_RADIUS: float = 26.0  # bubble cutout sits in a ~52px box
const FADE_NEAR_ALPHA: float = 0.85
const FADE_FAR_ALPHA: float = 0.15
const ELBOW_RADIUS: float = 4.0   # bend marker at each ricochet
const DOT_OUTLINE: Color = Color(0, 0, 0, 0.55)

var polyline: PackedVector2Array = PackedVector2Array()
var bubble_color: int = 0

func set_polyline(pts: PackedVector2Array, color_idx: int) -> void:
	polyline = pts
	bubble_color = color_idx
	queue_redraw()

func clear() -> void:
	polyline = PackedVector2Array()
	queue_redraw()

func _draw() -> void:
	if polyline.size() < 2:
		return
	var col: Color = _bubble_color_rgb(bubble_color)
	# Pre-compute total path length so dot alpha can fade with distance.
	var total_len: float = 0.0
	for i in range(polyline.size() - 1):
		total_len += polyline[i].distance_to(polyline[i + 1])
	if total_len <= 0.0:
		return
	# Walk the polyline at fixed spacing; emit a fading dot at each step.
	var dist_along: float = DOT_SPACING_PX * 0.5  # offset first dot off the cannon body
	for seg in range(polyline.size() - 1):
		var a: Vector2 = polyline[seg]
		var b: Vector2 = polyline[seg + 1]
		var seg_len: float = a.distance_to(b)
		if seg_len <= 0.001: continue
		var seg_start_dist: float = _dist_to_seg_start(seg)
		# Place dots along this segment.
		while dist_along < seg_start_dist + seg_len:
			var t: float = (dist_along - seg_start_dist) / seg_len
			var p: Vector2 = a.lerp(b, t)
			var u: float = dist_along / total_len  # 0 at cannon, 1 at landing
			var alpha: float = lerp(FADE_NEAR_ALPHA, FADE_FAR_ALPHA, u)
			var r: float = lerp(DOT_BASE_RADIUS, DOT_TIP_RADIUS, u)
			draw_circle(p, r + 1.0, Color(DOT_OUTLINE.r, DOT_OUTLINE.g, DOT_OUTLINE.b, alpha * 0.7))
			draw_circle(p, r, Color(col.r, col.g, col.b, alpha))
			dist_along += DOT_SPACING_PX
		# Mark the ricochet elbow with a small chevron dot so the bounce reads.
		if seg < polyline.size() - 2:
			draw_circle(polyline[seg + 1], ELBOW_RADIUS, Color(col.r, col.g, col.b, 0.55))
	# Ghost bubble at the predicted landing point.
	var landing: Vector2 = polyline[polyline.size() - 1]
	_draw_ghost_bubble(landing, col)

func _dist_to_seg_start(seg_idx: int) -> float:
	var d: float = 0.0
	for i in range(seg_idx):
		d += polyline[i].distance_to(polyline[i + 1])
	return d

func _draw_ghost_bubble(world_pos: Vector2, col: Color) -> void:
	var tex: Texture2D = BubbleRoster.get_cutout(bubble_color)
	if tex != null:
		var half: float = GHOST_RADIUS * 1.7  # match BubbleVisual._VISUAL_OVERSIZE
		var rect := Rect2(world_pos - Vector2(half, half), Vector2(half * 2.0, half * 2.0))
		draw_texture_rect(tex, rect, false, Color(1, 1, 1, 0.45))
	else:
		# Greybox fallback — colored circle ring.
		draw_arc(world_pos, GHOST_RADIUS, 0.0, TAU, 24, Color(col.r, col.g, col.b, 0.55), 3.0, true)
		draw_circle(world_pos, GHOST_RADIUS - 2.0, Color(col.r, col.g, col.b, 0.18))

func _bubble_color_rgb(c: int) -> Color:
	if GameConfig.COLOR_HEX.has(c):
		return Color.html(GameConfig.COLOR_HEX[c])
	return Color.WHITE
