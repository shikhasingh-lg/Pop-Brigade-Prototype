# Cannon — aim, fire, queue, swap.
# Design spec §3.3.
# W1: bubble physics + try_fire wired.
# W2: touch-and-hold drag-to-aim with ricochet preview, release-to-fire.

class_name Cannon
extends Node2D

signal bubble_fired(bubble: Bubble, aim_angle_deg: float, time_to_fire_ms: int)

@export var aim_line: Line2D  # set in editor; created at runtime if null
@export var cluster_path: NodePath

var current_color: int = 0  # GameConfig.BubbleColor.RED
var on_deck_color: int = 1  # GameConfig.BubbleColor.BLUE
var color_palette: Array = []  # colors currently present in cluster (refreshed by MatchScene)
var _last_fire_ms: int = 0
var _aim_touch_start_ms: int = 0
var _shot_count_since_last_bomb: int = 0
var _next_bomb_at_shot: int = 0

# Run-level boon modifiers (§4.2)
var color_bias: int = -1            # -1 = none
var fire_rate_cap_sec: float = 0.5
var ricochet_count: int = 1

# Stage context (MatchScene sets this each stage; payload for telemetry)
var current_stage_num: int = 1

# Trajectory math constants
const BUBBLE_RADIUS := 32.0
const FIELD_WIDTH := 720.0
const TOP_BOUND_Y := 120.0
# On-deck swap UI rect (matches MatchScene.tscn HUDBottom geometry, in world px).
const QUEUE_SWAP_HIT_RECT := Rect2(370, 1440, 80, 70)

# Aim-ring UX (visible guide ring around the cannon)
# Player drags anywhere; aim angle = atan2(touch - cannon). The ring + knob give
# a stable visual reference so small finger jitter doesn't snap the angle.
const AIM_RING_RADIUS := 170.0       # ring is in cannon-local px (drawn via _draw)
const AIM_RING_WIDTH := 4.0
const AIM_RING_START_DEG := -170.0   # upper arc only — no aiming below cannon
const AIM_RING_END_DEG := -10.0
const AIM_DEAD_ZONE_PX := 55.0       # touch within this of cannon → ignore (kills near-cannon jitter)
const AIM_SMOOTH_ALPHA := 0.30       # per-event lerp toward raw touch angle (lower = less sensitive)
const RING_COLOR_IDLE := Color(1, 1, 1, 0.18)
const RING_COLOR_ACTIVE := Color(1, 0.95, 0.7, 0.55)
const KNOB_COLOR := Color(1, 0.9, 0.45, 0.95)
const KNOB_RADIUS := 18.0

# Aiming state
var _aiming: bool = false
var _aim_start_pos: Vector2 = Vector2.ZERO
var _aim_current_pos: Vector2 = Vector2.ZERO
var _current_aim_angle_deg: float = -90.0
var _aim_swap_candidate: bool = false  # press started inside the on-deck rect
# V8 §3.10: cannon disabled in Phase 2 (input ignored, dimmed).
var _input_enabled: bool = true

# Queue HUD ColorRects (set up in MatchScene.tscn — current is child of Cannon, on-deck is sibling).
@onready var _current_sprite: ColorRect = get_node_or_null("CurrentBubble")
@onready var _on_deck_sprite: ColorRect = get_node_or_null("../OnDeckBubble")

var _cluster_ref: Cluster = null

func _ready() -> void:
	fire_rate_cap_sec = GameConfig.fire_rate_cap_sec
	ricochet_count    = GameConfig.aim_ricochet_count
	_next_bomb_at_shot = GameConfig.get_color_bomb_next_cadence()
	color_palette = GameConfig.all_bubble_colors()
	current_color = color_palette[randi() % color_palette.size()]
	on_deck_color = color_palette[randi() % color_palette.size()]
	_refresh_queue_visuals()
	call_deferred("_resolve_cluster")
	_ensure_aim_line()
	queue_redraw()  # paint the idle aim ring

func _ensure_aim_line() -> void:
	if aim_line != null:
		aim_line.visible = false
		return
	aim_line = Line2D.new()
	aim_line.name = "AimLine"
	aim_line.width = 4.0
	aim_line.default_color = Color(1, 1, 1, 0.55)
	aim_line.visible = false
	call_deferred("_attach_aim_line")

func _attach_aim_line() -> void:
	var scene := get_tree().current_scene
	if scene != null and aim_line.get_parent() == null:
		scene.add_child(aim_line)

func _resolve_cluster() -> void:
	if cluster_path != NodePath(""):
		_cluster_ref = get_node_or_null(cluster_path)
	if _cluster_ref == null:
		var scene := get_tree().current_scene
		if scene != null:
			_cluster_ref = _find_cluster(scene)

func _find_cluster(n: Node) -> Cluster:
	if n is Cluster: return n
	for child in n.get_children():
		var found := _find_cluster(child)
		if found != null: return found
	return null

# ============================================================
# §3.3 — Input (W2: touch-and-hold drag-to-aim, release-to-fire)
# ============================================================
func set_input_enabled(enabled: bool) -> void:
	_input_enabled = enabled
	modulate = Color(1, 1, 1, 1) if enabled else Color(0.55, 0.55, 0.55, 0.7)
	if not enabled and _aiming:
		_aiming = false
		_aim_swap_candidate = false
		if aim_line != null:
			aim_line.visible = false
			aim_line.points = PackedVector2Array()
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not _input_enabled: return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index != MOUSE_BUTTON_LEFT: return
		if mb.pressed:
			_begin_aim(mb.position)
		else:
			_release_aim(mb.position)
	elif event is InputEventMouseMotion and _aiming:
		_update_aim(event.position)

func _begin_aim(touch_pos: Vector2) -> void:
	_aim_touch_start_ms = Time.get_ticks_msec()
	_aim_start_pos = touch_pos
	_aim_current_pos = touch_pos
	# Press inside the on-deck rect → candidate swap; commit on release if no drag-out.
	_aim_swap_candidate = QUEUE_SWAP_HIT_RECT.has_point(touch_pos)
	if _aim_swap_candidate:
		return
	_aiming = true
	queue_redraw()
	_update_aim(touch_pos)

func _update_aim(touch_pos: Vector2) -> void:
	if not _aiming: return
	_aim_current_pos = touch_pos
	var origin := global_position
	var to_touch := touch_pos - origin
	# §3.3: only upward aims valid. Dead zone prevents finger-jitter near the
	# cannon from snapping the angle wildly. The previous aim angle is kept.
	if to_touch.y >= -8.0 or to_touch.length() < AIM_DEAD_ZONE_PX:
		if aim_line != null:
			aim_line.visible = false
		queue_redraw()
		return
	# Smooth toward raw target angle so each finger event nudges aim instead
	# of teleporting it — gives a much steadier feel on touch screens.
	var target_rad := to_touch.angle()
	var current_rad := deg_to_rad(_current_aim_angle_deg)
	var smoothed_rad := lerp_angle(current_rad, target_rad, AIM_SMOOTH_ALPHA)
	_current_aim_angle_deg = rad_to_deg(smoothed_rad)
	queue_redraw()
	if aim_line == null: return
	aim_line.visible = true
	aim_line.points = _compute_aim_polyline(_current_aim_angle_deg, ricochet_count)

func _release_aim(touch_pos: Vector2) -> void:
	if _aim_swap_candidate:
		_aim_swap_candidate = false
		# Release inside swap rect → swap (no drag commitment).
		if QUEUE_SWAP_HIT_RECT.has_point(touch_pos):
			swap_queue()
		return
	if not _aiming: return
	_aiming = false
	if aim_line != null:
		aim_line.visible = false
		aim_line.points = PackedVector2Array()
	var origin := global_position
	var to_release := touch_pos - origin
	# Cancel if released below cannon OR inside dead zone (treated as accidental tap).
	if to_release.y >= -8.0 or to_release.length() < AIM_DEAD_ZONE_PX:
		queue_redraw()
		return
	# Fire at the SMOOTHED aim angle (matches what the knob showed the player),
	# not the raw release vector.
	try_fire(_current_aim_angle_deg, false, current_stage_num)
	queue_redraw()

# Draw the always-on aim ring + active knob in cannon-local space.
# Brighter ring + visible knob while aiming; dim guide ring when idle.
func _draw() -> void:
	var ring_col: Color = RING_COLOR_ACTIVE if _aiming else RING_COLOR_IDLE
	draw_arc(Vector2.ZERO, AIM_RING_RADIUS,
		deg_to_rad(AIM_RING_START_DEG), deg_to_rad(AIM_RING_END_DEG),
		48, ring_col, AIM_RING_WIDTH, true)
	if _aiming:
		var knob_pos: Vector2 = Vector2.from_angle(deg_to_rad(_current_aim_angle_deg)) * AIM_RING_RADIUS
		draw_circle(knob_pos, KNOB_RADIUS, KNOB_COLOR)

# ============================================================
# §3.3 — Aim trajectory polyline (world-space; ricochets off side walls)
# ============================================================
func _compute_aim_polyline(angle_deg: float, max_ricochets: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var pos := global_position
	pts.append(pos)
	var dir := Vector2.from_angle(deg_to_rad(angle_deg))
	var remaining := max_ricochets
	var safety := 8
	while safety > 0:
		safety -= 1
		var t_left: float = INF
		var t_right: float = INF
		var t_top: float = INF
		if dir.x < 0: t_left  = (BUBBLE_RADIUS - pos.x) / dir.x
		if dir.x > 0: t_right = (FIELD_WIDTH - BUBBLE_RADIUS - pos.x) / dir.x
		if dir.y < 0: t_top   = (TOP_BOUND_Y - pos.y) / dir.y
		var t: float = min(t_left, min(t_right, t_top))
		if t == INF or t <= 0:
			break
		var hit: Vector2 = pos + dir * t
		pts.append(hit)
		if is_equal_approx(t, t_top):
			break
		if remaining <= 0:
			break  # no more ricochets allowed in preview
		dir.x = -dir.x
		remaining -= 1
		pos = hit
	return pts

# ============================================================
# §3.3 — Fire
# ============================================================
func try_fire(aim_angle_deg: float, queue_swap_used: bool, stage_num: int) -> void:
	var now_ms := Time.get_ticks_msec()
	if (now_ms - _last_fire_ms) / 1000.0 < fire_rate_cap_sec:
		return  # rate-capped
	_last_fire_ms = now_ms
	if _cluster_ref == null:
		_resolve_cluster()
		if _cluster_ref == null:
			push_warning("Cannon.try_fire: no Cluster found in scene")
			return
	var b: Bubble = _cluster_ref.bubble_scene.instantiate()
	b.color = current_color
	b.is_special_color_bomb = _is_color_bomb()
	get_tree().current_scene.add_child(b)
	var vel := Vector2.from_angle(deg_to_rad(aim_angle_deg)) * GameConfig.bubble_speed_px_per_sec
	b.launch(global_position, vel, _cluster_ref)
	Telemetry.log_bubble_fired(stage_num, current_color, queue_swap_used,
		aim_angle_deg, now_ms - _aim_touch_start_ms)
	emit_signal("bubble_fired", b, aim_angle_deg, now_ms - _aim_touch_start_ms)
	_advance_queue()
	_shot_count_since_last_bomb += 1

func _advance_queue() -> void:
	current_color = on_deck_color
	on_deck_color = _draw_from_palette()
	# §3.3: if the just-promoted current was the last of its color (popped by this shot),
	# re-roll it against the now-current palette.
	if _cluster_ref != null:
		var active: Array = _cluster_ref.get_active_colors()
		if not active.is_empty():
			if not (current_color in active):
				current_color = active[randi() % active.size()]
			if not (on_deck_color in active):
				on_deck_color = active[randi() % active.size()]
	_refresh_queue_visuals()

func swap_queue() -> void:
	var tmp := current_color
	current_color = on_deck_color
	on_deck_color = tmp
	_refresh_queue_visuals()

func _draw_from_palette() -> int:
	# §3.3 — only colors still in cluster are drawn.
	if _cluster_ref != null:
		var active: Array = _cluster_ref.get_active_colors()
		if not active.is_empty():
			color_palette = active
	if color_palette.is_empty():
		return GameConfig.BubbleColor.RED
	# §4.2 boon: color_bias gives +30% weight to that color when present in palette.
	if color_bias >= 0 and color_bias in color_palette:
		var weights: Array[float] = []
		var total := 0.0
		for c in color_palette:
			var w: float = 1.3 if c == color_bias else 1.0
			weights.append(w)
			total += w
		var roll := randf() * total
		var acc := 0.0
		for i in range(color_palette.size()):
			acc += weights[i]
			if roll <= acc:
				return color_palette[i]
		return color_palette[color_palette.size() - 1]
	return color_palette[randi() % color_palette.size()]

func _is_color_bomb() -> bool:
	if _shot_count_since_last_bomb >= _next_bomb_at_shot:
		_shot_count_since_last_bomb = 0
		_next_bomb_at_shot = GameConfig.get_color_bomb_next_cadence()
		return true
	return false

func _refresh_queue_visuals() -> void:
	if _current_sprite != null:
		_current_sprite.color = _color_for_enum(current_color)
	if _on_deck_sprite != null:
		_on_deck_sprite.color = _color_for_enum(on_deck_color)

func _color_for_enum(c: int) -> Color:
	if GameConfig.COLOR_HEX.has(c):
		return Color.html(GameConfig.COLOR_HEX[c])
	return Color.WHITE

# ============================================================
# Boon application — called by MatchScene after boon pick (§4.2)
# ============================================================
func apply_boon(boon_id: String) -> void:
	match boon_id:
		"red_bias":       color_bias = GameConfig.BubbleColor.RED
		"blue_bias":      color_bias = GameConfig.BubbleColor.BLUE
		"yellow_bias":    color_bias = GameConfig.BubbleColor.YELLOW
		"faster_fire":    fire_rate_cap_sec = 0.4
		"ricochet_plus":  ricochet_count = 2
		"extra_special":  pass  # handled by special-bubble timer elsewhere
		_:                pass  # damage boons handled by Lane / Hero
