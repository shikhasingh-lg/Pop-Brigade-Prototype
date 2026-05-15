# Enemy — single enemy unit marching down the lane.
# Design spec §3.6 + §3.10 + §8.x variants.

class_name Enemy
extends Node2D

signal reached_cannon(enemy_id: int, color: int, hp_damage: int)
signal died(enemy_id: int, color: int, killed_by_color: int, lifetime_ms: int)

@export_enum("Red", "Blue", "Yellow", "Green", "Purple") var color: int = 0
@export var lane_col: int = 0
var lane_row: int = 0
var lane_ref: Lane = null

# Variant tag: "walker"|"runner"|"brute"|"shielder"|"healer"|"accelerator"|"phaser".
var variant: String = "walker"
# Realm + stage drive scaling (§3.10.4). Lane sets these BEFORE _ready().
var realm_num: int = 1
var stage_num: int = 1

# §4.3 boss flag.
var is_boss: bool = false
var boss_hp_override: int = 0
var boss_damage_override: int = 0

# §8.x — variant state
var shield_hits_remaining: int = 0
var is_healer: bool = false
var is_accelerator: bool = false
var is_phaser: bool = false
var _heal_tick_accum: float = 0.0
var _phase_skip_timer: float = 0.0
# Speed-buff (Accelerator legacy) — applied externally via apply_speed_buff().
var _speed_buff_factor: float = 1.0
var _speed_buff_timer: float = 0.0

var hp: int = 50
var max_hp: int = 50
var speed_sec_per_cell: float = 1.0
var damage_on_reach: int = 10
var _move_timer: float = 0.0
var _spawn_ms: int = 0
var _enemy_id: int = 0
var _slow_factor: float = 1.0  # 1.0 = normal, 0.7 = 30% slowed (Blue hero debuff)
var _slow_timer: float = 0.0
var _reached: bool = false

@onready var _sprite: Sprite2D = $Sprite
var _hp_bar_bg: ColorRect = null
var _hp_bar_fill: ColorRect = null

# Target on-lane footprint (px). Slightly smaller than heroes to read as a threat.
const _ENEMY_DISPLAY_PX := 78.0
# Per-enemy HP bar dims (drawn above the sprite when HP < max).
const _HP_BAR_WIDTH := 56.0
const _HP_BAR_HEIGHT := 5.0
const _HP_BAR_Y_OFFSET := -52.0  # above the sprite

func _ready() -> void:
	_spawn_ms = Time.get_ticks_msec()
	_enemy_id = get_instance_id()
	_apply_color_stats()
	_apply_visual()
	_setup_hp_bar()

func _setup_hp_bar() -> void:
	# Bar drawn as two stacked ColorRects parented to the enemy so it follows
	# the enemy's lane-tween automatically. Hidden until first damage.
	_hp_bar_bg = ColorRect.new()
	_hp_bar_bg.color = Color(0, 0, 0, 0.55)
	_hp_bar_bg.size = Vector2(_HP_BAR_WIDTH, _HP_BAR_HEIGHT)
	_hp_bar_bg.position = Vector2(-_HP_BAR_WIDTH * 0.5, _HP_BAR_Y_OFFSET)
	_hp_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_bar_bg.visible = false
	add_child(_hp_bar_bg)
	_hp_bar_fill = ColorRect.new()
	_hp_bar_fill.color = Color(0.88, 0.30, 0.30, 0.95)
	_hp_bar_fill.size = Vector2(_HP_BAR_WIDTH, _HP_BAR_HEIGHT)
	_hp_bar_fill.position = Vector2(-_HP_BAR_WIDTH * 0.5, _HP_BAR_Y_OFFSET)
	_hp_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_bar_fill.visible = false
	add_child(_hp_bar_fill)

func _apply_color_stats() -> void:
	var base_hp: float
	var base_speed: float
	var base_dmg: float
	match color:
		GameConfig.BubbleColor.RED:
			base_hp = float(GameConfig.red_enemy_hp)
			base_speed = GameConfig.red_enemy_speed_sec_per_cell
			base_dmg = float(GameConfig.red_enemy_damage_on_reach)
		GameConfig.BubbleColor.BLUE:
			base_hp = float(GameConfig.blue_enemy_hp)
			base_speed = GameConfig.blue_enemy_speed_sec_per_cell
			base_dmg = float(GameConfig.blue_enemy_damage_on_reach)
		GameConfig.BubbleColor.YELLOW:
			base_hp = float(GameConfig.yellow_enemy_hp)
			base_speed = GameConfig.yellow_enemy_speed_sec_per_cell
			base_dmg = float(GameConfig.yellow_enemy_damage_on_reach)
		GameConfig.BubbleColor.GREEN:
			base_hp = float(GameConfig.green_enemy_hp)
			base_speed = GameConfig.green_enemy_speed_sec_per_cell
			base_dmg = float(GameConfig.green_enemy_damage_on_reach)
		GameConfig.BubbleColor.PURPLE:
			base_hp = float(GameConfig.purple_enemy_hp)
			base_speed = GameConfig.purple_enemy_speed_sec_per_cell
			base_dmg = float(GameConfig.purple_enemy_damage_on_reach)
		_:
			base_hp = 50.0; base_speed = 1.0; base_dmg = 10.0
	# Variant multipliers (§3.2 + §3.10.5).
	match variant:
		"runner":
			base_hp *= GameConfig.runner_hp_mult
			base_speed *= GameConfig.runner_speed_mult
		"brute":
			base_hp *= GameConfig.brute_hp_mult
			base_speed *= GameConfig.brute_speed_mult
			base_dmg *= GameConfig.brute_dmg_mult
		"shielder":
			base_hp *= GameConfig.shielder_hp_mult
			base_speed *= GameConfig.shielder_speed_mult
			shield_hits_remaining = GameConfig.shielder_shield_hits
		"healer":
			base_hp *= GameConfig.healer_hp_mult
			is_healer = true
		"accelerator":
			is_accelerator = true
		"phaser":
			is_phaser = true
			_phase_skip_timer = randf_range(
				GameConfig.phaser_phase_interval_min_sec,
				GameConfig.phaser_phase_interval_max_sec
			)
		_:
			pass
	# §3.10.4 realm + stage scalars.
	base_hp *= GameConfig.get_realm_hp_mult(realm_num) * GameConfig.get_stage_hp_mult(stage_num)
	base_dmg *= GameConfig.get_realm_dmg_mult(realm_num) * GameConfig.get_stage_dmg_mult(stage_num)
	base_speed *= GameConfig.get_realm_speed_mult(realm_num) * GameConfig.get_stage_speed_mult(stage_num)
	# Boss overrides (any realm's S5 path + R5S3 mini-boss).
	if is_boss:
		if boss_hp_override > 0: base_hp = float(boss_hp_override)
		if boss_damage_override > 0: base_dmg = float(boss_damage_override)
		base_speed *= 1.5
		scale = Vector2(1.6, 1.6)
	hp = int(round(base_hp))
	max_hp = hp
	speed_sec_per_cell = base_speed
	damage_on_reach = int(round(base_dmg))

func get_max_hp() -> int:
	return max_hp

func _apply_visual() -> void:
	if _sprite == null: return
	# Pull cutout for this color (or boss if flagged).
	var slug: String = ""
	if is_boss:
		slug = EnemyRoster.boss_slug()
	else:
		var entry: Dictionary = EnemyRoster.get_for_color(color)
		if not entry.is_empty():
			slug = entry["slug"]
	if slug != "":
		var tex: Texture2D = EnemyRoster.get_cutout(slug)
		if tex != null:
			_sprite.texture = tex
			var max_dim: int = max(tex.get_width(), tex.get_height())
			if max_dim > 0:
				var fit: float = _ENEMY_DISPLAY_PX / float(max_dim)
				_sprite.scale = Vector2(fit, fit)
	# Variant visual cues (on top of texture scale).
	match variant:
		"runner":
			scale = Vector2(0.85, 0.85)
			_sprite.modulate = Color(1.15, 1.15, 1.10, 1.0)
		"brute":
			scale = Vector2(1.4, 1.4)
			_sprite.modulate = Color(0.75, 0.75, 0.85, 1.0)
		"shielder":
			# Adds a translucent cyan halo behind the sprite per shield charge.
			_decorate_shielder()
		"healer":
			# Green wisp halo + brighter tint.
			_decorate_healer()
		"accelerator":
			# Red speed trail tint.
			_sprite.modulate = Color(1.25, 0.85, 0.85, 1.0)
		"phaser":
			# Ghostly — slightly transparent + purple tint.
			_sprite.modulate = Color(1.1, 0.85, 1.2, 0.78)
		_:
			pass

func _decorate_shielder() -> void:
	var halo := ColorRect.new()
	halo.color = Color(0.4, 0.85, 1.0, 0.32)
	halo.size = Vector2(80, 80)
	halo.position = Vector2(-40, -40)
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	halo.z_index = -1
	add_child(halo)
	move_child(halo, 0)

func _decorate_healer() -> void:
	var wisp := ColorRect.new()
	wisp.color = Color(0.35, 1.0, 0.45, 0.30)
	wisp.size = Vector2(72, 72)
	wisp.position = Vector2(-36, -36)
	wisp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wisp.z_index = -1
	add_child(wisp)
	move_child(wisp, 0)
	if _sprite != null:
		_sprite.modulate = Color(0.85, 1.20, 0.85, 1.0)

func _process(delta: float) -> void:
	if _reached: return
	if _slow_timer > 0:
		_slow_timer -= delta
		if _slow_timer <= 0:
			_slow_factor = 1.0
	# §8.5 Accelerator buff window expires.
	if _speed_buff_timer > 0.0:
		_speed_buff_timer -= delta
		if _speed_buff_timer <= 0.0:
			_speed_buff_factor = 1.0
	# §8.4 Healer pulse: tick every 1s, heal nearest enemy within radius.
	if is_healer and lane_ref != null:
		_heal_tick_accum += delta
		if _heal_tick_accum >= 1.0:
			_heal_tick_accum = 0.0
			_do_heal_pulse()
	# §8.6 Phaser: random row-skip every 4-6s.
	if is_phaser:
		_phase_skip_timer -= delta
		if _phase_skip_timer <= 0.0:
			_phase_skip_timer = randf_range(
				GameConfig.phaser_phase_interval_min_sec,
				GameConfig.phaser_phase_interval_max_sec
			)
			_phase_skip()
	_move_timer += delta * _slow_factor * _speed_buff_factor
	if _move_timer >= Lane.ENEMY_FAST_SEC_PER_CELL:
		_move_timer = 0.0
		_advance_cell()

func _do_heal_pulse() -> void:
	if lane_ref == null: return
	var heal_amount: int = GameConfig.healer_heal_per_sec
	var radius_px: float = GameConfig.healer_radius_cells * Lane.CELL_H
	var r_sq: float = radius_px * radius_px
	var best: Enemy = null
	var best_d2: float = INF
	for e in lane_ref._enemies:
		if e == null or not is_instance_valid(e): continue
		if e == self: continue
		if e.hp >= e.max_hp: continue
		var d2: float = (e.position - position).length_squared()
		if d2 < r_sq and d2 < best_d2:
			best = e; best_d2 = d2
	if best != null:
		best.hp = min(best.max_hp, best.hp + heal_amount)
		best._refresh_hp_bar()
		Vfx.floating_badge(lane_ref, best.position + Vector2(0, -30),
			"+%d" % heal_amount, Color(0.4, 1.0, 0.5))

func _phase_skip() -> void:
	# Visual flicker + skip an extra row's worth of timer.
	if _sprite != null:
		var orig_a: float = _sprite.modulate.a
		var tw := _sprite.create_tween()
		tw.tween_property(_sprite, "modulate:a", 0.25, 0.10)
		tw.tween_property(_sprite, "modulate:a", orig_a, 0.10)
	# Skip ahead by extra cells (immediate advance + clear movement timer so it
	# advances again on the next tick).
	for i in GameConfig.phaser_skip_rows:
		if _reached: return
		_advance_cell()
	_move_timer = 0.0

func apply_speed_buff(buff_pct: float, duration_sec: float) -> void:
	# Bigger _speed_buff_factor = faster (it MULTIPLIES the move timer per
	# delta so the timer hits the per-cell threshold sooner).
	_speed_buff_factor = max(_speed_buff_factor, 1.0 + buff_pct)
	_speed_buff_timer = max(_speed_buff_timer, duration_sec)
	if _sprite != null:
		_sprite.modulate = Color(1.4, 0.6, 0.6, _sprite.modulate.a)

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
	# Tween must finish before the next advance fires (ENEMY_FAST_SEC_PER_CELL apart).
	var tween_dur: float = 0.18
	var tw := create_tween()
	tw.tween_property(self, "position", target_pos, tween_dur) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func take_damage(amount: int, source_color: int) -> void:
	# §8.3 Shielder: first N hits chip the shield rather than HP. Each hit
	# consumes 1 shield charge regardless of damage amount (per spec).
	if shield_hits_remaining > 0:
		shield_hits_remaining -= 1
		Vfx.hit_flash(self)
		if lane_ref != null:
			var tag: String = "SHIELD" if shield_hits_remaining > 0 else "SHATTER"
			Vfx.floating_badge(lane_ref, position + Vector2(0, -30), tag,
				Color(0.6, 0.85, 1.0))
		return
	# Hit-stop on heavy or fatal hits — gated globally in Vfx.hit_stop().
	var is_heavy: bool = max_hp > 0 and amount >= int(round(float(max_hp) * 0.30))
	var will_kill: bool = (hp - amount) <= 0
	if is_heavy or will_kill:
		Vfx.hit_stop()
	hp -= amount
	if hp <= 0:
		# §8.5 Accelerator: on death, buff the next N nearby enemies.
		if is_accelerator and lane_ref != null:
			_trigger_accelerator_buff()
		var burst_color: Color = Vfx.color_for_bubble(color)
		if is_boss: burst_color = Color(1.0, 0.85, 0.4)
		if get_parent() != null:
			Vfx.death_burst(get_parent(), global_position, burst_color)
		Telemetry.log_enemy_death(_enemy_id, color, source_color,
			Time.get_ticks_msec() - _spawn_ms)
		emit_signal("died", _enemy_id, color, source_color,
			Time.get_ticks_msec() - _spawn_ms)
		queue_free()
		return
	Vfx.hit_flash(self)
	_apply_knockback()
	_refresh_hp_bar()

func _trigger_accelerator_buff() -> void:
	if lane_ref == null: return
	# Pick the N nearest alive enemies (excluding self) and apply speed buff.
	var by_dist: Array = []
	for e in lane_ref._enemies:
		if e == null or not is_instance_valid(e) or e == self: continue
		by_dist.append({"e": e, "d": (e.position - position).length_squared()})
	by_dist.sort_custom(func(a, b): return a.d < b.d)
	var applied: int = 0
	for entry in by_dist:
		if applied >= GameConfig.accelerator_buff_target_count: break
		var target: Enemy = entry.e
		if is_instance_valid(target):
			target.apply_speed_buff(
				GameConfig.accelerator_speed_buff_pct,
				GameConfig.accelerator_speed_buff_duration_sec)
			applied += 1
	if lane_ref != null:
		Vfx.floating_badge(lane_ref, position + Vector2(0, -30),
			"SURGE!", Color(1.0, 0.5, 0.5))

# Visual knockback — tween the sprite child's offset (not the enemy's position)
# so the lane-tween that's driving cell-to-cell movement isn't fought.
# Pushes the sprite back toward the cluster (negative y) then settles.
func _apply_knockback() -> void:
	if _sprite == null or not is_instance_valid(_sprite): return
	var origin: Vector2 = Vector2.ZERO  # sprite is centered at (0,0) by default
	_sprite.offset = Vector2(0, -5)     # snap upward (toward cluster) on hit
	var tw := _sprite.create_tween()
	tw.tween_property(_sprite, "offset", origin, 0.10) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _refresh_hp_bar() -> void:
	if _hp_bar_bg == null or _hp_bar_fill == null: return
	if hp >= max_hp:
		_hp_bar_bg.visible = false
		_hp_bar_fill.visible = false
		return
	_hp_bar_bg.visible = true
	_hp_bar_fill.visible = true
	var frac: float = clamp(float(hp) / float(max_hp), 0.0, 1.0)
	_hp_bar_fill.size = Vector2(_HP_BAR_WIDTH * frac, _HP_BAR_HEIGHT)

func apply_slow() -> void:
	# §3.5 Blue hero ability: 30% slow for 2s.
	_slow_factor = 1.0 - GameConfig.blue_slow_pct
	_slow_timer = GameConfig.blue_slow_duration_sec
