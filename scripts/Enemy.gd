# Enemy — single enemy unit marching down the lane.
# Design spec §3.6. Spawned by Cluster when bubbles cross spawn line.

class_name Enemy
extends Node2D

signal reached_cannon(enemy_id: int, color: int, hp_damage: int)
signal died(enemy_id: int, color: int, killed_by_color: int, lifetime_ms: int)

@export_enum("Red", "Blue", "Yellow") var color: int = 0
@export var lane_col: int = 0
var lane_row: int = 0

var hp: int = 50
var speed_sec_per_cell: float = 1.0
var damage_on_reach: int = 10
var _move_timer: float = 0.0
var _spawn_ms: int = 0
var _enemy_id: int = 0
var _slow_factor: float = 1.0  # 1.0 = normal, 0.7 = 30% slowed (Blue hero debuff)
var _slow_timer: float = 0.0

func _ready() -> void:
	_spawn_ms = Time.get_ticks_msec()
	_enemy_id = get_instance_id()
	_apply_color_stats()

func _apply_color_stats() -> void:
	match color:
		GameConfig.BubbleColor.RED:
			hp = GameConfig.red_enemy_hp
			speed_sec_per_cell = GameConfig.red_enemy_speed_sec_per_cell
			damage_on_reach = GameConfig.red_enemy_damage_on_reach
		GameConfig.BubbleColor.BLUE:
			hp = GameConfig.blue_enemy_hp
			speed_sec_per_cell = GameConfig.blue_enemy_speed_sec_per_cell
			damage_on_reach = GameConfig.blue_enemy_damage_on_reach
		GameConfig.BubbleColor.YELLOW:
			hp = GameConfig.yellow_enemy_hp
			speed_sec_per_cell = GameConfig.yellow_enemy_speed_sec_per_cell
			damage_on_reach = GameConfig.yellow_enemy_damage_on_reach

func _process(delta: float) -> void:
	if _slow_timer > 0:
		_slow_timer -= delta
		if _slow_timer <= 0:
			_slow_factor = 1.0
	_move_timer += delta * _slow_factor
	if _move_timer >= speed_sec_per_cell:
		_move_timer = 0.0
		_advance_cell()

func _advance_cell() -> void:
	# TODO §3.6: lane_row += 1. Move to new cell position visually.
	# TODO: if lane_row reaches the bottom row (cannon), emit reached_cannon() and queue_free().
	pass

func take_damage(amount: int, source_color: int) -> void:
	hp -= amount
	if hp <= 0:
		Telemetry.log_enemy_death(_enemy_id, color, source_color,
			Time.get_ticks_msec() - _spawn_ms)
		emit_signal("died", _enemy_id, color, source_color,
			Time.get_ticks_msec() - _spawn_ms)
		queue_free()

func apply_slow() -> void:
	# §3.5 Blue hero ability: 30% slow for 2s.
	_slow_factor = 1.0 - GameConfig.blue_slow_pct
	_slow_timer = GameConfig.blue_slow_duration_sec
