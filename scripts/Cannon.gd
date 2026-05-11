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

func _ready() -> void:
	fire_rate_cap_sec = GameConfig.fire_rate_cap_sec
	ricochet_count    = GameConfig.aim_ricochet_count
	_next_bomb_at_shot = GameConfig.get_color_bomb_next_cadence()

# ============================================================
# §3.3 — Input
# ============================================================
func _input(event: InputEvent) -> void:
	# TODO: touch-and-hold anywhere in lower 70% of screen → show aim line.
	# TODO: drag to set angle. Release to fire.
	# TODO: aim line draws full trajectory with `ricochet_count` reflections off side walls.
	# TODO: enforce fire_rate_cap_sec.
	pass

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
