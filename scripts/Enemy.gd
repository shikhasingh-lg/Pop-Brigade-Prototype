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

# Variant tag — "walker" (default), "runner", "brute". See combat-design.md §3.2.
var variant: String = "walker"
# Stage number — used to apply per-stage HP/dmg scalars (combat-design.md §3.3).
# Lane sets this BEFORE _ready().
var stage_num: int = 1

# §4.3 Stage 5 boss flag. Lane sets these BEFORE _ready() so _apply_color_stats
# can use boss HP / damage instead of the color-baseline values.
var is_boss: bool = false
var boss_hp_override: int = 0
var boss_damage_override: int = 0

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
		_:
			base_hp = 50.0; base_speed = 1.0; base_dmg = 10.0
	# Variant multipliers (combat-design.md §3.2)
	match variant:
		"runner":
			base_hp *= GameConfig.runner_hp_mult
			base_speed *= GameConfig.runner_speed_mult
		"brute":
			base_hp *= GameConfig.brute_hp_mult
			base_speed *= GameConfig.brute_speed_mult
			base_dmg *= GameConfig.brute_dmg_mult
		_:
			pass  # walker = baseline
	# Per-stage scalars (combat-design.md §3.3)
	var stage_idx: int = clamp(stage_num - 1, 0, GameConfig.stage_hp_mults.size() - 1)
	base_hp *= GameConfig.stage_hp_mults[stage_idx]
	base_dmg *= GameConfig.stage_dmg_mults[stage_idx]
	# §4.3 boss override (Stage 5 only): tougher + slower + harder-hitting.
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
			# Slightly smaller silhouette + brighter tint to read as quick & nimble.
			scale = Vector2(0.85, 0.85)
			_sprite.modulate = Color(1.15, 1.15, 1.10, 1.0)
		"brute":
			# Bigger silhouette + darker tint to read as a tank.
			scale = Vector2(1.4, 1.4)
			_sprite.modulate = Color(0.75, 0.75, 0.85, 1.0)
		_:
			pass

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
		return
	# Hit flash on damage that doesn't kill — covers AoE/cleave secondaries
	# that bypass the per-target flash in Hero's attack path.
	Vfx.hit_flash(self)
	_apply_knockback()
	_refresh_hp_bar()

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
