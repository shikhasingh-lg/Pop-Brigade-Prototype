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
var lane_ref: Lane = null  # injected by Lane on spawn

var _fire_timer: float = 0.0
var _damage_dealt_total: int = 0
var _spawn_ms: int = 0
var _hero_id: int = 0

# Damage multipliers (§3.5 + §4.2 boons + §3.6 color counter)
var damage_mult_global: float = 1.0    # color frenzy buff
var damage_mult_class: float  = 1.0    # boon "+25% red dmg" etc.

@onready var _sprite: ColorRect = $Sprite

func _ready() -> void:
	_spawn_ms = Time.get_ticks_msec()
	_hero_id = get_instance_id()
	_apply_tier_stats()
	_apply_class_stats()
	_apply_visual()

func spawn_ms() -> int:
	return _spawn_ms

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

func _apply_visual() -> void:
	if _sprite == null: return
	if GameConfig.COLOR_HEX.has(color):
		_sprite.color = Color.html(GameConfig.COLOR_HEX[color])
	# Tier accent: scale the sprite slightly so testers can read tier without art.
	var s := 1.0
	if tier == "silver": s = 1.15
	elif tier == "gold": s = 1.3
	scale = Vector2(s, s)

func _process(delta: float) -> void:
	_fire_timer += delta
	if _fire_timer >= fire_rate_sec:
		_fire_timer = 0.0
		_try_fire()

func _try_fire() -> void:
	# §3.5: idle in Phase 1; combat only when MatchScene flips lane.combat_enabled
	# on _enter_phase_2. Cheaper than a per-frame phase lookup on MatchScene.
	if lane_ref == null or not lane_ref.combat_enabled: return
	var target: Enemy = lane_ref.find_enemy_in_range(self, range_cells)
	if target == null: return
	# §3.6 color counter (2× vs same color) + frenzy + class boon mults.
	var dmg_f: float = float(damage) * damage_mult_global * damage_mult_class
	if target.color == color:
		dmg_f *= GameConfig.color_counter_multiplier
	var dmg := int(round(dmg_f))
	_emit_attack_vfx(target)
	target.take_damage(dmg, color)
	# Blue applies a 30%/2s slow on hit (§3.5).
	if color == GameConfig.BubbleColor.BLUE and is_instance_valid(target):
		target.apply_slow()
	_damage_dealt_total += dmg
	Telemetry.log_hero_attack(_hero_id, target.get_instance_id(), dmg)

func _emit_attack_vfx(target: Enemy) -> void:
	# Cheap greybox VFX: a short-lived Line2D from hero to target.
	var line := Line2D.new()
	line.width = 3.0
	line.default_color = Color.html(GameConfig.COLOR_HEX[color])
	line.add_point(Vector2.ZERO)
	line.add_point(to_local(target.global_position))
	add_child(line)
	var timer := get_tree().create_timer(0.08)
	timer.timeout.connect(func():
		if is_instance_valid(line):
			line.queue_free())

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
