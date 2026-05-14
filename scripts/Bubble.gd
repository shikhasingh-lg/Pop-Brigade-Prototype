# Bubble — single bubble entity (in flight or attached to cluster).
# Design spec §3.2 (cluster) and §3.3 (aim/fire).

class_name Bubble
extends Area2D

signal attached_to_cluster(row: int, col: int)
# Conversion-to-enemy is emitted by Cluster (see Cluster.bubble_crossed_spawn_line),
# not by the Bubble itself — kept as documentation, no Bubble-level signal needed.

@export_enum("Red", "Blue", "Yellow") var color: int = 0
@export var is_special_color_bomb: bool = false
# Hero bubble — when matched, spawns a hero of `color`. Pre-placed in the cluster
# or converted from regular bubbles via a designer hook. Renders with hero-bubble art.
@export var is_hero_bubble: bool = false

var grid_row: int = -1
var grid_col: int = -1
var velocity: Vector2 = Vector2.ZERO
var in_flight: bool = false
var cluster_ref: Cluster = null
# The cluster bubble that triggered the collision-based attach. Null when the
# attach was caused by a top-wall hit (no specific neighbor to anchor against).
var _hit_bubble: Bubble = null

var _fill_color: Color = Color(1, 1, 1, 1)
var _texture: Texture2D = null

const BUBBLE_RADIUS := 32.0
# Snap/collision radius is smaller than the visual radius so a ball can thread
# a perceived gap between two cluster bubbles without grazing them. Bubble.tscn's
# CollisionShape2D must match this value. Used by Cannon's trajectory preview too.
const ATTACH_RADIUS := 28.0

# Visual radius is larger than collision radius because the 256² texture has
# transparent padding around the bubble. Tweak _VISUAL_OVERSIZE if the bubbles
# overlap (decrease) or look too small / detached (increase).
const _VISUAL_OVERSIZE := 1.7

const FIELD_WIDTH := 720.0
const FIELD_HEIGHT := 1560.0
const TOP_BOUND_Y := 120.0  # bottom of top HUD; bubbles passing this attach to cluster
const TOP_CENTER_Y := TOP_BOUND_Y + BUBBLE_RADIUS

var _attaching: bool = false

# Hero-bubble visual treatment — gold halo + ring + slow pulse so they read
# as "special" against the regular cluster regardless of source art.
const HERO_RING_COLOR := Color(1.0, 0.85, 0.25, 1.0)
const HERO_RING_WIDTH := 4.0
const HERO_GLOW_EXTRA_PX := 10.0
const HERO_PULSE_HZ := 0.7  # cycles/sec
var _hero_pulse_t: float = 0.0

func _ready() -> void:
	_apply_color()
	# The bubble is an Area2D for editor-visible collision radius, but shot attach
	# is driven by the same swept math as the aim preview. Raw overlap callbacks
	# made near-wall shots feel random because they could disagree with the preview.
	monitoring = false
	area_entered.connect(_on_area_entered)
	set_process(is_hero_bubble)

func set_color(c: int) -> void:
	color = c
	_apply_color()

func _apply_color() -> void:
	_texture = BubbleRoster.get_hero_cutout(color) if is_hero_bubble else BubbleRoster.get_cutout(color)
	# Color-bomb gets a brighter tint over the chosen texture as a placeholder.
	# (Final art will swap for a rainbow/shader treatment.)
	_fill_color = Color(1.4, 1.4, 1.4, 1) if is_special_color_bomb else Color(1, 1, 1, 1)
	queue_redraw()

func set_hero_bubble(flag: bool) -> void:
	is_hero_bubble = flag
	_apply_color()
	set_process(flag)

func _process(delta: float) -> void:
	# Only ticks when is_hero_bubble (gated via set_process in _ready/set_hero_bubble).
	_hero_pulse_t += delta
	queue_redraw()

func _draw() -> void:
	if _texture == null: return
	var half: float = BUBBLE_RADIUS * _VISUAL_OVERSIZE
	var rect := Rect2(Vector2(-half, -half), Vector2(half * 2.0, half * 2.0))
	if is_hero_bubble:
		# Pulse 0..1 over time; ring + soft outer glow underneath the texture.
		var pulse: float = (sin(_hero_pulse_t * TAU * HERO_PULSE_HZ) + 1.0) * 0.5
		var ring_alpha: float = lerp(0.55, 0.95, pulse)
		var glow_alpha: float = lerp(0.18, 0.40, pulse)
		var glow_r: float = BUBBLE_RADIUS + HERO_GLOW_EXTRA_PX + 3.0 * pulse
		draw_circle(Vector2.ZERO, glow_r,
			Color(HERO_RING_COLOR.r, HERO_RING_COLOR.g, HERO_RING_COLOR.b, glow_alpha))
		draw_arc(Vector2.ZERO, BUBBLE_RADIUS + 2.0, 0.0, TAU, 32,
			Color(HERO_RING_COLOR.r, HERO_RING_COLOR.g, HERO_RING_COLOR.b, ring_alpha),
			HERO_RING_WIDTH, true)
	draw_texture_rect(_texture, rect, false, _fill_color)
	if is_hero_bubble:
		# Small gold star top-right so hero status reads even when the ring is occluded.
		_draw_hero_star(Vector2(BUBBLE_RADIUS * 0.55, -BUBBLE_RADIUS * 0.55), 7.0)

func _draw_hero_star(c: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	var n: int = 5
	for i in range(n * 2):
		var ang: float = -PI * 0.5 + i * PI / float(n)
		var rr: float = r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(ang), sin(ang)) * rr)
	# Dark outline first so the star reads on any background.
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0, 0, 0, 0.6), 2.0, true)
	draw_colored_polygon(pts, HERO_RING_COLOR)

# Launch this bubble from a global position with velocity, aimed at a Cluster.
# Caller must add the bubble to the scene tree first; this just sets state.
func launch(start_global_pos: Vector2, vel: Vector2, cluster: Cluster) -> void:
	global_position = start_global_pos
	velocity = vel
	in_flight = true
	cluster_ref = cluster
	_attaching = false
	_hit_bubble = null

func _physics_process(delta: float) -> void:
	if not in_flight or _attaching: return
	var remaining: float = velocity.length() * delta
	var safety := 4
	while remaining > 0.001 and safety > 0:
		safety -= 1
		var dir := velocity.normalized()
		var t_left: float = INF
		var t_right: float = INF
		var t_top: float = INF
		if dir.x < 0.0: t_left = (BUBBLE_RADIUS - global_position.x) / dir.x
		if dir.x > 0.0: t_right = (FIELD_WIDTH - BUBBLE_RADIUS - global_position.x) / dir.x
		if dir.y < 0.0: t_top = (TOP_CENTER_Y - global_position.y) / dir.y
		var t_wall: float = min(t_left, t_right)
		var cluster_hit := _sweep_first_cluster_hit(global_position, dir, remaining)
		var t_cluster: float = cluster_hit["t"]
		var t: float = min(t_wall, min(t_top, t_cluster))
		if t == INF or t > remaining:
			global_position += dir * remaining
			remaining = 0.0
			break
		if t <= 0.001:
			t = min(remaining, 0.001)
		global_position += dir * t
		remaining -= t
		if t == t_cluster:
			_hit_bubble = cluster_hit["bubble"]
			if cluster_ref != null:
				global_position = cluster_ref.predict_attach_world_position(global_position, _hit_bubble)
			_begin_attach()
			return
		# §3.2 top-wall attach (no neighbor to snap against — snap to top row)
		if t == t_top:
			global_position.y = TOP_CENTER_Y
			if cluster_ref != null:
				global_position = cluster_ref.predict_attach_world_position(global_position)
			_begin_attach()
			return
		# §3.3 side-wall ricochet
		if t == t_wall:
			if global_position.x < FIELD_WIDTH * 0.5:
				global_position.x = BUBBLE_RADIUS
			else:
				global_position.x = FIELD_WIDTH - BUBBLE_RADIUS
			velocity.x = -velocity.x
	if remaining > 0.001 and not _attaching:
		global_position += velocity.normalized() * remaining
	# Safety: if a bubble ever exits the field (e.g., aim sideways and grazes), free it.
	if global_position.y > FIELD_HEIGHT + BUBBLE_RADIUS:
		queue_free()

func _sweep_first_cluster_hit(pos: Vector2, dir: Vector2, max_t: float) -> Dictionary:
	if cluster_ref == null:
		return { "t": INF, "bubble": null }
	var sum_r: float = ATTACH_RADIUS * 2.0
	var sum_r_sq: float = sum_r * sum_r
	var best_t: float = INF
	var best_bubble: Bubble = null
	for child in cluster_ref.get_children():
		if not (child is Bubble):
			continue
		var b: Bubble = child
		if b == self or b.in_flight:
			continue
		var d: Vector2 = pos - b.global_position
		var b_coef: float = 2.0 * d.dot(dir)
		var c_coef: float = d.dot(d) - sum_r_sq
		var disc: float = b_coef * b_coef - 4.0 * c_coef
		if disc < 0.0:
			continue
		var sqrt_disc: float = sqrt(disc)
		var t0: float = (-b_coef - sqrt_disc) * 0.5
		var t1: float = (-b_coef + sqrt_disc) * 0.5
		var t_hit: float = t0 if t0 > 0.001 else t1
		if t_hit > 0.001 and t_hit <= max_t and t_hit < best_t:
			best_t = t_hit
			best_bubble = b
	return { "t": best_t, "bubble": best_bubble }

func _on_area_entered(_area: Area2D) -> void:
	pass

# Two-phase attach: flip state immediately so _physics_process / future signals bail out,
# then defer the actual reparent so it doesn't run inside a physics callback (Godot forbids
# reparenting/disabling a CollisionObject2D mid-physics — flushing-queries errors).
func _begin_attach() -> void:
	if _attaching: return
	_attaching = true
	in_flight = false
	velocity = Vector2.ZERO
	call_deferred("_do_attach")

func _do_attach() -> void:
	if cluster_ref == null:
		queue_free()
		return
	cluster_ref.attach_bubble(self, global_position, _hit_bubble)

func attach_to_grid(row: int, col: int) -> void:
	grid_row = row
	grid_col = col
	in_flight = false
	velocity = Vector2.ZERO
	emit_signal("attached_to_cluster", row, col)

# Place this bubble into a Cluster's local grid at the given local position.
# Used by the W1 debug harness (tap-to-place) and by W2 flight-collision code.
# Reparents into `new_parent` if not already a child.
func attach_to_grid_cell(new_parent: Node, row: int, col: int, local_pos: Vector2) -> void:
	if get_parent() != new_parent:
		if get_parent() != null:
			get_parent().remove_child(self)
		new_parent.add_child(self)
	position = local_pos
	attach_to_grid(row, col)
