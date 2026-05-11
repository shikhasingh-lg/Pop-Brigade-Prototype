# Cannon — aim, fire, queue, swap.
# Design spec §3.3.

class_name Cannon
extends Node2D

signal bubble_fired(bubble: Bubble, aim_angle_deg: float, time_to_fire_ms: int)

@export var bubble_scene: PackedScene
@export var aim_line: Line2D  # set in editor — the dotted trajectory preview

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

# W1 debug harness: tap a cell to place a bubble there. Skips flight physics.
# Flip to false in W2 when Bubble._physics_process is implemented.
@export var debug_mode: bool = true
@export var cluster_path: NodePath  # set in MatchScene.tscn; W1 only

# Queue HUD ColorRects (set up in MatchScene.tscn — current is child of Cannon, on-deck is sibling).
@onready var _current_sprite: ColorRect = get_node_or_null("CurrentBubble")
@onready var _on_deck_sprite: ColorRect = get_node_or_null("../OnDeckBubble")

func _ready() -> void:
	fire_rate_cap_sec = GameConfig.fire_rate_cap_sec
	ricochet_count    = GameConfig.aim_ricochet_count
	_next_bomb_at_shot = GameConfig.get_color_bomb_next_cadence()
	# Seed palette for the W1 debug queue: use all colors so we can test matches freely.
	color_palette = GameConfig.all_bubble_colors()
	current_color = color_palette[randi() % color_palette.size()]
	on_deck_color = color_palette[randi() % color_palette.size()]
	_refresh_queue_visuals()
	if not debug_mode:
		return
	# Defer cluster resolution so MatchScene's @onready vars finish first.
	call_deferred("_resolve_cluster")

func _refresh_queue_visuals() -> void:
	if _current_sprite != null:
		_current_sprite.color = _color_for_enum(current_color)
	if _on_deck_sprite != null:
		_on_deck_sprite.color = _color_for_enum(on_deck_color)

func _color_for_enum(c: int) -> Color:
	if GameConfig.COLOR_HEX.has(c):
		return Color.html(GameConfig.COLOR_HEX[c])
	return Color.WHITE

var _cluster_ref: Cluster = null

func _resolve_cluster() -> void:
	if cluster_path != NodePath(""):
		_cluster_ref = get_node_or_null(cluster_path)
	if _cluster_ref == null:
		# Fallback: scan the scene tree for a Cluster (one expected per match).
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
# §3.3 — Input
# ============================================================
func _input(event: InputEvent) -> void:
	if debug_mode:
		_debug_input(event)
		return
	# TODO W2: touch-and-hold anywhere in lower 70% of screen → show aim line.
	# TODO W2: drag to set angle. Release to fire.
	# TODO W2: aim line draws full trajectory with `ricochet_count` reflections off side walls.
	# TODO W2: enforce fire_rate_cap_sec.

func _debug_input(event: InputEvent) -> void:
	# W1 tap-to-place: tap places a bubble of `current_color` at the nearest empty hex.
	# Handle only InputEventMouseButton; project has emulate_touch_from_mouse=true so a
	# single click otherwise fires twice (MouseButton + ScreenTouch).
	if not (event is InputEventMouseButton): return
	if not event.pressed: return
	if event.button_index != MOUSE_BUTTON_LEFT: return
	if _cluster_ref == null:
		_resolve_cluster()
		if _cluster_ref == null:
			push_warning("Cannon[debug]: no Cluster found in scene; tap ignored")
			return
	var world_pos: Vector2 = event.position
	# Bottom HUD: swap if tap is on the on-deck slot (MatchScene.tscn: x 380..440, y 1450..1500).
	if world_pos.y > 1390:
		if world_pos.x >= 370 and world_pos.x <= 450 \
				and world_pos.y >= 1440 and world_pos.y <= 1510:
			swap_queue()
		return
	# Use the bubble_scene exported on Cluster (already wired in MatchScene.tscn).
	# Per spec §3.7, color bombs only spawn IN the cluster at stage >=4, never from the cannon.
	var b: Bubble = _cluster_ref.bubble_scene.instantiate()
	b.color = current_color
	b.is_special_color_bomb = false
	_cluster_ref.attach_bubble(b, world_pos)
	Telemetry.log_bubble_fired(1, current_color, false, 0.0, 0)
	_advance_queue()

# ============================================================
# §3.3 — Fire
# ============================================================
func try_fire(aim_angle_deg: float, queue_swap_used: bool, stage_num: int) -> void:
	var now_ms := Time.get_ticks_msec()
	if (now_ms - _last_fire_ms) / 1000.0 < fire_rate_cap_sec:
		return  # rate-capped
	_last_fire_ms = now_ms
	var b: Bubble = bubble_scene.instantiate()
	b.color = current_color
	b.is_special_color_bomb = _is_color_bomb()
	b.velocity = Vector2.from_angle(deg_to_rad(aim_angle_deg)) * GameConfig.bubble_speed_px_per_sec
	b.in_flight = true
	get_tree().current_scene.add_child(b)
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
	# TODO W2: apply +30% weight toward color_bias if set, then weighted random pick.
	return color_palette[randi() % color_palette.size()]

func _is_color_bomb() -> bool:
	if _shot_count_since_last_bomb >= _next_bomb_at_shot:
		_shot_count_since_last_bomb = 0
		_next_bomb_at_shot = GameConfig.get_color_bomb_next_cadence()
		return true
	return false

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
