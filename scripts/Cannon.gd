# Cannon — aim, fire, queue, swap.
# Design spec §3.3.
# W1: bubble physics + try_fire wired.
# W2: touch-and-hold drag-to-aim with ricochet preview, release-to-fire.

class_name Cannon
extends Node2D

signal bubble_fired(bubble: Bubble, aim_angle_deg: float, time_to_fire_ms: int)

# Dotted-trajectory overlay (replaces the old solid Line2D). Drawn in
# world space by AimOverlay; created at runtime and parented to MatchScene root.
# Preloaded by path (not via class_name) so first-run before the editor has
# scanned the class registry still works.
const AIM_OVERLAY_SCRIPT := preload("res://scripts/AimOverlay.gd")
var aim_overlay: Node2D = null
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
# New boon flags (B-pass). Most are simple multiplier overrides; the deeply
# behavior-changing ones (Twin Cannons, Overcharge, etc.) are flagged here so
# they show up in telemetry/inspector even when the gameplay hook is a stub.
var boon_color_lock: bool = false       # only fire colors matching cluster majority
var boon_overcharge: bool = false       # every 5th shot = giant (stub)
var boon_twin_cannons: bool = false     # 2 bubbles/shot (stub — needs trajectory math)
var boon_wide_barrel: bool = false      # +20% hit zone (stub — physics)
var _overcharge_counter: int = 0

# Stage context (MatchScene sets this each stage; payload for telemetry)
var current_stage_num: int = 1

# Trajectory math constants
const FIELD_WIDTH := 720.0
const TOP_BOUND_Y := 120.0
const TOP_CENTER_Y := TOP_BOUND_Y + Bubble.BUBBLE_RADIUS
# On-deck swap UI rect (matches MatchScene.tscn HUDBottom geometry, in world px).
const QUEUE_SWAP_HIT_RECT := Rect2(550, 1440, 90, 70)

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
# Transient block while another input modal is active (e.g. hero drag in v2 §3.2).
# Suppresses aim input WITHOUT dimming the cannon — kept separate from the
# phase-level disable so brief drags don't flash the cannon dim/undim.
var _aim_blocked: bool = false

# Queue HUD bubble visuals (BubbleVisual.gd on a Node2D — circle preview).
# Current is a child of Cannon; on-deck is a sibling in HUDBottom.
@onready var _current_sprite: Node = get_node_or_null("CurrentBubble")
@onready var _on_deck_sprite: Node = get_node_or_null("../OnDeckBubble")

var _cluster_ref: Cluster = null

func _ready() -> void:
	fire_rate_cap_sec = GameConfig.fire_rate_cap_sec
	ricochet_count    = GameConfig.aim_ricochet_count
	_next_bomb_at_shot = GameConfig.get_color_bomb_next_cadence()
	color_palette = GameConfig.all_bubble_colors()
	current_color = color_palette[randi() % color_palette.size()]
	on_deck_color = color_palette[randi() % color_palette.size()]
	_refresh_queue_visuals()
	_refresh_bomb_state()
	call_deferred("_resolve_cluster")
	_ensure_aim_overlay()
	queue_redraw()  # paint the idle aim ring

func _ensure_aim_overlay() -> void:
	if aim_overlay != null:
		aim_overlay.visible = false
		return
	aim_overlay = Node2D.new()
	aim_overlay.set_script(AIM_OVERLAY_SCRIPT)
	aim_overlay.name = "AimOverlay"
	aim_overlay.visible = false
	aim_overlay.z_index = 25
	call_deferred("_attach_aim_overlay")

func _attach_aim_overlay() -> void:
	var root := _match_root()
	if root != null and aim_overlay.get_parent() == null:
		root.add_child(aim_overlay)

# Resolve the MatchScene root (cannon → HUDBottom → MatchScene). Used as the
# parent for the aim line and in-flight bubbles so they render above the match
# background. Falls back to current_scene if the cannon was reparented.
func _match_root() -> Node:
	var p := get_parent()
	if p != null and p.get_parent() != null:
		return p.get_parent()
	return get_tree().current_scene

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
		_hide_aim_overlay()
	queue_redraw()

func set_aim_blocked(blocked: bool) -> void:
	_aim_blocked = blocked
	if blocked and _aiming:
		_aiming = false
		_aim_swap_candidate = false
		_hide_aim_overlay()
		queue_redraw()

func _hide_aim_overlay() -> void:
	if aim_overlay != null:
		aim_overlay.visible = false
		aim_overlay.clear()

func _input(event: InputEvent) -> void:
	if not _input_enabled or _aim_blocked: return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index != MOUSE_BUTTON_LEFT: return
		if _touch_hits_merge_ui(mb.position):
			_aiming = false
			_aim_swap_candidate = false
			_hide_aim_overlay()
			queue_redraw()
			return
		if mb.pressed:
			_begin_aim(mb.position)
		else:
			_release_aim(mb.position)
	elif event is InputEventMouseMotion and _aiming:
		_update_aim(event.position)

func _touch_hits_merge_ui(world_pos: Vector2) -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return false
	var lane := _find_lane(scene)
	return lane != null and lane.is_merge_option_at_world_pos(world_pos)

func _find_lane(n: Node) -> Lane:
	if n is Lane:
		return n
	for child in n.get_children():
		var found := _find_lane(child)
		if found != null:
			return found
	return null

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
		_hide_aim_overlay()
		queue_redraw()
		return
	# Smooth toward raw target angle so each finger event nudges aim instead
	# of teleporting it — gives a much steadier feel on touch screens.
	var target_rad := to_touch.angle()
	var current_rad := deg_to_rad(_current_aim_angle_deg)
	var smoothed_rad := lerp_angle(current_rad, target_rad, AIM_SMOOTH_ALPHA)
	_current_aim_angle_deg = rad_to_deg(smoothed_rad)
	queue_redraw()
	if aim_overlay == null: return
	aim_overlay.visible = true
	var prediction := _compute_aim_prediction(_current_aim_angle_deg, ricochet_count)
	aim_overlay.set_polyline(prediction["polyline"], current_color, prediction["landing"])

func _release_aim(touch_pos: Vector2) -> void:
	if _aim_swap_candidate:
		_aim_swap_candidate = false
		# Release inside swap rect → swap (no drag commitment).
		if QUEUE_SWAP_HIT_RECT.has_point(touch_pos):
			swap_queue()
		return
	if not _aiming: return
	_aiming = false
	_hide_aim_overlay()
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

# Draw the always-on aim ring + active knob + rotating muzzle wedge.
# Brighter ring + visible knob while aiming; dim guide ring when idle.
# The muzzle is a small triangle attached to the cannon edge that always points
# at the current aim angle — sells "the cannon points where you aim."
func _draw() -> void:
	var ring_col: Color = RING_COLOR_ACTIVE if _aiming else RING_COLOR_IDLE
	draw_arc(Vector2.ZERO, AIM_RING_RADIUS,
		deg_to_rad(AIM_RING_START_DEG), deg_to_rad(AIM_RING_END_DEG),
		48, ring_col, AIM_RING_WIDTH, true)
	# Muzzle wedge — always on (idle or aiming), defaults to straight up.
	_draw_muzzle(_current_aim_angle_deg)
	if _aiming:
		var knob_pos: Vector2 = Vector2.from_angle(deg_to_rad(_current_aim_angle_deg)) * AIM_RING_RADIUS
		draw_circle(knob_pos, KNOB_RADIUS, KNOB_COLOR)

const MUZZLE_BASE_DIST := 38.0   # touches cannon body edge (CannonBody is 80x80, half=40)
const MUZZLE_TIP_DIST  := 64.0   # 26px out from edge
const MUZZLE_HALF_WIDTH := 14.0
const MUZZLE_FILL := Color(0.92, 0.78, 0.40, 1.0)
const MUZZLE_OUTLINE := Color(0.18, 0.14, 0.06, 0.95)

func _draw_muzzle(angle_deg: float) -> void:
	var dir: Vector2 = Vector2.from_angle(deg_to_rad(angle_deg))
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var base: Vector2 = dir * MUZZLE_BASE_DIST
	var tip: Vector2 = dir * MUZZLE_TIP_DIST
	var poly := PackedVector2Array([
		tip,
		base + perp * MUZZLE_HALF_WIDTH,
		base - perp * MUZZLE_HALF_WIDTH,
	])
	draw_colored_polygon(poly, MUZZLE_FILL)
	# Outline so the muzzle reads against bright cluster colors.
	draw_polyline(PackedVector2Array([poly[0], poly[1], poly[2], poly[0]]),
		MUZZLE_OUTLINE, 2.0, true)

# ============================================================
# §3.3 — Aim trajectory prediction (world-space; ricochets off side walls,
# terminates at first cluster contact or top bound)
# ============================================================
# The preview must use the SAME collision model as the real ball, otherwise the
# trajectory shows a landing point the ball can never reach. The real ball
# (Bubble._on_area_entered) attaches at the first cluster Area2D overlap, where
# overlap = centers within (Bubble.ATTACH_RADIUS + Bubble.ATTACH_RADIUS). We
# mirror that here: a circle-vs-circle sweep against every attached cluster
# bubble, taking the nearest of wall hit / top hit / cluster hit each segment.
func _compute_aim_prediction(angle_deg: float, max_ricochets: int) -> Dictionary:
	if _cluster_ref == null:
		_resolve_cluster()
	var pts := PackedVector2Array()
	var pos := global_position
	pts.append(pos)
	var dir := Vector2.from_angle(deg_to_rad(angle_deg))
	var remaining := max_ricochets
	var safety := 8
	var landing: Variant = null
	while safety > 0:
		safety -= 1
		var t_left: float = INF
		var t_right: float = INF
		var t_top: float = INF
		if dir.x < 0: t_left  = (Bubble.BUBBLE_RADIUS - pos.x) / dir.x
		if dir.x > 0: t_right = (FIELD_WIDTH - Bubble.BUBBLE_RADIUS - pos.x) / dir.x
		if dir.y < 0: t_top   = (TOP_CENTER_Y - pos.y) / dir.y
		var t_wall: float = min(t_left, t_right)
		var cluster_hit := _segment_first_cluster_hit(pos, dir)
		var t_cluster: float = cluster_hit["t"]
		var t: float = min(t_wall, min(t_top, t_cluster))
		if t == INF or t <= 0:
			break
		var hit: Vector2 = pos + dir * t
		pts.append(hit)
		# Cluster contact or top bound = terminal (no further ricochet).
		if t == t_cluster:
			if _cluster_ref != null:
				landing = _cluster_ref.predict_attach_world_position(hit, cluster_hit["bubble"])
				pts[pts.size() - 1] = landing
			break
		if t == t_top:
			if _cluster_ref != null:
				landing = _cluster_ref.predict_attach_world_position(hit)
				pts[pts.size() - 1] = landing
			break
		if remaining <= 0:
			break  # no more ricochets allowed in preview
		dir.x = -dir.x
		remaining -= 1
		pos = hit
	return { "polyline": pts, "landing": landing }

func _compute_aim_polyline(angle_deg: float, max_ricochets: int) -> PackedVector2Array:
	return _compute_aim_prediction(angle_deg, max_ricochets)["polyline"]

# Distance along (pos, dir) at which a ball of Bubble.ATTACH_RADIUS first
# overlaps a stationary cluster bubble. Returns { t, bubble }; t = INF when
# no bubble is hit.
# Solves |(pos + dir*t) - C|² = R² where R = 2 * ATTACH_RADIUS (sum of radii).
func _segment_first_cluster_hit(pos: Vector2, dir: Vector2) -> Dictionary:
	if _cluster_ref == null:
		return { "t": INF, "bubble": null }
	var sum_r: float = Bubble.ATTACH_RADIUS * 2.0
	var sum_r_sq: float = sum_r * sum_r
	var best_t: float = INF
	var best_bubble: Bubble = null
	for child in _cluster_ref.get_children():
		if not (child is Bubble):
			continue
		var b: Bubble = child
		if b.in_flight:
			continue
		var d: Vector2 = pos - b.global_position
		# Quadratic at² + bt + c = 0 with a = dir·dir (= 1), b = 2 d·dir, c = d·d - R²
		var b_coef: float = 2.0 * d.dot(dir)
		var c_coef: float = d.dot(d) - sum_r_sq
		var disc: float = b_coef * b_coef - 4.0 * c_coef
		if disc < 0.0:
			continue
		var sqrt_disc: float = sqrt(disc)
		# Smaller positive root is the entry point.
		var t0: float = (-b_coef - sqrt_disc) * 0.5
		var t1: float = (-b_coef + sqrt_disc) * 0.5
		var t_hit: float = t0 if t0 > 0.001 else t1
		if t_hit > 0.001 and t_hit < best_t:
			best_t = t_hit
			best_bubble = b
	return { "t": best_t, "bubble": best_bubble }

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
	_match_root().add_child(b)
	var vel := Vector2.from_angle(deg_to_rad(aim_angle_deg)) * GameConfig.bubble_speed_px_per_sec
	b.launch(global_position, vel, _cluster_ref)
	Telemetry.log_bubble_fired(stage_num, current_color, queue_swap_used,
		aim_angle_deg, now_ms - _aim_touch_start_ms)
	emit_signal("bubble_fired", b, aim_angle_deg, now_ms - _aim_touch_start_ms)
	_advance_queue()
	_shot_count_since_last_bomb += 1
	_refresh_bomb_state()

func _advance_queue() -> void:
	current_color = on_deck_color
	on_deck_color = _draw_from_palette()
	_refresh_queue_visuals()
	_refresh_bomb_state()

# Color-bomb pulse on the loaded bubble. True when the NEXT fire will produce
# a bomb (matches _is_color_bomb's gate but read-only). Driven by _process.
var _current_is_bomb_loaded: bool = false
var _bomb_pulse_t: float = 0.0

func _refresh_bomb_state() -> void:
	_current_is_bomb_loaded = _shot_count_since_last_bomb >= _next_bomb_at_shot
	if not _current_is_bomb_loaded and _current_sprite != null:
		_current_sprite.modulate = Color(1, 1, 1, 1)

func _process(delta: float) -> void:
	if not _current_is_bomb_loaded or _current_sprite == null: return
	_bomb_pulse_t += delta
	# Rainbow hue cycle + brightness pulse — reads as "special" without needing
	# new art. 0.6 cycles/sec hue rotation, 2Hz brightness pulse.
	var hue: float = fmod(_bomb_pulse_t * 0.6, 1.0)
	var rainbow: Color = Color.from_hsv(hue, 0.85, 1.0)
	var pulse: float = 1.0 + sin(_bomb_pulse_t * TAU * 2.0) * 0.25
	_current_sprite.modulate = Color(rainbow.r * pulse, rainbow.g * pulse, rainbow.b * pulse, 1.0)

# Called by MatchScene after Cluster.bubble_resolved — the in-flight shot has
# now attached/popped, so the cluster's active-color set reflects post-shot
# state. Re-roll queue slots that point at colors no longer present, otherwise
# the player gets shots that can never match anything in the cluster.
func refresh_queue_against_cluster() -> void:
	if _cluster_ref == null:
		_resolve_cluster()
		if _cluster_ref == null:
			return
	var active: Array = _cluster_ref.get_active_colors()
	if active.is_empty():
		return
	color_palette = active
	var changed := false
	if not (current_color in active):
		current_color = active[randi() % active.size()]
		changed = true
	if not (on_deck_color in active):
		on_deck_color = active[randi() % active.size()]
		changed = true
	if changed:
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
	# §4.2 boon: Color Lock — always serve the cluster's most-common color so the
	# player never gets a "wrong" bubble. Falls back to weighted/random when the
	# cluster ref is missing.
	if boon_color_lock and _cluster_ref != null and _cluster_ref.has_method("get_active_colors"):
		var counts: Dictionary = {}
		if _cluster_ref.has_method("get_color_counts"):
			counts = _cluster_ref.get_color_counts()
		if not counts.is_empty():
			var best_color: int = color_palette[0]
			var best_n: int = -1
			for c in counts.keys():
				if int(counts[c]) > best_n:
					best_n = int(counts[c])
					best_color = c
			return best_color
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
		_current_sprite.set_bubble_color(current_color)
	if _on_deck_sprite != null:
		_on_deck_sprite.set_bubble_color(on_deck_color)

func _color_for_enum(c: int) -> Color:
	if GameConfig.COLOR_HEX.has(c):
		return Color.html(GameConfig.COLOR_HEX[c])
	return Color.WHITE

# ============================================================
# Boon application — called by MatchScene after boon pick (§4.2)
# Dispatched on BoonDB.effect_key so legacy ids and new ids share handlers.
# ============================================================
func apply_boon(boon_id: String) -> void:
	# Legacy color-bias ids still encode the color in the id, so handle those
	# explicitly. Everything else routes through effect_key.
	match boon_id:
		"red_bias":    color_bias = GameConfig.BubbleColor.RED; return
		"blue_bias":   color_bias = GameConfig.BubbleColor.BLUE; return
		"yellow_bias": color_bias = GameConfig.BubbleColor.YELLOW; return
	var key: String = BoonDB.get_effect_key(boon_id)
	match key:
		"cannon_fire_rate":      fire_rate_cap_sec = 0.4
		"cannon_rapid_fire":     fire_rate_cap_sec = min(fire_rate_cap_sec, 0.375)
		"cannon_infinity_mag":   fire_rate_cap_sec = 0.15
		"cannon_ricochet":       ricochet_count = max(ricochet_count, 2)
		"cannon_color_lock":     boon_color_lock = true
		"cannon_overcharge":     boon_overcharge = true
		"cannon_twin":           boon_twin_cannons = true
		"cannon_wide_barrel":    boon_wide_barrel = true
		"cannon_queue_plus2":    pass  # queue UI only shows 2; visual stub only
		"extra_special":         pass  # handled by special-bubble timer elsewhere
		_:                       pass  # hero / lane / matchscene-side effects
