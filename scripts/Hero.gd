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

@onready var _sprite: Sprite2D = $Sprite

# Target on-lane footprint (px). Original greybox block was 60×60.
const _HERO_DISPLAY_PX := 84.0

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
	# Per-class fire rate. Range is encoded in Lane's class-specific pickers
	# (combat-design.md §2.1); we keep range_cells for back-compat / telemetry only.
	match color:
		GameConfig.BubbleColor.RED:
			fire_rate_sec = GameConfig.red_fire_rate_sec
			range_cells = GameConfig.red_cone_rows
		GameConfig.BubbleColor.BLUE:
			fire_rate_sec = GameConfig.blue_fire_rate_sec
			range_cells = GameConfig.blue_reach_rows
		GameConfig.BubbleColor.YELLOW:
			fire_rate_sec = GameConfig.yellow_fire_rate_sec
			range_cells = GameConfig.yellow_reach_rows

func _apply_visual() -> void:
	if _sprite == null: return
	# Pull the cutout (transparent-bg) portrait for this hero's color binding.
	var entry: Dictionary = HeroRoster.get_for_color(color)
	if not entry.is_empty():
		var slug: String = entry["slug"]
		var tex: Texture2D = HeroRoster.get_cutout(slug)
		if tex != null:
			_sprite.texture = tex
			# Fit the 512² portrait into ~_HERO_DISPLAY_PX on the lane.
			var max_dim: int = max(tex.get_width(), tex.get_height())
			if max_dim > 0:
				var fit: float = _HERO_DISPLAY_PX / float(max_dim)
				_sprite.scale = Vector2(fit, fit)
			_sprite.modulate = Color(1, 1, 1, 1)
	# Tier accent: scale the whole hero slightly so testers can read tier.
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
	match color:
		GameConfig.BubbleColor.RED:    _fire_red()
		GameConfig.BubbleColor.BLUE:   _fire_blue()
		GameConfig.BubbleColor.YELLOW: _fire_yellow()

# Final per-hit damage including frenzy + class boon + color counter.
func _damage_against(target: Enemy, class_dmg_mult: float) -> int:
	var dmg_f: float = float(damage) * damage_mult_global * damage_mult_class * class_dmg_mult
	if target.color == color:
		dmg_f *= GameConfig.color_counter_multiplier
	return int(round(dmg_f))

# ----- Fire Knight (RED): cone + chance to cleave row neighbors -----
func _fire_red() -> void:
	var target: Enemy = lane_ref.find_target_red(self)
	if target == null: return
	var dmg: int = _damage_against(target, GameConfig.red_dmg_mult)
	_vfx_red_cone(target)
	target.take_damage(dmg, color)
	_damage_dealt_total += dmg
	Telemetry.log_hero_attack(_hero_id, target.get_instance_id(), dmg)
	# Cleave proc: hit up to N other enemies in the SAME row in the cone.
	if randf() < GameConfig.red_cleave_chance:
		var cleaved: int = 0
		for e in lane_ref._enemies:
			if cleaved >= GameConfig.red_cleave_targets: break
			if e == null or not is_instance_valid(e): continue
			if e == target: continue
			if e.lane_row != target.lane_row: continue
			if abs(e.lane_col - lane_col) > GameConfig.red_cone_cols: continue
			var cd: int = _damage_against(e, GameConfig.red_dmg_mult)
			e.take_damage(cd, color)
			_damage_dealt_total += cd
			cleaved += 1

# ----- Ice Mage (BLUE): lob + AoE splash + slow -----
func _fire_blue() -> void:
	var target: Enemy = lane_ref.find_target_blue(self)
	if target == null: return
	var primary_dmg: int = _damage_against(target, GameConfig.blue_dmg_mult)
	_vfx_blue_lob(target)
	# AoE: every enemy within blue_aoe_radius_cells of the target takes same dmg + slow.
	# (Friendly fire OFF — heroes are excluded; AoE list is enemies only.)
	var splash: Array = lane_ref.enemies_in_aoe(target.position, GameConfig.blue_aoe_radius_cells)
	for e in splash:
		if e == null or not is_instance_valid(e): continue
		var d: int = primary_dmg if e == target else _damage_against(e, GameConfig.blue_dmg_mult)
		e.take_damage(d, color)
		if is_instance_valid(e):
			e.apply_slow()
		_damage_dealt_total += d
	Telemetry.log_hero_attack(_hero_id, target.get_instance_id(), primary_dmg)

# ----- Archer (YELLOW): straight shot + execute under-30% bonus -----
func _fire_yellow() -> void:
	var target: Enemy = lane_ref.find_target_yellow(self)
	if target == null: return
	var dmg_f: float = float(damage) * damage_mult_global * damage_mult_class * GameConfig.yellow_dmg_mult
	if target.color == color:
		dmg_f *= GameConfig.color_counter_multiplier
	var max_hp: int = _enemy_max_hp(target)
	var is_execute: bool = max_hp > 0 and (float(target.hp) / float(max_hp)) < GameConfig.yellow_execute_threshold
	if is_execute:
		dmg_f *= (1.0 + GameConfig.yellow_execute_bonus)
	var dmg: int = int(round(dmg_f))
	_vfx_yellow_shot(target, is_execute)
	target.take_damage(dmg, color)
	_damage_dealt_total += dmg
	Telemetry.log_hero_attack(_hero_id, target.get_instance_id(), dmg)

# Best-effort max-HP probe (Enemy stores starting hp in _spawn_hp set by Enemy.gd).
func _enemy_max_hp(e: Enemy) -> int:
	if e.has_method("get_max_hp"):
		return e.get_max_hp()
	return e.hp  # fallback (means execute never triggers)

# ============================================================
# VFX — short-lived built-in nodes, no asset files.
# ============================================================
func _vfx_red_cone(target: Enemy) -> void:
	# Brief forward lunge toward the target.
	var dir: Vector2 = (target.global_position - global_position).normalized()
	var tw := create_tween()
	tw.tween_property(self, "position", position + dir * 8.0, 0.06)
	tw.tween_property(self, "position", position, 0.12)
	# Red wedge drawn in front of the hero, 90° arc, ~120 px reach.
	var wedge := Polygon2D.new()
	wedge.color = Color(1.0, 0.35, 0.18, 0.55)
	var reach: float = 120.0
	var half_deg: float = 45.0
	var base_angle: float = dir.angle()
	var pts := PackedVector2Array()
	pts.append(Vector2.ZERO)
	var steps := 8
	for i in steps + 1:
		var t: float = -half_deg + (2.0 * half_deg) * (float(i) / float(steps))
		var a: float = base_angle + deg_to_rad(t)
		pts.append(Vector2(cos(a), sin(a)) * reach)
	wedge.polygon = pts
	add_child(wedge)
	var timer := get_tree().create_timer(0.18)
	timer.timeout.connect(func():
		if is_instance_valid(wedge):
			wedge.queue_free())

func _vfx_blue_lob(target: Enemy) -> void:
	# Cyan shard tweens from hero to target along a low arc, then an AoE ring expands.
	var shard := Polygon2D.new()
	shard.color = Color(0.40, 0.78, 1.0, 0.95)
	shard.polygon = PackedVector2Array([
		Vector2(0, -10), Vector2(8, 6), Vector2(-8, 6),
	])
	get_parent().add_child(shard)  # parent = Lane (so global_position works directly)
	shard.global_position = global_position
	var p0: Vector2 = global_position
	var p2: Vector2 = target.global_position
	var ring_local_pos: Vector2 = target.position  # capture NOW — target may die mid-flight
	var mid: Vector2 = (p0 + p2) * 0.5
	mid.y -= 40.0  # arc apex above straight line
	var sh_tween := create_tween()
	sh_tween.tween_method(func(t: float):
		if not is_instance_valid(shard): return
		var u: float = 1.0 - t
		shard.global_position = u * u * p0 + 2.0 * u * t * mid + t * t * p2
		shard.rotation = (p2 - p0).angle() + t * PI
	, 0.0, 1.0, 0.18)
	sh_tween.tween_callback(func():
		if is_instance_valid(shard): shard.queue_free()
		_spawn_blue_aoe_ring(ring_local_pos))

func _spawn_blue_aoe_ring(local_target_pos: Vector2) -> void:
	# Expanding ring (filled poly approximated as circle) on the lane node.
	var ring := Polygon2D.new()
	ring.color = Color(0.40, 0.78, 1.0, 0.35)
	var radius: float = GameConfig.blue_aoe_radius_cells * Lane.CELL_H
	var pts := PackedVector2Array()
	var n := 24
	for i in n:
		var a: float = TAU * float(i) / float(n)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	ring.polygon = pts
	get_parent().add_child(ring)
	ring.position = local_target_pos
	ring.scale = Vector2(0.1, 0.1)
	var rt := create_tween()
	rt.tween_property(ring, "scale", Vector2(1.0, 1.0), 0.18).set_trans(Tween.TRANS_SINE)
	rt.parallel().tween_property(ring, "modulate:a", 0.0, 0.22)
	rt.tween_callback(func():
		if is_instance_valid(ring): ring.queue_free())

func _vfx_yellow_shot(target: Enemy, is_execute: bool) -> void:
	# Yellow streak from hero to target, with a white core.
	var line := Line2D.new()
	line.width = 4.0
	line.default_color = Color(1.0, 0.82, 0.12, 0.95)
	line.add_point(Vector2.ZERO)
	line.add_point(to_local(target.global_position))
	add_child(line)
	# Brief recoil on the hero.
	var rec := create_tween()
	rec.tween_property(self, "position", position + Vector2(0, 4), 0.04)
	rec.tween_property(self, "position", position, 0.10)
	# Target flash.
	if is_instance_valid(target):
		var orig_mod: Color = target.modulate
		var flash_color := Color(1, 1, 1, 1) if not is_execute else Color(1.3, 1.2, 0.6, 1)
		target.modulate = flash_color
		var t := get_tree().create_timer(0.08)
		t.timeout.connect(func():
			if is_instance_valid(target):
				target.modulate = orig_mod)
	var lt := get_tree().create_timer(0.12 if not is_execute else 0.18)
	lt.timeout.connect(func():
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
