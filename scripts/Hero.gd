# Hero — single hero unit on the lane (stationary, auto-fires).
# Design spec §3.4 + §3.5.

class_name Hero
extends Node2D

signal died(hero_id: int, color: int, tier: String, lifetime_ms: int, damage_total: int)

@export_enum("Red", "Blue", "Yellow", "Green", "Purple") var color: int = 0
@export var tier:  String = "bronze"  # "bronze" | "silver" | "gold"
@export var lane_col: int = 0
@export var lane_row: int = 0

var hp: int = 100
var max_hp: int = 100
var damage: int = 10
var range_cells: int = 3
var fire_rate_sec: float = 1.0
var lane_ref: Lane = null
# §8.4 Druid per-second heal cap accounting (resets each game-second).
var _heal_received_this_sec: int = 0
var _heal_window_t: float = 0.0
# §8.3 Storm Tyrant electrified column multiplier (set by MatchScene zap).
var damage_taken_mult: float = 1.0
# §8.6 Wizard arcane burst — every Nth attack does AOE.
var _wizard_attack_count: int = 0

var _fire_timer: float = 0.0
var _breathe_timer: float = 0.0
# Idle breathe — ~1Hz sine, 2px amplitude. Tuned to be perceptible without
# competing with attack VFX or the per-hero scale used for tier.
const BREATHE_FREQ_RAD: float = TAU * 1.0    # 1 cycle/sec
const BREATHE_AMPLITUDE_PX: float = 2.0
var _damage_dealt_total: int = 0
var _spawn_ms: int = 0
var _hero_id: int = 0

# Damage multipliers (§3.5 + §4.2 boons + §3.6 color counter)
var damage_mult_global: float = 1.0    # color frenzy buff
var damage_mult_class: float  = 1.0    # boon "+25% red dmg" etc.

@onready var _sprite: Sprite2D = $Sprite

# Target on-lane footprint (px). Original greybox block was 60×60.
const _HERO_DISPLAY_PX := 84.0

# Tier readability: size alone is hard to compare across lanes, so we layer
# a base ring at the feet (tier color), star pips above the head (1/2/3),
# and a pulsing aura for gold only. Three independent signals at zero art cost.
const TIER_COLORS := {
	"bronze": Color(0.78, 0.48, 0.22),
	"silver": Color(0.82, 0.85, 0.92),
	"gold":   Color(1.00, 0.82, 0.12),
}
const TIER_PIPS := { "bronze": 1, "silver": 2, "gold": 3 }

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
	# §3.10.6 playtest-mode level multiplier (stand-in for hero leveling).
	var level_mult: float = GameConfig.hero_level_mult()
	hp = int(round(float(hp) * level_mult))
	damage = int(round(float(damage) * level_mult))
	# §4.2 boons.
	hp = int(round(float(hp) * RunState.boon_global_hp_mult))
	damage_mult_global *= RunState.boon_global_dmg_mult
	max_hp = hp

func _apply_class_stats() -> void:
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
		GameConfig.BubbleColor.GREEN:
			fire_rate_sec = GameConfig.green_fire_rate_sec
			range_cells = GameConfig.green_reach_rows
		GameConfig.BubbleColor.PURPLE:
			fire_rate_sec = GameConfig.purple_fire_rate_sec
			range_cells = GameConfig.purple_reach_rows
	if RunState.boon_global_atk_speed_mult > 0.0:
		fire_rate_sec = fire_rate_sec / RunState.boon_global_atk_speed_mult

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
	_setup_tier_decor()

func _setup_tier_decor() -> void:
	var c: Color = TIER_COLORS.get(tier, Color.WHITE)

	# Cast shadow on the battle-line stone. Wider + flatter than the tier ring,
	# drawn at world y ≈ spawn-line height so the hero reads as standing on the
	# parapet rather than floating above it.
	var cast_shadow := _make_ellipse(44.0, 6.0, Color(0, 0, 0, 0.5))
	cast_shadow.position = Vector2(0, 22)
	add_child(cast_shadow)
	move_child(cast_shadow, 0)

	# Base ring at feet — flat ellipse, drawn BEHIND the sprite so it reads
	# as a ground decal. Black outline for definition on light/dark backgrounds.
	var rx := 38.0
	var ry := 9.0
	var ring_outline := _make_ellipse(rx + 1.5, ry + 1.0, Color(0, 0, 0, 0.85))
	var ring_fill := _make_ellipse(rx, ry, Color(c.r, c.g, c.b, 0.95))
	for n in [ring_outline, ring_fill]:
		n.position = Vector2(0, 38)
		add_child(n)
		move_child(n, 0)  # behind sprite

	# Star pips above the head. 1/2/3 stars = bronze/silver/gold.
	var pip_count: int = TIER_PIPS.get(tier, 1)
	var pip_r := 7.0
	var pip_gap := 4.0
	var total_w: float = float(pip_count) * (pip_r * 2.0) + float(pip_count - 1) * pip_gap
	var start_x: float = -total_w * 0.5 + pip_r
	for i in pip_count:
		var pip := _make_star(pip_r, c)
		pip.position = Vector2(start_x + float(i) * (pip_r * 2.0 + pip_gap), -54)
		add_child(pip)

	# Gold-only pulsing aura behind the sprite. Cheap loop tween.
	if tier == "gold":
		var aura := _make_ellipse(46.0, 46.0, Color(c.r, c.g, c.b, 0.28))
		add_child(aura)
		move_child(aura, 0)
		var tw := create_tween().set_loops()
		tw.tween_property(aura, "modulate:a", 0.55, 0.9).set_trans(Tween.TRANS_SINE)
		tw.tween_property(aura, "modulate:a", 1.00, 0.9).set_trans(Tween.TRANS_SINE)

func _make_ellipse(rx: float, ry: float, color: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.color = color
	var pts := PackedVector2Array()
	var n := 28
	for i in n:
		var a: float = TAU * float(i) / float(n)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	poly.polygon = pts
	return poly

func _make_star(size: float, color: Color) -> Node2D:
	# 5-point star with a black outline poly behind a tier-colored fill.
	var holder := Node2D.new()
	var outline := Polygon2D.new()
	outline.color = Color(0, 0, 0, 0.9)
	outline.polygon = _star_points(size + 1.2)
	holder.add_child(outline)
	var fill := Polygon2D.new()
	fill.color = color
	fill.polygon = _star_points(size)
	holder.add_child(fill)
	return holder

func _star_points(size: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var outer: float = size
	var inner: float = size * 0.45
	for i in 10:
		var ang: float = -PI * 0.5 + TAU * float(i) / 10.0
		var r: float = outer if i % 2 == 0 else inner
		pts.append(Vector2(cos(ang) * r, sin(ang) * r))
	return pts

func _process(delta: float) -> void:
	_fire_timer += delta
	_breathe_timer += delta
	# Druid heal-cap window resets every game-second.
	if _heal_window_t > 0.0:
		_heal_window_t -= delta
		if _heal_window_t <= 0.0:
			_heal_received_this_sec = 0
	# Idle breathe — ~1Hz vertical bob on the sprite. Keeps heroes feeling alive
	# during Phase 1 (no firing, no enemies). Drives sprite.offset so it doesn't
	# fight any future knockback / scale tweens on the parent.
	if _sprite != null:
		# Stagger phase by hero_id so a wall of heroes doesn't breathe in unison.
		var phase: float = float(_hero_id % 1000) * 0.001 * TAU
		_sprite.offset.y = sin(_breathe_timer * BREATHE_FREQ_RAD + phase) * BREATHE_AMPLITUDE_PX
	if _fire_timer >= fire_rate_sec:
		_fire_timer = 0.0
		_try_fire()

func _try_fire() -> void:
	if lane_ref == null or not lane_ref.combat_enabled: return
	match color:
		GameConfig.BubbleColor.RED:    _fire_red()
		GameConfig.BubbleColor.BLUE:   _fire_blue()
		GameConfig.BubbleColor.YELLOW: _fire_yellow()
		GameConfig.BubbleColor.GREEN:  _fire_green()
		GameConfig.BubbleColor.PURPLE: _fire_purple()

# Final per-hit damage including frenzy + class boon + color counter +
# Berserker Rage (§4.2 boon: 2× dmg while below 30% HP).
func _damage_against(target: Enemy, class_dmg_mult: float) -> int:
	var dmg_f: float = float(damage) * damage_mult_global * damage_mult_class * class_dmg_mult
	if target.color == color:
		dmg_f *= GameConfig.color_counter_multiplier
	if RunState.boon_berserker_rage and _hp_ratio() < 0.30:
		dmg_f *= 2.0
	var dealt: int = int(round(dmg_f))
	# Vampiric Strike — heal 10% of damage dealt, capped at max HP.
	if RunState.boon_vampiric_strike and dealt > 0:
		hp = min(_max_hp(), hp + int(round(float(dealt) * 0.10)))
	return dealt

func _max_hp() -> int:
	return max_hp

func max_total_hp() -> int:
	return max_hp

func _hp_ratio() -> float:
	var m: int = _max_hp()
	if m <= 0: return 1.0
	return float(hp) / float(m)

# Tier-based volley: Bronze 1 shot, Silver 2 shots, Gold 3 shots. All shots
# in a volley target the SAME enemy. If the target dies mid-volley, remaining
# shots are skipped (the volley is locked to the primary target).
func _tier_shot_count() -> int:
	match tier:
		"silver": return 2
		"gold":   return 3
		_:        return 1

# ----- Fire Knight (RED): cone + chance to cleave row neighbors -----
func _fire_red() -> void:
	var target: Enemy = lane_ref.find_target_red(self)
	if target == null: return
	# One lunge per attack tick. Then N staggered slashes on the SAME target;
	# remaining slashes are dropped if the target dies before they fire.
	var dir0: Vector2 = (target.global_position - global_position).normalized()
	_vfx_red_lunge(dir0)
	_red_slash_shot(target)
	for i in range(1, _tier_shot_count()):
		var captured: Enemy = target
		get_tree().create_timer(0.10 * float(i)).timeout.connect(func():
			if is_instance_valid(captured): _red_slash_shot(captured))
	# Cleave RNG fires once per attack tick (not per shot) on the primary target.
	if randf() < GameConfig.red_cleave_chance:
		_red_cleave_proc(target)

# One slash on one target — slash arc + heat wedge + impact sparks + damage.
# Lunge is handled separately by _fire_red so multi-shot volleys don't stack lunges.
func _red_slash_shot(target: Enemy) -> void:
	if not is_instance_valid(target): return
	var dir: Vector2 = (target.global_position - global_position).normalized()
	_vfx_red_slash(dir, 130.0, Color(1.0, 0.55, 0.20, 0.92))
	_vfx_red_wedge(dir, 150.0, 45.0, Color(1.0, 0.35, 0.18, 0.30), 0.20)
	_vfx_impact_sparks(target.global_position,
		Color(1.0, 0.7, 0.25, 1.0), 8, 36.0)
	var dmg: int = _damage_against(target, GameConfig.red_dmg_mult)
	var is_crit: bool = target.color == color
	var target_pos: Vector2 = target.position
	target.take_damage(dmg, color)
	_spawn_damage_number(target_pos, dmg, is_crit)
	if is_crit:
		Vfx.color_counter_badge(lane_ref, target_pos, Vfx.color_for_bubble(color))
	_damage_dealt_total += dmg
	Telemetry.log_hero_attack(_hero_id, target.get_instance_id(), dmg)

# RNG cleave proc — hits row neighbors in cone with narrower secondary wedges.
func _red_cleave_proc(primary: Enemy) -> void:
	if not is_instance_valid(primary): return
	var cleaved: int = 0
	Vfx.floating_badge(lane_ref, position + Vector2(0, -70),
		"CLEAVE!", Color(1.0, 0.55, 0.20))
	for e in lane_ref._enemies:
		if cleaved >= GameConfig.red_cleave_targets: break
		if e == null or not is_instance_valid(e): continue
		if e == primary: continue
		if e.lane_row != primary.lane_row: continue
		if abs(e.lane_col - lane_col) > GameConfig.red_cone_cols: continue
		var c_dir: Vector2 = (e.global_position - global_position).normalized()
		_vfx_red_wedge(c_dir, 90.0, 22.0,
			Color(1.0, 0.55, 0.20, 0.45), 0.14)
		var cd: int = _damage_against(e, GameConfig.red_dmg_mult)
		var c_crit: bool = e.color == color
		var c_pos: Vector2 = e.position
		e.take_damage(cd, color)
		_spawn_damage_number(c_pos, cd, c_crit)
		if c_crit:
			Vfx.color_counter_badge(lane_ref, c_pos, Vfx.color_for_bubble(color))
		_damage_dealt_total += cd
		cleaved += 1

# ----- Ice Mage (BLUE): lob + AoE splash + slow -----
func _fire_blue() -> void:
	var target: Enemy = lane_ref.find_target_blue(self)
	if target == null: return
	_blue_lob_shot(target)
	for i in range(1, _tier_shot_count()):
		var captured: Enemy = target
		get_tree().create_timer(0.12 * float(i)).timeout.connect(func():
			if is_instance_valid(captured): _blue_lob_shot(captured))

# One ice-lob on one target — independent crystal + AoE splash + slow per shot.
func _blue_lob_shot(target: Enemy) -> void:
	if not is_instance_valid(target): return
	var primary_dmg: int = _damage_against(target, GameConfig.blue_dmg_mult)
	_vfx_blue_lob(target)
	# AoE: every enemy within blue_aoe_radius_cells of the target takes same dmg + slow.
	var splash: Array = lane_ref.enemies_in_aoe(target.position, GameConfig.blue_aoe_radius_cells)
	for e in splash:
		if e == null or not is_instance_valid(e): continue
		var d: int = primary_dmg if e == target else _damage_against(e, GameConfig.blue_dmg_mult)
		var e_crit: bool = e.color == color
		var e_pos: Vector2 = e.position
		e.take_damage(d, color)
		_spawn_damage_number(e_pos, d, e_crit)
		if e_crit:
			Vfx.color_counter_badge(lane_ref, e_pos, Vfx.color_for_bubble(color))
		if is_instance_valid(e):
			e.apply_slow()
		_damage_dealt_total += d
	Telemetry.log_hero_attack(_hero_id, target.get_instance_id(), primary_dmg)

# ----- Archer (YELLOW): straight shot + execute under-30% bonus -----
func _fire_yellow() -> void:
	var target: Enemy = lane_ref.find_target_yellow(self)
	if target == null: return
	# Bowstring recoil once per attack tick (single release for the whole volley).
	var dir0: Vector2 = (target.global_position - global_position).normalized()
	var rec := create_tween()
	rec.tween_property(self, "position", position - dir0 * 5.0, 0.05)
	rec.tween_property(self, "position", position, 0.12)
	_yellow_arrow_shot(target)
	for i in range(1, _tier_shot_count()):
		var captured: Enemy = target
		get_tree().create_timer(0.08 * float(i)).timeout.connect(func():
			if is_instance_valid(captured): _yellow_arrow_shot(captured))

# One arrow on one target — independent damage + VFX per shot.
func _yellow_arrow_shot(target: Enemy) -> void:
	if not is_instance_valid(target): return
	var dmg_f: float = float(damage) * damage_mult_global * damage_mult_class * GameConfig.yellow_dmg_mult
	if target.color == color:
		dmg_f *= GameConfig.color_counter_multiplier
	var enemy_max_hp: int = _enemy_max_hp(target)
	var is_execute: bool = enemy_max_hp > 0 and (float(target.hp) / float(enemy_max_hp)) < GameConfig.yellow_execute_threshold
	if is_execute:
		dmg_f *= (1.0 + GameConfig.yellow_execute_bonus)
	var dmg: int = int(round(dmg_f))
	var is_color_counter: bool = target.color == color
	var is_crit: bool = is_execute or is_color_counter
	var target_pos: Vector2 = target.position
	_vfx_yellow_shot(target, is_execute)
	target.take_damage(dmg, color)
	_spawn_damage_number(target_pos, dmg, is_crit)
	if is_color_counter:
		Vfx.color_counter_badge(lane_ref, target_pos, Vfx.color_for_bubble(color))
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
	# Sword strike: lunge forward, swing a glowing crescent slash, spark on impact.
	var dir: Vector2 = (target.global_position - global_position).normalized()
	_vfx_red_lunge(dir)
	_vfx_red_slash(dir, 110.0, Color(1.0, 0.55, 0.20, 0.92))
	# Wide secondary heat-haze wedge for the cone area-of-effect signal.
	_vfx_red_wedge(dir, 130.0, 45.0, Color(1.0, 0.35, 0.18, 0.30), 0.20)
	# Impact sparks at target.
	if is_instance_valid(target):
		_vfx_impact_sparks(target.global_position,
			Color(1.0, 0.7, 0.25, 1.0), 8, 36.0)


# Brief forward lunge toward an attack direction. Factored out so cleave
# secondaries can fire wedges without re-lunging per target.
func _vfx_red_lunge(dir: Vector2) -> void:
	var tw := create_tween()
	tw.tween_property(self, "position", position + dir * 8.0, 0.06)
	tw.tween_property(self, "position", position, 0.12)


# Sword slash — glowing crescent arc that sweeps across the swing direction.
# Built from two stacked arcs (outer warm orange + inner white-hot core) so the
# blade reads as molten steel rather than a flat shape.
func _vfx_red_slash(dir: Vector2, reach: float, color: Color) -> void:
	var holder := Node2D.new()
	holder.rotation = dir.angle()
	add_child(holder)
	# Outer crescent (wider, dimmer).
	var outer := _make_crescent(reach, 18.0, deg_to_rad(70.0),
		Color(color.r, color.g, color.b, color.a * 0.85))
	holder.add_child(outer)
	# Inner core (narrower, white-hot).
	var inner := _make_crescent(reach * 0.92, 8.0, deg_to_rad(55.0),
		Color(1.0, 0.95, 0.78, 0.95))
	holder.add_child(inner)
	# Sweep the holder through the swing arc — start angled "up", rotate down.
	holder.rotation = dir.angle() - deg_to_rad(35.0)
	var tw := holder.create_tween()
	tw.tween_property(holder, "rotation",
		dir.angle() + deg_to_rad(35.0), 0.14) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(holder, "modulate:a", 0.0, 0.22) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		if is_instance_valid(holder): holder.queue_free())


# Curved crescent ring segment from -half_arc..+half_arc at the given radius,
# `thickness` px wide. Used as a sword-slash trail.
func _make_crescent(radius: float, thickness: float, half_arc: float,
		color: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.color = color
	var pts := PackedVector2Array()
	var steps := 14
	# Outer arc (radius + thickness/2) sweeping +arc.
	for i in steps + 1:
		var t: float = -half_arc + 2.0 * half_arc * float(i) / float(steps)
		pts.append(Vector2(cos(t), sin(t)) * (radius + thickness * 0.5))
	# Inner arc (radius - thickness/2) sweeping back.
	for i in steps + 1:
		var t: float = half_arc - 2.0 * half_arc * float(i) / float(steps)
		pts.append(Vector2(cos(t), sin(t)) * (radius - thickness * 0.5))
	poly.polygon = pts
	return poly


# Red wedge — short-lived Polygon2D pie slice drawn in front of the hero.
# Used as the area-of-effect ghost behind the slash and for cleave secondaries.
func _vfx_red_wedge(dir: Vector2, reach: float, half_deg: float,
		color: Color, fade_dur: float) -> void:
	var wedge := Polygon2D.new()
	wedge.color = color
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
	var tw := wedge.create_tween()
	tw.tween_property(wedge, "modulate:a", 0.0, fade_dur) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		if is_instance_valid(wedge): wedge.queue_free())


# Radial spark burst at world position — small bright shards flying outward.
# Used for impact moments on red/yellow attacks.
func _vfx_impact_sparks(world_pos: Vector2, color: Color,
		count: int, reach: float) -> void:
	if lane_ref == null or not is_instance_valid(lane_ref): return
	var local := lane_ref.to_local(world_pos)
	for i in count:
		var spark := Polygon2D.new()
		spark.color = color
		var sz: float = randf_range(2.5, 4.5)
		spark.polygon = PackedVector2Array([
			Vector2(-sz * 0.4, -sz), Vector2(sz * 0.4, -sz),
			Vector2(sz * 0.4, sz), Vector2(-sz * 0.4, sz),
		])
		spark.z_index = 65
		lane_ref.add_child(spark)
		spark.position = local
		var ang: float = TAU * float(i) / float(count) + randf_range(-0.3, 0.3)
		var dist: float = randf_range(reach * 0.5, reach)
		var dest: Vector2 = local + Vector2(cos(ang), sin(ang)) * dist
		spark.rotation = ang
		var dur: float = randf_range(0.18, 0.28)
		var tw := spark.create_tween()
		tw.tween_property(spark, "position", dest, dur) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(spark, "scale", Vector2(0.2, 0.2), dur)
		tw.parallel().tween_property(spark, "modulate:a", 0.0, dur)
		tw.tween_callback(func():
			if is_instance_valid(spark): spark.queue_free())

func _vfx_blue_lob(target: Enemy) -> void:
	# Chunky glowing ice crystal arcs from hero to target, leaves a sparkle trail,
	# detonates into a radial shard burst + expanding ring on impact.
	var shard: Node2D = _make_ice_crystal(20.0)
	get_parent().add_child(shard)  # parent = Lane (so global_position works directly)
	shard.global_position = global_position
	var p0: Vector2 = global_position
	var p2: Vector2 = target.global_position
	var ring_local_pos: Vector2 = target.position  # capture NOW — target may die mid-flight
	var ring_world_pos: Vector2 = target.global_position
	var mid: Vector2 = (p0 + p2) * 0.5
	mid.y -= 50.0  # arc apex above straight line
	# Slight scale-in pop so the crystal "appears" rather than blinking on.
	shard.scale = Vector2(0.5, 0.5)
	var spawn_tw := shard.create_tween()
	spawn_tw.tween_property(shard, "scale", Vector2(1.0, 1.0), 0.06) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var sh_tween := create_tween()
	var last_trail_t: Array = [0.0]
	sh_tween.tween_method(func(t: float):
		if not is_instance_valid(shard): return
		var u: float = 1.0 - t
		shard.global_position = u * u * p0 + 2.0 * u * t * mid + t * t * p2
		# Tumble the crystal — a clean spin reads better than a wobble.
		shard.rotation = (p2 - p0).angle() + t * TAU * 1.5
		# Sparkle trail — drop a fading dot every ~0.025 of progress.
		if t - last_trail_t[0] >= 0.05:
			last_trail_t[0] = t
			_spawn_blue_trail_dot(shard.global_position)
	, 0.0, 1.0, 0.45)
	sh_tween.tween_callback(func():
		if is_instance_valid(shard): shard.queue_free()
		_spawn_blue_aoe_ring(ring_local_pos)
		_spawn_blue_shatter(ring_world_pos))


# Multi-layered ice crystal — bright white core inside translucent cyan body
# inside a soft outer halo. Reads as a glowing gem, not a flat triangle.
func _make_ice_crystal(size: float) -> Node2D:
	var holder := Node2D.new()
	# Outer halo (large, faint).
	var halo := Polygon2D.new()
	halo.color = Color(0.55, 0.85, 1.0, 0.28)
	halo.polygon = _diamond_points(size * 1.7, size * 1.3)
	holder.add_child(halo)
	# Body (cyan, semi-opaque).
	var body := Polygon2D.new()
	body.color = Color(0.40, 0.78, 1.0, 0.95)
	body.polygon = _diamond_points(size, size * 0.75)
	holder.add_child(body)
	# Hot core (white).
	var core := Polygon2D.new()
	core.color = Color(0.92, 0.98, 1.0, 0.95)
	core.polygon = _diamond_points(size * 0.5, size * 0.36)
	holder.add_child(core)
	return holder


# Four-pointed diamond/lozenge points used to build ice-crystal layers.
func _diamond_points(rx: float, ry: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0, -ry),
		Vector2(rx, 0),
		Vector2(0, ry),
		Vector2(-rx, 0),
	])


# Tiny cyan sparkle dropped behind the flying ice crystal. Lives ~0.25s.
func _spawn_blue_trail_dot(world_pos: Vector2) -> void:
	if lane_ref == null or not is_instance_valid(lane_ref): return
	var dot := Polygon2D.new()
	dot.color = Color(0.75, 0.95, 1.0, 0.85)
	var s: float = randf_range(2.0, 3.5)
	dot.polygon = _diamond_points(s, s)
	dot.z_index = 55
	lane_ref.add_child(dot)
	dot.position = lane_ref.to_local(world_pos)
	dot.rotation = randf() * TAU
	var tw := dot.create_tween()
	tw.tween_property(dot, "scale", Vector2(0.1, 0.1), 0.28) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(dot, "modulate:a", 0.0, 0.28)
	tw.tween_callback(func():
		if is_instance_valid(dot): dot.queue_free())


# Impact shatter — 6 small ice fragments flying outward from the hit point.
func _spawn_blue_shatter(world_pos: Vector2) -> void:
	if lane_ref == null or not is_instance_valid(lane_ref): return
	var local := lane_ref.to_local(world_pos)
	var n := 6
	for i in n:
		var shard := Polygon2D.new()
		shard.color = Color(0.70, 0.92, 1.0, 0.95)
		var sz: float = randf_range(4.0, 7.0)
		shard.polygon = _diamond_points(sz * 0.5, sz)
		shard.z_index = 62
		lane_ref.add_child(shard)
		shard.position = local
		var ang: float = TAU * float(i) / float(n) + randf_range(-0.2, 0.2)
		var dist: float = randf_range(30.0, 50.0)
		shard.rotation = ang + PI * 0.5
		var dest: Vector2 = local + Vector2(cos(ang), sin(ang)) * dist
		var dur: float = randf_range(0.22, 0.32)
		var tw := shard.create_tween()
		tw.tween_property(shard, "position", dest, dur) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(shard, "rotation",
			shard.rotation + randf_range(-PI, PI), dur)
		tw.parallel().tween_property(shard, "scale", Vector2(0.2, 0.2), dur)
		tw.parallel().tween_property(shard, "modulate:a", 0.0, dur)
		tw.tween_callback(func():
			if is_instance_valid(shard): shard.queue_free())

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
	# Real arrow projectile: shaft + fletching + head, flies hero → target with
	# a fading streak trail. Execute shots are larger and glow hotter.
	# Note: bowstring recoil happens once-per-attack-tick in _fire_yellow,
	# not here (so a Silver/Gold volley doesn't stack N recoils).
	var p0: Vector2 = global_position
	var p1: Vector2 = target.global_position
	var dir: Vector2 = (p1 - p0).normalized()
	# Build arrow as a Node2D so it rotates as a rigid body.
	var arrow_color := Color(1.0, 0.85, 0.20, 1.0) if not is_execute \
		else Color(1.0, 0.95, 0.55, 1.0)
	var arrow := _make_arrow(26.0 if not is_execute else 32.0, arrow_color)
	arrow.z_index = 75
	get_parent().add_child(arrow)  # parent = Lane
	arrow.global_position = p0
	arrow.rotation = dir.angle()
	# Flight: linear interp, slight constant rotation jitter would look wrong on
	# an arrow, so we lock the angle to flight direction.
	var flight_dur: float = clamp((p1 - p0).length() / 600.0, 0.18, 0.40)
	var last_trail_t: Array = [0.0]
	var tw := create_tween()
	tw.tween_method(func(t: float):
		if not is_instance_valid(arrow): return
		arrow.global_position = p0.lerp(p1, t)
		if t - last_trail_t[0] >= 0.12:
			last_trail_t[0] = t
			_spawn_yellow_trail_streak(arrow.global_position, dir, arrow_color)
	, 0.0, 1.0, flight_dur)
	tw.tween_callback(func():
		# Stick the arrow into the target briefly, then fade.
		if is_instance_valid(arrow):
			var stick_tw := arrow.create_tween()
			stick_tw.tween_interval(0.10 if not is_execute else 0.16)
			stick_tw.tween_property(arrow, "modulate:a", 0.0, 0.10)
			stick_tw.tween_callback(func():
				if is_instance_valid(arrow): arrow.queue_free())
		# Impact: spark burst at target.
		_vfx_impact_sparks(p1, arrow_color, 6 if not is_execute else 10,
			32.0 if not is_execute else 44.0)
		# Target flash.
		if is_instance_valid(target):
			var orig_mod: Color = target.modulate
			var flash_color := Color(1, 1, 1, 1) if not is_execute \
				else Color(1.3, 1.2, 0.6, 1)
			target.modulate = flash_color
			var ft := get_tree().create_timer(0.08)
			ft.timeout.connect(func():
				if is_instance_valid(target):
					target.modulate = orig_mod))


# Arrow visual: dark shaft, golden fletching at the back, sharp head at the front.
# All in local space pointing along +X so the parent's rotation aligns with flight.
func _make_arrow(length: float, color: Color) -> Node2D:
	var holder := Node2D.new()
	var half_len: float = length * 0.5
	# Shaft.
	var shaft := Polygon2D.new()
	shaft.color = Color(0.28, 0.20, 0.12, 1.0)
	shaft.polygon = PackedVector2Array([
		Vector2(-half_len, -1.6), Vector2(half_len - 4.0, -1.6),
		Vector2(half_len - 4.0, 1.6), Vector2(-half_len, 1.6),
	])
	holder.add_child(shaft)
	# Head (triangle pointing +X).
	var head := Polygon2D.new()
	head.color = Color(0.92, 0.92, 0.95, 1.0)
	head.polygon = PackedVector2Array([
		Vector2(half_len, 0),
		Vector2(half_len - 7.0, -4.0),
		Vector2(half_len - 7.0, 4.0),
	])
	holder.add_child(head)
	# Glow tip — slightly translucent tier-color blob behind the head.
	var glow := Polygon2D.new()
	glow.color = Color(color.r, color.g, color.b, 0.6)
	glow.polygon = PackedVector2Array([
		Vector2(half_len + 2.0, 0),
		Vector2(half_len - 9.0, -6.0),
		Vector2(half_len - 9.0, 6.0),
	])
	holder.add_child(glow)
	holder.move_child(glow, 0)  # behind head
	# Fletching — two small triangles at the back.
	for sign_y in [-1.0, 1.0]:
		var fl := Polygon2D.new()
		fl.color = color
		fl.polygon = PackedVector2Array([
			Vector2(-half_len, 0),
			Vector2(-half_len + 6.0, 0),
			Vector2(-half_len + 2.0, 4.0 * sign_y),
		])
		holder.add_child(fl)
	return holder


# Short fading streak left behind the arrow each tick. Drawn perpendicular-free
# (just a short line in flight direction) so it reads as motion blur.
func _spawn_yellow_trail_streak(world_pos: Vector2, dir: Vector2,
		color: Color) -> void:
	if lane_ref == null or not is_instance_valid(lane_ref): return
	var streak := Polygon2D.new()
	streak.color = Color(color.r, color.g, color.b, 0.55)
	streak.polygon = PackedVector2Array([
		Vector2(-10.0, -1.2), Vector2(0, -1.2),
		Vector2(0, 1.2), Vector2(-10.0, 1.2),
	])
	streak.rotation = dir.angle()
	streak.z_index = 60
	lane_ref.add_child(streak)
	streak.position = lane_ref.to_local(world_pos)
	var tw := streak.create_tween()
	tw.tween_property(streak, "modulate:a", 0.0, 0.18)
	tw.parallel().tween_property(streak, "scale", Vector2(0.3, 0.3), 0.18)
	tw.tween_callback(func():
		if is_instance_valid(streak): streak.queue_free())

# Spawn a floating damage number above the given lane-local position.
# Parents on lane_ref so the label survives the target's queue_free().
func _spawn_damage_number(local_pos: Vector2, amount: int, is_crit: bool) -> void:
	if lane_ref == null or not is_instance_valid(lane_ref): return
	var col: Color = Vfx.color_for_bubble(color)
	Vfx.damage_number(lane_ref, local_pos, amount, col, is_crit)


func take_damage(amount: int) -> void:
	# §8.3 Storm Tyrant electrified column multiplier.
	if damage_taken_mult != 1.0:
		amount = int(round(float(amount) * damage_taken_mult))
	hp -= amount
	if hp <= 0:
		# Death burst parented on Lane so it outlives our queue_free().
		if get_parent() != null:
			Vfx.death_burst(get_parent(), global_position, Vfx.color_for_bubble(color))
		Telemetry.log_hero_death(_hero_id, color, tier,
			Time.get_ticks_msec() - _spawn_ms, _damage_dealt_total)
		emit_signal("died", _hero_id, color, tier,
			Time.get_ticks_msec() - _spawn_ms, _damage_dealt_total)
		queue_free()

func apply_frenzy_buff() -> void:
	damage_mult_global = 1.0 + GameConfig.color_frenzy_buff_pct
	var t := get_tree().create_timer(GameConfig.color_frenzy_duration_sec)
	t.timeout.connect(func(): damage_mult_global = 1.0)

# ============================================================
# §8.4 Druid (GREEN) — basic attack + chain heal on allies
# §8.6 Wizard (PURPLE) — full-lane shot + AOE every Nth hit
# ============================================================
func _fire_green() -> void:
	if lane_ref == null: return
	var target: Enemy = lane_ref.find_target_green(self)
	if target == null:
		# No enemy to hit, but still cast a heal pulse if any ally needs it.
		lane_ref.druid_chain_heal(self)
		return
	var dmg: int = _damage_against(target, GameConfig.green_dmg_mult)
	var is_crit: bool = target.color == color
	var target_pos: Vector2 = target.position
	_vfx_red_wedge((target.global_position - global_position).normalized(),
		95.0, 30.0, Color(0.45, 1.0, 0.55, 0.45), 0.18)
	target.take_damage(dmg, color)
	_spawn_damage_number(target_pos, dmg, is_crit)
	if is_crit:
		Vfx.color_counter_badge(lane_ref, target_pos, Vfx.color_for_bubble(color))
	_damage_dealt_total += dmg
	Telemetry.log_hero_attack(_hero_id, target.get_instance_id(), dmg)
	# Chain heal — fires on every attack tick (capped per ally per game-second).
	lane_ref.druid_chain_heal(self)

func _fire_purple() -> void:
	if lane_ref == null: return
	var target: Enemy = lane_ref.find_target_purple(self)
	if target == null: return
	var dmg: int = _damage_against(target, GameConfig.purple_dmg_mult)
	var target_pos: Vector2 = target.position
	# Big AOE smash visual.
	_vfx_red_wedge((target.global_position - global_position).normalized(),
		160.0, 60.0, Color(0.75, 0.45, 0.95, 0.40), 0.22)
	target.take_damage(dmg, color)
	_spawn_damage_number(target_pos, dmg, target.color == color)
	_damage_dealt_total += dmg
	Telemetry.log_hero_attack(_hero_id, target.get_instance_id(), dmg)
	_wizard_attack_count += 1
	if _wizard_attack_count >= GameConfig.purple_burst_every_n_hits:
		_wizard_attack_count = 0
		_wizard_arcane_burst(target)

func _wizard_arcane_burst(primary: Enemy) -> void:
	if lane_ref == null or not is_instance_valid(primary): return
	var splash: Array = lane_ref.enemies_in_aoe(primary.position,
		GameConfig.purple_aoe_radius_cells)
	# Burst halo VFX.
	var ring := Polygon2D.new()
	ring.color = Color(0.85, 0.5, 1.0, 0.55)
	var pts := PackedVector2Array()
	var radius: float = GameConfig.purple_aoe_radius_cells * Lane.CELL_H
	for i in 24:
		var a: float = TAU * float(i) / 24.0
		pts.append(Vector2(cos(a), sin(a)) * radius)
	ring.polygon = pts
	lane_ref.add_child(ring)
	ring.position = primary.position
	ring.scale = Vector2(0.15, 0.15)
	var tw := ring.create_tween()
	tw.tween_property(ring, "scale", Vector2(1.1, 1.1), 0.22) \
		.set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.28)
	tw.tween_callback(func():
		if is_instance_valid(ring): ring.queue_free())
	for e in splash:
		if e == null or not is_instance_valid(e): continue
		if e == primary: continue
		var d: int = _damage_against(e, GameConfig.purple_dmg_mult)
		e.take_damage(d, color)
		_spawn_damage_number(e.position, d, e.color == color)
		_damage_dealt_total += d
	Vfx.floating_badge(lane_ref, position + Vector2(0, -60),
		"ARCANE!", Color(0.85, 0.5, 1.0))

# Druid uses this from Lane.druid_chain_heal. Returns actual amount healed
# (after per-second cap is applied so we never out-heal cap).
func try_heal(amount: int, cap_per_sec: int) -> int:
	if hp >= max_hp: return 0
	# Reset accumulator every game-second.
	if _heal_window_t <= 0.0:
		_heal_received_this_sec = 0
		_heal_window_t = 1.0
	var remaining_cap: int = max(0, cap_per_sec - _heal_received_this_sec)
	if remaining_cap <= 0: return 0
	var space: int = max_hp - hp
	var ticked: int = min(amount, min(remaining_cap, space))
	if ticked <= 0: return 0
	hp += ticked
	_heal_received_this_sec += ticked
	return ticked
