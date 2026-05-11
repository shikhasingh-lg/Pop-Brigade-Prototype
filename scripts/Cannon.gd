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

func _ready() -> void:
	fire_rate_cap_sec = GameConfig.fire_rate_cap_sec
	ricochet_count    = GameConfig.aim_ricochet_count
	_next_bomb_at_shot = GameConfig.get_color_bomb_next_cadence()
	# Seed palette for the W1 debug queue: use all colors so we can test matches freely.
	color_palette = GameConfig.all_bubble_colors()
	current_color = color_palette[randi() % color_palette.size()]
	on_deck_color = color_palette[randi() % color_palette.size()]
	if not debug_mode:
		return
	# Defer cluster resolution so MatchScene's @onready vars finish first.
	call_deferred("_resolve_cluster")

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
	# W1 tap-to-place: any tap (mouse-down or touch-down) places a bubble of `current_color`
	# at the nearest empty hex cell to the tap position.
	var is_tap: bool = false
	if event is InputEventMouseButton:
		is_tap = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		is_tap = event.pressed
	if not is_tap: return
	if _cluster_ref == null:
		_resolve_cluster()
		if _cluster_ref == null:
			push_warning("Cannon[debug]: no Cluster found in scene; tap ignored")
			return
	var world_pos: Vector2 = event.position
	# Ignore taps in the bottom HUD (cannon area) to allow swap-tap later.
	if world_pos.y > 1390: return
	# Use the bubble_scene exported on Cluster (already wired in MatchScene.tscn).
	var b: Bubble = _cluster_ref.bubble_scene.instantiate()
	b.color = current_color
	b.is_special_color_bomb = _is_color_bomb()
	# Cluster handles parenting + placement; pass world position.
	_cluster_ref.attach_bubble(b, world_pos)
	Telemetry.log_bubble_fired(1, current_color, false, 0.0, 0)
	_advance_queue()
	_shot_count_since_last_bomb += 1

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

func swap_queue() -> void:
	var tmp := current_color
	current_color = on_deck_color
	on_deck_color = tmp

func _draw_from_palette() -> int:
	# §3.3 — only colors still in cluster are drawn. With color_bias (boon), bias toward color_bias by +30%.
	if color_palette.is_empty():
		return GameConfig.BubbleColor.RED  # fallback
	# TODO: apply +30% weight toward color_bias if set, then weighted random pick.
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
