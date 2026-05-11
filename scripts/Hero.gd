# Hero — single hero unit on the lane (stationary, auto-fires).
# Design spec §3.4 + §3.5.

class_name Hero
extends Node2D

signal died(hero_id: int, color: int, tier: String, lifetime_ms: int, damage_total: int)

@export_enum("Red", "Blue", "Yellow") var color: int = 0
@export var tier:  String = "bronze"  # "bronze" | "silver" | "gold"
@export var lane_col: int = 0
@export var lane_row: int = 0

var hp: int = 100
var damage: int = 10
var range_cells: int = 3
var fire_rate_sec: float = 1.0
var _fire_timer: float = 0.0
var _damage_dealt_total: int = 0
var _spawn_ms: int = 0
var _hero_id: int = 0

# Damage multipliers (§3.5 + §4.2 boons + §3.6 color counter)
var damage_mult_global: float = 1.0    # color frenzy buff
var damage_mult_class: float  = 1.0    # boon "+25% red dmg" etc.

func _ready() -> void:
	_spawn_ms = Time.get_ticks_msec()
	_hero_id = get_instance_id()
	_apply_tier_stats()
	_apply_class_stats()

func _apply_tier_stats() -> void:
	match tier:
		"bronze": hp = GameConfig.bronze_hp; damage = GameConfig.bronze_dmg
		"silver": hp = GameConfig.silver_hp; damage = GameConfig.silver_dmg
		"gold":   hp = GameConfig.gold_hp;   damage = GameConfig.gold_dmg

func _apply_class_stats() -> void:
	match color:
		GameConfig.BubbleColor.RED:
			range_cells = GameConfig.red_range_cells
			fire_rate_sec = GameConfig.red_fire_rate_sec
		GameConfig.BubbleColor.BLUE:
			range_cells = GameConfig.blue_range_cells
			fire_rate_sec = GameConfig.blue_fire_rate_sec
		GameConfig.BubbleColor.YELLOW:
			range_cells = GameConfig.yellow_range_cells
			fire_rate_sec = GameConfig.yellow_fire_rate_sec

func _process(delta: float) -> void:
	_fire_timer += delta
	if _fire_timer >= fire_rate_sec:
		_fire_timer = 0.0
		_try_fire()

func _try_fire() -> void:
	# §3.5: target nearest enemy in range, prefer lowest HP on ties.
	# TODO: find target via Lane.find_enemy_in_range(self, range_cells)
	# TODO: apply color counter (§3.6) — if target.color == self.color, dmg × color_counter_multiplier
	# TODO: apply damage_mult_global (frenzy) + damage_mult_class (boon)
	# TODO: emit attack VFX (projectile line)
	# TODO: Telemetry.log_hero_attack(_hero_id, target_id, dmg)
	pass

func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		Telemetry.log_hero_death(_hero_id, color, tier,
			Time.get_ticks_msec() - _spawn_ms, _damage_dealt_total)
		emit_signal("died", _hero_id, color, tier,
			Time.get_ticks_msec() - _spawn_ms, _damage_dealt_total)
		queue_free()

func apply_frenzy_buff() -> void:
	damage_mult_global = 1.0 + GameConfig.color_frenzy_buff_pct
	var t := get_tree().create_timer(GameConfig.color_frenzy_duration_sec)
	t.timeout.connect(func(): damage_mult_global = 1.0)
