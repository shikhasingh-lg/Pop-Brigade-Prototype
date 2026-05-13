# Enemy — single enemy unit marching down the lane.
# Design spec §3.6. Spawned by Cluster when bubbles cross spawn line.

class_name Enemy
extends Node2D

signal reached_cannon(enemy_id: int, color: int, hp_damage: int)
signal died(enemy_id: int, color: int, killed_by_color: int, lifetime_ms: int)

@export_enum("Red", "Blue", "Yellow") var color: int = 0
@export var lane_col: int = 0
var lane_row: int = 0
var lane_ref: Lane = null  # injected by Lane on spawn

# §4.3 Stage 5 boss flag. Lane sets these BEFORE _ready() so _apply_color_stats
# can use boss HP / damage instead of the color-baseline values.
var is_boss: bool = false
var boss_hp_override: int = 0
var boss_damage_override: int = 0

var hp: int = 50
var speed_sec_per_cell: float = 1.0
var damage_on_reach: int = 10
var _move_timer: float = 0.0
var _spawn_ms: int = 0
var _enemy_id: int = 0
var _slow_factor: float = 1.0  # 1.0 = normal, 0.7 = 30% slowed (Blue hero debuff)
var _slow_timer: float = 0.0
var _reached: bool = false

@onready var _sprite: ColorRect = $Sprite

func _ready() -> void:
	_spawn_ms = Time.get_ticks_msec()
	_enemy_id = get_instance_id()
	_apply_color_stats()
	_apply_visual()

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
	# §4.3 boss override (Stage 5 only): tougher + slower + harder-hitting.
	if is_boss:
		if boss_hp_override > 0: hp = boss_hp_override
		if boss_damage_override > 0: damage_on_reach = boss_damage_override
		speed_sec_per_cell = speed_sec_per_cell * 1.5
		scale = Vector2(1.6, 1.6)

func _apply_visual() -> void:
	if _sprite == null: return
	if GameConfig.COLOR_HEX.has(color):
		# Enemies use a darker tone of their color so they read distinct from heroes.
		var base := Color.html(GameConfig.COLOR_HEX[color])
		_sprite.color = base.darkened(0.25)

func _process(delta: float) -> void:
	if _reached: return
	if _slow_timer > 0:
		_slow_timer -= delta
		if _slow_timer <= 0:
			_slow_factor = 1.0
	_move_timer += delta * _slow_factor
	# Fast "drop-in" travel while above the spawn line (lane_row < 0); switch
	# to color-stat speed once the enemy hits row 0 (the spawn line / hero row).
	var effective_speed: float = Lane.ENEMY_FAST_SEC_PER_CELL if lane_row < 0 else speed_sec_per_cell
	if _move_timer >= effective_speed:
		_move_timer = 0.0
		_advance_cell()

func _advance_cell() -> void:
	lane_row += 1
	if lane_row >= Lane.ROWS:
		_reached = true
		emit_signal("reached_cannon", _enemy_id, color, damage_on_reach)
		queue_free()
		return
	# Tween to new cell centre. Position is local (parent = Lane).
	var target_pos := Vector2.ZERO
	if lane_ref != null:
		target_pos = lane_ref.cell_to_local_pos(lane_row, lane_col)
	else:
		target_pos = position + Vector2(0, Lane.CELL_H)
	# Fast-mode tween (while still above row 0) must finish before the next
	# advance fires (Lane.ENEMY_FAST_SEC_PER_CELL apart) — use a tight 0.18s.
	var tween_dur: float = 0.18 if lane_row < 0 else min(0.25, speed_sec_per_cell * 0.4)
	var tw := create_tween()
	tw.tween_property(self, "position", target_pos, tween_dur) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

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
