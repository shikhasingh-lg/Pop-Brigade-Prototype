# MatchScene — orchestrates a single stage of gameplay (V8: Phased Cluster→Wave).
# Owns Cluster, Lane, Cannon. Listens to all gameplay signals and runs the
# per-stage phase state machine: PHASE_1 → TRANSITION → PHASE_2 → CLEAR/FAIL.

class_name MatchScene
extends Node2D

# Signals to the Main router (replace inline auto-advance once router owns flow).
signal stage_cleared(stage_num: int)
signal stage_failed(stage_num: int, reason: String)
signal quit_run_requested(stage_num: int)

const PAUSE_OVERLAY_SCENE := preload("res://scenes/PauseOverlay.tscn")

@onready var cluster: Cluster = $ClusterZone/Cluster
@onready var lane: Lane = $LaneZone/Lane
@onready var cannon: Cannon = $HUDBottom/Cannon
@onready var hud_hp_bar: ProgressBar = $HUDTop/HPBar
@onready var hud_stage_label: Label = $HUDTop/StageLabel
@onready var pause_icon: Label = $HUDTop/PauseIcon

# Base / defended object (added in MatchScene.tscn). HP shown on the base
# itself, plus damage tint + smoke + shake when enemies reach the wall.
@onready var base_node: Node2D = $Base
@onready var base_wall: ColorRect = $Base/Wall
@onready var base_hp_bar_fill: ColorRect = $Base/HPBarFill
@onready var base_crack: ColorRect = $Base/Crack
@onready var base_smoke: ColorRect = $Base/Smoke
const BASE_HP_BAR_LEFT: float = 42.0
const BASE_HP_BAR_RIGHT: float = 678.0
const BASE_WALL_FULL: Color = Color(0.275, 0.212, 0.157, 1)
const BASE_WALL_HURT: Color = Color(0.45, 0.20, 0.12, 1)   # at 0 HP

enum Phase { PHASE_1, TRANSITION, PHASE_2, STAGE_CLEAR, STAGE_FAIL }

# Set by Main router before _ready() so we boot into the right stage.
var start_stage_num: int = 1

var stage_num: int = 1
var player_hp: int = 100
var _pause_overlay: Control = null
var stage_start_ms: int = 0
var _stage_active: bool = false

# Phase-duration trackers: stamped at the END of each phase so stage_clear/fail
# telemetry can report p1_ms and p2_ms independently (Telemetry.log_stage_clear
# expects both).
var _p1_ms: int = 0
var _p2_ms: int = 0

# Phase state
var _phase: int = Phase.PHASE_1
var _phase_start_ms: int = 0
var _phase1_time_remaining: float = 0.0
var _phase2_time_remaining: float = 0.0
var _transition_timer: float = 0.0
var _no_enemy_timer: float = 0.0   # Phase 2 stage-clear grace

# Phase 2 wave spawner state
var _wave_queue: Array = []        # remaining enemy colors to spawn this stage
var _wave_size_total: int = 0      # total scripted enemies for the wave (for telemetry)
var _wave_spawn_timer: float = 0.0
var _wave_next_col: int = 0        # round-robin column assignment
var _wave_index: int = 0           # cumulative spawn index

# Stage-level counters for telemetry rollup
var _total_pops: int = 0
var _bubbles_fired: int = 0
var _bubbles_lost: int = 0
var _max_chain: int = 0
var _enemies_killed: int = 0
var _enemies_leaked: int = 0

# V8 §3.5: Phase-1 color clears earn a persistent +50% damage buff for that
# color, applied to all live heroes at Phase 2 start. Carried across the
# transition via this set (color enum keys).
var _frenzy_buffed_colors: Dictionary = {}

# V8 §4.3 Stage 5: boss appended after the walker wave. Spawned by MatchScene
# (not by the wave-comp array) so wave-comp telemetry stays a pure walker list.
var _boss_pending: bool = false
var _boss_alive: bool = false

# §4.2 Reinforcements boon: every 30 s of Phase 2, +1 hero.
const PERIODIC_HERO_INTERVAL_SEC: float = 30.0
var _periodic_hero_timer: float = 0.0
var _periodic_hero_spawned_this_stage: int = 0

# §4.2 Time Stop boon: pause wave processing for N seconds at Phase 2 start.
var _time_stop_remaining: float = 0.0

# Descent is deferred until the player's shot resolves so the cluster doesn't
# drop out from under an in-flight bubble. Queued on fire, relieved on pop,
# net applied on bubble_resolved.
var _pending_descent_rows: int = 0
var _pending_descent_relief: int = 0

# GET READY! / phase banner (created at runtime — no scene edit needed).
var _phase_banner: Label = null

# Hero drag (v2 §3.2 — Phase 2 agency surface, allowed in P1/transition too).
# Modal: while dragging, cannon aim is blocked. v1 = row 0 only, no cooldown.
var _drag_hero: Hero = null
var _drag_start_col: int = -1
var _drag_start_ms: int = 0

# Debug menu (F4) — runtime toggles for OQ A/B (§7.1). Built once in _ready,
# shown/hidden via key. Reads + writes GameConfig fields live.
var _debug_panel: Panel = null
var _dbg_carry_chk: CheckButton = null
var _dbg_early_clear_spin: SpinBox = null
var _dbg_transition_spin: SpinBox = null
var _dbg_ricochet_spin: SpinBox = null
var _dbg_status_label: Label = null

# ============================================================
# Lifecycle
# ============================================================
func _ready() -> void:
	_setup_phase_banner()
	_setup_debug_panel()
	if cluster:
		cluster.match_popped.connect(_on_match_popped)
		cluster.bubble_lost_below_line.connect(_on_bubble_lost_below_line)
		cluster.cluster_reached_lane.connect(_on_cluster_reached_lane)
		cluster.bubble_resolved.connect(_on_bubble_resolved)
	if lane:
		lane.enemy_reached_cannon.connect(_on_enemy_reached_cannon)
		lane.lane_cleared.connect(_on_lane_cleared)
	if cannon:
		cannon.bubble_fired.connect(_on_bubble_fired)
	_setup_pause_overlay()
	# Boot into start_stage_num (set by Main router) with the run's accumulated boons.
	start_stage(start_stage_num, RunState.run_boons)

# Debug stage controls (combat-design.md test loop):
#   F2 → next stage (wrap 5 → 1)
#   F3 → restart current stage
#   1..5 (top row) → jump to that stage directly
func _input(event: InputEvent) -> void:
	# Hero drag (combat-design.md §3.2). Must run BEFORE the cannon sees the
	# event — we block the cannon via set_aim_blocked while a drag is live.
	# Disabled once the stage has ended so corpses can't be grabbed.
	if not _stage_active: return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index != MOUSE_BUTTON_LEFT: return
		if mb.pressed:
			_try_begin_hero_drag(mb.position)
		elif _drag_hero != null:
			_end_hero_drag(mb.position)
	elif event is InputEventMouseMotion and _drag_hero != null:
		_update_hero_drag(event.position)

func _try_begin_hero_drag(touch_pos: Vector2) -> void:
	if lane == null: return
	var h: Hero = lane.find_hero_at_world_pos(touch_pos)
	if h == null: return
	_drag_hero = h
	_drag_start_col = h.lane_col
	_drag_start_ms = Time.get_ticks_msec()
	if cannon: cannon.set_aim_blocked(true)
	h.modulate = Color(1.15, 1.15, 1.15, 0.9)  # drag highlight
	h.z_index = 10  # draw above neighbors during drag

func _update_hero_drag(touch_pos: Vector2) -> void:
	if _drag_hero == null or not is_instance_valid(_drag_hero): return
	# Follow finger horizontally; lock to row-0 y so heroes don't drift up/down.
	var local_x: float = touch_pos.x - lane.global_position.x
	_drag_hero.position.x = clamp(local_x, Lane.CELL_W * 0.5, (Lane.COLS - 0.5) * Lane.CELL_W)
	_drag_hero.position.y = -Lane.CELL_H * 0.5

func _end_hero_drag(touch_pos: Vector2) -> void:
	var h: Hero = _drag_hero
	_drag_hero = null
	if cannon: cannon.set_aim_blocked(false)
	if h == null or not is_instance_valid(h):
		return
	h.modulate = Color(1, 1, 1, 1)
	h.z_index = 0
	var target_col: int = lane.world_x_to_row0_col(touch_pos.x)
	var end_col: int = lane.move_hero(h, target_col)
	if end_col >= 0 and end_col != _drag_start_col:
		var dragged_ms: int = Time.get_ticks_msec() - _drag_start_ms
		Telemetry.log_hero_drag(h.get_instance_id(), _drag_start_col, end_col,
			dragged_ms, h.color, h.tier)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: int = event.keycode
	if key == KEY_F2:
		var nxt: int = stage_num + 1
		if nxt > 5: nxt = 1
		_debug_jump_to_stage(nxt)
	elif key == KEY_F3:
		_debug_jump_to_stage(stage_num)
	elif key == KEY_F4:
		_toggle_debug_panel()
	elif key >= KEY_1 and key <= KEY_5:
		_debug_jump_to_stage(key - KEY_0)

func _debug_jump_to_stage(num: int) -> void:
	num = clamp(num, 1, 5)
	print("[Debug] Jumping to stage %d" % num)
	if lane: lane.reset()
	start_stage(num, [])

func start_stage(num: int, run_boons: Array) -> void:
	stage_num = num
	player_hp = GameConfig.stage_start_hp
	stage_start_ms = Time.get_ticks_msec()
	_stage_active = true
	_total_pops = 0
	_bubbles_fired = 0
	_bubbles_lost = 0
	_max_chain = 0
	_enemies_killed = 0
	_enemies_leaked = 0
	_pending_descent_rows = 0
	_pending_descent_relief = 0
	_no_enemy_timer = 0.0
	_frenzy_buffed_colors = {}
	_boss_pending = false
	_boss_alive = false
	cluster.setup_for_stage(num)
	hud_hp_bar.value = player_hp
	_update_base_visuals()
	hud_stage_label.text = "Stage %d/5" % num
	if cannon:
		cannon.current_stage_num = num
	# Recompute all idempotent boon state (multipliers, flags) from the boon list,
	# then dispatch per-system apply (cannon color bias, lane class dmg, etc.).
	RunState.recompute_boon_state()
	for boon_id in run_boons:
		_apply_boon(boon_id)
	_periodic_hero_timer = 0.0
	_periodic_hero_spawned_this_stage = 0
	# Carry heroes forward from the previous stage (HP + cell preserved; no heal,
	# no reposition). Empty on the first stage of a run. OQ11 toggle: when
	# carry_over_heroes_enabled is false, the lane stays empty each stage.
	var heroes_carried_in: int = 0
	if lane and GameConfig.carry_over_heroes_enabled and not RunState.run_heroes.is_empty():
		heroes_carried_in = RunState.run_heroes.size()
		lane.restore_heroes(RunState.run_heroes)
	# §4.2 one-shot boons: Recruitment Drive / Fresh Blood spawn heroes pre-Phase 1.
	# Both queues drain on the FIRST stage that runs after the boon is picked.
	_consume_pending_extra_heroes()
	Telemetry.log_stage_start(num, GameConfig.get_stage_start_rows(num), player_hp, heroes_carried_in)
	_enter_phase_1(heroes_carried_in)


func _consume_pending_extra_heroes() -> void:
	if lane == null: return
	var total: int = RunState.boon_pending_extra_heroes_next_stage + RunState.boon_pending_extra_heroes_now
	if total <= 0: return
	var palette: Array = GameConfig.all_bubble_colors()
	for i in range(total):
		var c: int = palette[i % palette.size()]
		var col: int = (i * 3) % Lane.COLS
		lane.spawn_hero(c, "bronze", col, "boon_recruitment")
	RunState.boon_pending_extra_heroes_next_stage = 0
	RunState.boon_pending_extra_heroes_now = 0

# ============================================================
# Phase transitions
# ============================================================
func _enter_phase_1(heroes_carried_in: int = 0) -> void:
	_phase = Phase.PHASE_1
	_phase_start_ms = Time.get_ticks_msec()
	_phase1_time_remaining = GameConfig.get_phase1_cap_sec(stage_num)
	if cannon: cannon.set_input_enabled(true)
	if lane:
		lane.combat_enabled = false
		lane.frenzied_colors = {}
	Telemetry.log_phase1_start(stage_num, GameConfig.get_stage_start_rows(stage_num), heroes_carried_in)
	_show_banner("PHASE 1 — BUILD", 0.8)

func _enter_transition(reason: String) -> void:
	if _phase != Phase.PHASE_1: return
	_phase = Phase.TRANSITION
	_transition_timer = GameConfig.phase_transition_sec
	if cannon: cannon.set_input_enabled(false)
	_p1_ms = Time.get_ticks_msec() - _phase_start_ms
	# OQ10 (§7.1): early-clear bonus heroes. Only when Phase 1 ends via
	# cluster_cleared (not the time cap) and the config knob is enabled.
	if reason == "cluster_cleared":
		_award_early_clear_bonus()
	# Telemetry rollup payload — heroes_by_color not tracked yet, pass empty.
	Telemetry.log_phase1_end(stage_num, _p1_ms, reason,
		0, {}, _bubbles_fired, _total_pops, _bubbles_lost, _max_chain,
		_frenzy_buffed_colors.keys())
	_show_banner("GET READY!", GameConfig.phase_transition_sec)

func _award_early_clear_bonus() -> void:
	var secs_per_hero: int = GameConfig.phase1_early_clear_secs_per_bonus_hero
	if secs_per_hero <= 0 or lane == null: return
	var time_remaining: float = max(0.0, _phase1_time_remaining)
	var bonus_count: int = int(time_remaining / float(secs_per_hero))
	if bonus_count <= 0: return
	# Cycle colors so bonus heroes aren't all one class — they reflect what's
	# usable right now (cluster is empty, so use the v1 palette directly).
	var palette: Array = GameConfig.all_bubble_colors()
	for i in range(bonus_count):
		var color: int = palette[i % palette.size()]
		# spawn_col cycles too; lane will fall back to nearest empty cell.
		var col: int = (i * 3) % Lane.COLS
		lane.spawn_hero(color, "bronze", col, "early_clear_bonus")
	Telemetry.log_phase1_early_clear_bonus(stage_num, int(time_remaining), bonus_count)

func _enter_phase_2() -> void:
	_phase = Phase.PHASE_2
	_phase_start_ms = Time.get_ticks_msec()
	_phase2_time_remaining = GameConfig.get_phase2_cap_sec(stage_num)
	_wave_queue = GameConfig.get_wave_composition(stage_num)
	_wave_size_total = _wave_queue.size()
	_boss_pending = (stage_num == 5)   # stage 5 appends a boss after the walker wave
	_boss_alive = false
	_wave_spawn_timer = 0.0   # spawn first enemy immediately
	_wave_next_col = 0
	_wave_index = 0
	if cannon: cannon.set_input_enabled(false)
	# Stamp the P1-earned frenzy buffs onto live heroes before combat starts.
	if lane:
		for color in _frenzy_buffed_colors:
			lane.apply_color_frenzy_persistent(color)
		lane.combat_enabled = true
	# wave_composition payload: { "R": n, "B": n, "Y": n }
	# _wave_queue is now Array[Dictionary] of {color, variant}.
	var wave_comp: Dictionary = {"R": 0, "B": 0, "Y": 0}
	for entry in _wave_queue:
		var c: int = entry["color"]
		match c:
			GameConfig.BubbleColor.RED:    wave_comp["R"] += 1
			GameConfig.BubbleColor.BLUE:   wave_comp["B"] += 1
			GameConfig.BubbleColor.YELLOW: wave_comp["Y"] += 1
	Telemetry.log_phase2_start(stage_num, 0, {}, _wave_size_total, wave_comp)
	# §4.2 Time Stop: drain pending stop-seconds at P2 start. One-shot per pick.
	if RunState.boon_time_stop_pending_sec > 0.0:
		_time_stop_remaining = RunState.boon_time_stop_pending_sec
		RunState.boon_time_stop_pending_sec = 0.0
		_show_banner("TIME STOP — %ds" % int(_time_stop_remaining), 1.0)
	else:
		_show_banner("PHASE 2 — DEFEND", 0.8)

# ============================================================
# Per-frame phase tick
# ============================================================
func _process(delta: float) -> void:
	if not _stage_active: return
	match _phase:
		Phase.PHASE_1:     _process_phase_1(delta)
		Phase.TRANSITION:  _process_transition(delta)
		Phase.PHASE_2:     _process_phase_2(delta)
		_: pass

func _process_phase_1(delta: float) -> void:
	_phase1_time_remaining -= delta
	# End Phase 1 when no bubbles remain above the spawn line.
	if cluster and cluster.bubbles_above_spawn_line_count() == 0:
		_enter_transition("cluster_cleared")
		return
	if _phase1_time_remaining <= 0:
		if cluster: cluster.sweep_all()
		_enter_transition("time_cap")

func _process_transition(delta: float) -> void:
	_transition_timer -= delta
	if _transition_timer <= 0:
		_enter_phase_2()

func _process_phase_2(delta: float) -> void:
	# §4.2 Time Stop: freeze wave spawning + enemy movement is approximated by
	# only freezing the spawn cadence (enemies already on the lane keep walking
	# but heroes keep firing too — the net effect is "fewer adds, breathing room").
	if _time_stop_remaining > 0.0:
		_time_stop_remaining -= delta
	else:
		_phase2_time_remaining -= delta
	# §4.2 Reinforcements: drop a bronze hero every 30 s of Phase 2.
	if RunState.boon_periodic_hero_spawn and lane != null and _time_stop_remaining <= 0.0:
		_periodic_hero_timer += delta
		if _periodic_hero_timer >= PERIODIC_HERO_INTERVAL_SEC:
			_periodic_hero_timer = 0.0
			var palette: Array = GameConfig.all_bubble_colors()
			var c: int = palette[_periodic_hero_spawned_this_stage % palette.size()]
			var col: int = (_periodic_hero_spawned_this_stage * 3) % Lane.COLS
			lane.spawn_hero(c, "bronze", col, "boon_reinforcements")
			_periodic_hero_spawned_this_stage += 1
	# Spawn next wave enemy on cadence.
	if not _wave_queue.is_empty() and _time_stop_remaining <= 0.0:
		_wave_spawn_timer -= delta
		if _wave_spawn_timer <= 0:
			var entry: Dictionary = _wave_queue.pop_front()
			var color: int = entry["color"]
			var variant: String = entry.get("variant", "walker")
			lane.spawn_wave_enemy(color, _wave_next_col, _wave_index, variant, stage_num)
			_wave_next_col = (_wave_next_col + 1) % Lane.COLS
			_wave_index += 1
			_wave_spawn_timer = GameConfig.wave_spawn_interval_sec
	# Stage 5: append the boss one beat after the last walker spawns.
	elif _boss_pending:
		_wave_spawn_timer -= delta
		if _wave_spawn_timer <= 0:
			_spawn_boss()
			_boss_pending = false
	# Phase 2 time cap: if hit with enemies still alive → fail.
	if _phase2_time_remaining <= 0:
		_fail_stage("phase2_cap")
		return
	# Stage-clear grace timer (started by lane.lane_cleared once wave queue is empty).
	if _no_enemy_timer > 0:
		_no_enemy_timer -= delta
		if _no_enemy_timer <= 0:
			_clear_stage()

# ============================================================
# Gameplay signal handlers
# ============================================================
func _on_bubble_fired(_bubble: Bubble, _angle_deg: float, _time_to_fire_ms: int) -> void:
	if _phase != Phase.PHASE_1: return
	_bubbles_fired += 1
	_pending_descent_rows += GameConfig.get_stage_descent_rows_per_shot(stage_num)

func _on_match_popped(color: int, match_size: int, chain_count: int, _positions: Array, hero_colors: Array) -> void:
	_total_pops += 1
	_max_chain = max(_max_chain, chain_count)
	# v2: heroes only spawn from matched hero bubbles. One hero per hero bubble
	# in the cleared group, each spawning a unit of its own color (red hero
	# bubble → Fire Knight, blue → Ice Mage, etc.). Tier still scales with the
	# overall match size so chaining hero bubbles into bigger matches matters.
	var tier: String = "bronze"
	if match_size >= 5: tier = "gold"
	elif match_size == 4: tier = "silver"
	var spawn_col: int = _column_for_match(_positions)
	var spawned: Array = []
	# §4.2 Twin Souls — every hero drop is doubled (1 → 2).
	var drop_count: int = 2 if RunState.boon_double_hero_drops else 1
	for hero_color in hero_colors:
		for _i in range(drop_count):
			lane.spawn_hero(hero_color, tier, spawn_col, "hero_bubble")
			RunState.total_heroes_spawned += 1
			spawned.append({"color": hero_color, "tier": tier})
	# §4.2 Hero Synergy — re-count duplicates after this batch landed.
	if RunState.boon_hero_synergy:
		lane.apply_hero_synergy()
	Telemetry.log_match_pop(match_size, color, chain_count, spawned)
	_pending_descent_relief += GameConfig.cluster_descent_pop_relief_rows
	# §3.5 color frenzy: full-clear of any color in Phase 1 stamps a persistent
	# +color_frenzy_buff_pct buff onto every hero of that color when Phase 2 starts.
	# Detection runs AFTER the pop has cleared this color's bubbles from the grid.
	if cluster and not _frenzy_buffed_colors.has(color):
		var still_present := false
		for c in cluster.get_active_colors():
			if c == color:
				still_present = true
				break
		if not still_present:
			_frenzy_buffed_colors[color] = true
			Vfx.edge_tint_pulse(self, Vfx.color_for_bubble(color), 0.85)
			Telemetry.log_color_frenzy(color, 0)

func _column_for_match(positions: Array) -> int:
	if positions.is_empty(): return 0
	var sum := 0
	for p in positions:
		sum += int(p.x)  # Vector2(col, row)
	return int(float(sum) / float(positions.size()))

func _on_bubble_resolved(_was_pop: bool) -> void:
	var net: int = _pending_descent_rows - _pending_descent_relief
	_pending_descent_rows = 0
	_pending_descent_relief = 0
	# Cluster's active-color set is now post-pop; re-validate the cannon queue so
	# we don't keep showing colors no longer present in the cluster.
	if cannon:
		cannon.refresh_queue_against_cluster()
	if cluster == null or _phase != Phase.PHASE_1: return
	if net > 0:
		cluster.descend_rows(net)
	elif net < 0:
		cluster.refund_descent_rows(-net)

func _on_bubble_lost_below_line(color: int, _col: int, source: String) -> void:
	_bubbles_lost += 1
	Telemetry.log_bubble_lost_below_line(color, source)

func _on_enemy_reached_cannon(hp_damage: int) -> void:
	if _phase != Phase.PHASE_2: return
	_enemies_leaked += 1
	player_hp = max(0, player_hp - hp_damage)
	hud_hp_bar.value = player_hp
	_update_base_visuals()
	_punch_base()
	Vfx.screen_shake(self, 18.0, 0.32)
	if player_hp <= 0:
		_fail_stage("hp")

# Visual response when an enemy reaches the wall: shake the base, flash it
# white briefly, and let _update_base_visuals handle the persistent damage state.
func _punch_base() -> void:
	if base_node == null: return
	Vfx.hit_flash(base_wall, 0.18)
	Vfx.screen_shake(base_node, 10.0, 0.28)

# Reflect player_hp on the base: HP bar width, wall tint, crack alpha, smoke alpha.
func _update_base_visuals() -> void:
	if base_hp_bar_fill == null: return
	var max_hp: float = float(GameConfig.stage_start_hp)
	var frac: float = clamp(float(player_hp) / max_hp, 0.0, 1.0)
	# HP bar fill width.
	var full_width: float = BASE_HP_BAR_RIGHT - BASE_HP_BAR_LEFT
	var sz: Vector2 = base_hp_bar_fill.size
	sz.x = full_width * frac
	base_hp_bar_fill.size = sz
	# HP bar color: green → orange → red as HP drops.
	if frac > 0.5:
		base_hp_bar_fill.color = Color(0.30, 0.78, 0.45, 1)
	elif frac > 0.25:
		base_hp_bar_fill.color = Color(0.92, 0.66, 0.20, 1)
	else:
		base_hp_bar_fill.color = Color(0.88, 0.25, 0.22, 1)
	# Wall tint — lerp full → hurt as HP drops.
	if base_wall != null:
		base_wall.color = BASE_WALL_FULL.lerp(BASE_WALL_HURT, 1.0 - frac)
	# Crack overlay fades in below 50% HP.
	if base_crack != null:
		var crack_alpha: float = 0.0 if frac >= 0.5 else clamp((0.5 - frac) / 0.5, 0.0, 0.65)
		base_crack.color = Color(0, 0, 0, crack_alpha)
	# Smoke overlay fades in below 25% HP.
	if base_smoke != null:
		var smoke_alpha: float = 0.0 if frac >= 0.25 else clamp((0.25 - frac) / 0.25, 0.0, 0.55)
		base_smoke.color = Color(0.42, 0.42, 0.45, smoke_alpha)

func _spawn_boss() -> void:
	# Stage 5 boss: red, centre column (col=4 of 8). Death/leak both clear _boss_alive
	# so the grace timer in _on_lane_cleared can fire.
	var center_col: int = int(Lane.COLS / 2)
	var boss: Enemy = lane.spawn_boss(GameConfig.BubbleColor.RED, center_col)
	if boss == null: return
	_boss_alive = true
	# Boss death/leak counted in addition to walkers.
	boss.died.connect(func(_id, _c, _src, _life): _boss_alive = false)
	boss.reached_cannon.connect(func(_id, _c, _dmg): _boss_alive = false)
	_show_banner("BOSS", 1.0)

func _on_cluster_reached_lane() -> void:
	# V8 §3.8: cluster reaching the lane in Phase 1 is NOT a fail —
	# just end Phase 1 and start the wave with the army built so far.
	if _phase == Phase.PHASE_1:
		_enter_transition("descent_complete")

func _on_lane_cleared() -> void:
	# Phase 2 stage-clear grace: only start the 2s timer once the WHOLE wave has spawned
	# AND (for Stage 5) the boss has spawned + died.
	if _phase != Phase.PHASE_2: return
	if not _wave_queue.is_empty(): return
	if _boss_pending or _boss_alive: return
	_no_enemy_timer = GameConfig.stage_clear_no_enemies_sec
	# Approximate enemies_killed: total spawned minus leaked. (Heroes can also die,
	# but lane_cleared fires only when _enemies.is_empty — leaks counted separately.)
	_enemies_killed = max(0, _wave_size_total - _enemies_leaked)

# ============================================================
# Stage end
# ============================================================
func _clear_stage() -> void:
	_phase = Phase.STAGE_CLEAR
	_stage_active = false
	if cannon: cannon.set_input_enabled(false)
	if lane: lane.combat_enabled = false
	_p2_ms = Time.get_ticks_msec() - _phase_start_ms
	Telemetry.log_phase2_end(stage_num, _p2_ms, "clear",
		player_hp, _enemies_killed, _enemies_leaked, 0)
	var stage_ms: int = Time.get_ticks_msec() - stage_start_ms
	Telemetry.log_stage_clear(stage_num, player_hp, stage_ms,
		_p1_ms, _p2_ms, _total_pops, _bubbles_lost, _max_chain)
	# Roll per-stage rollup into RunState so RunEnd can display it.
	RunState.record_stage_clear(stage_num, _total_pops, _bubbles_lost, _max_chain,
		_enemies_killed, _enemies_leaked)
	RunState.total_bubbles_fired += _bubbles_fired
	RunState.total_frenzies += _frenzy_buffed_colors.size()
	# Snapshot surviving heroes so the next stage can carry them forward.
	if lane:
		RunState.run_heroes = lane.snapshot_heroes()
	_show_banner("STAGE %d CLEAR" % stage_num, 1.5)
	# Hand off to Main router after a beat (lets banner read).
	var cleared_stage: int = stage_num
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_callback(func(): stage_cleared.emit(cleared_stage))

func _fail_stage(reason: String) -> void:
	if _phase == Phase.STAGE_FAIL: return
	var prior_phase: int = _phase
	_phase = Phase.STAGE_FAIL
	_stage_active = false
	if cannon: cannon.set_input_enabled(false)
	if lane: lane.combat_enabled = false
	if prior_phase == Phase.PHASE_2 or reason == "hp" or reason == "phase2_cap":
		_p2_ms = Time.get_ticks_msec() - _phase_start_ms
		Telemetry.log_phase2_end(stage_num, _p2_ms, "fail",
			player_hp, _enemies_killed, _enemies_leaked, 0)
	var stage_ms: int = Time.get_ticks_msec() - stage_start_ms
	Telemetry.log_stage_fail(stage_num, player_hp, reason, stage_ms)
	# Stat rollup for RunEnd — same fields a clear would carry.
	RunState.record_stage_fail(stage_num, reason)
	RunState.total_pops += _total_pops
	RunState.total_bubbles_lost += _bubbles_lost
	RunState.total_bubbles_fired += _bubbles_fired
	RunState.total_enemies_killed += _enemies_killed
	RunState.total_enemies_leaked += _enemies_leaked
	RunState.total_frenzies += _frenzy_buffed_colors.size()
	RunState.run_max_chain = max(RunState.run_max_chain, _max_chain)
	_show_banner("STAGE %d FAILED" % stage_num, 2.0)
	var failed_stage: int = stage_num
	var failed_reason: String = reason
	var tw := create_tween()
	tw.tween_interval(1.8)
	tw.tween_callback(func(): stage_failed.emit(failed_stage, failed_reason))

# ============================================================
# §4.2 — apply a boon at stage start.
# Most multiplier/flag effects already landed in RunState.recompute_boon_state.
# This function only handles per-system dispatch for Cannon + Lane.
# ============================================================
func _apply_boon(boon_id: String) -> void:
	cannon.apply_boon(boon_id)
	match boon_id:
		"red_dmg":    lane.apply_damage_boon(GameConfig.BubbleColor.RED,    1.25)
		"blue_dmg":   lane.apply_damage_boon(GameConfig.BubbleColor.BLUE,   1.25)
		"yellow_dmg": lane.apply_damage_boon(GameConfig.BubbleColor.YELLOW, 1.25)
		_: pass
	# §4.2 Hero Synergy — re-evaluate duplicate-class buff now that this boon
	# is live (safe to call on every boon since lane.apply_synergy is idempotent).
	if lane != null and RunState.boon_hero_synergy:
		lane.apply_hero_synergy()

# ============================================================
# Banner (GET READY! / phase / stage end)
# ============================================================
func _setup_phase_banner() -> void:
	_phase_banner = Label.new()
	_phase_banner.name = "PhaseBanner"
	_phase_banner.text = ""
	_phase_banner.add_theme_font_size_override("font_size", 64)
	_phase_banner.add_theme_color_override("font_color", Color(1, 0.95, 0.6))
	_phase_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_phase_banner.add_theme_constant_override("outline_size", 8)
	_phase_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Control parented to a Node2D: anchors don't apply, so set explicit rect.
	_phase_banner.position = Vector2(0, 0)
	_phase_banner.size = Vector2(720, 1560)
	_phase_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phase_banner.visible = false
	add_child(_phase_banner)

func _show_banner(text: String, duration_sec: float) -> void:
	if _phase_banner == null: return
	_phase_banner.text = text
	_phase_banner.modulate = Color(1, 1, 1, 1)
	_phase_banner.visible = true
	var tw := create_tween()
	tw.tween_interval(max(0.05, duration_sec - 0.25))
	tw.tween_property(_phase_banner, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func(): _phase_banner.visible = false)

# ============================================================
# Pause overlay (Screen 5)
# ============================================================
func _setup_pause_overlay() -> void:
	_pause_overlay = PAUSE_OVERLAY_SCENE.instantiate()
	add_child(_pause_overlay)
	_pause_overlay.resume_pressed.connect(_on_pause_resume)
	_pause_overlay.quit_run_pressed.connect(_on_pause_quit)
	# Tap the ⏸ in the top HUD to open. The Label has no built-in click,
	# so we use a transparent Button overlay.
	if pause_icon:
		var btn := Button.new()
		btn.flat = true
		btn.modulate = Color(1, 1, 1, 0)
		btn.size = Vector2(80, 80)
		btn.position = Vector2(620, 20)
		btn.pressed.connect(_on_pause_button)
		$HUDTop.add_child(btn)

func _on_pause_button() -> void:
	if not _stage_active: return
	var phase_for_log: int = 1 if _phase == Phase.PHASE_1 else 2
	var ms_into_stage: int = Time.get_ticks_msec() - stage_start_ms
	_pause_overlay.open(stage_num, phase_for_log, ms_into_stage)

func _on_pause_resume() -> void:
	pass  # tree-unpause handled in PauseOverlay; nothing else to do.

func _on_pause_quit() -> void:
	quit_run_requested.emit(stage_num)

# ============================================================
# Debug menu (F4) — exposes OQ flags so internal testers can A/B at runtime.
# Lives over the bottom HUD; ignores mouse when hidden so it doesn't eat aim.
# ============================================================
func _setup_debug_panel() -> void:
	_debug_panel = Panel.new()
	_debug_panel.name = "DebugPanel"
	_debug_panel.position = Vector2(20, 140)
	_debug_panel.size = Vector2(420, 260)
	_debug_panel.visible = false
	_debug_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_debug_panel)

	var vb := VBoxContainer.new()
	vb.position = Vector2(12, 8)
	vb.custom_minimum_size = Vector2(396, 240)
	_debug_panel.add_child(vb)

	var title := Label.new()
	title.text = "DEBUG (F4)  —  stage F2/F3, jump 1-5"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	vb.add_child(title)

	# OQ11 — carry-over heroes toggle
	_dbg_carry_chk = CheckButton.new()
	_dbg_carry_chk.text = "Carry-over heroes (OQ11)"
	_dbg_carry_chk.button_pressed = GameConfig.carry_over_heroes_enabled
	_dbg_carry_chk.toggled.connect(func(on: bool):
		GameConfig.carry_over_heroes_enabled = on
		_refresh_debug_status())
	vb.add_child(_dbg_carry_chk)

	# OQ10 — early-clear bonus secs/hero (0 = off)
	_dbg_early_clear_spin = _make_labeled_spin(vb,
		"P1 early-clear bonus: 1 hero per N sec (OQ10, 0=off)",
		0, 60, 1, GameConfig.phase1_early_clear_secs_per_bonus_hero,
		func(v: float):
			GameConfig.phase1_early_clear_secs_per_bonus_hero = int(v)
			_refresh_debug_status())

	# OQ1 — phase transition duration
	_dbg_transition_spin = _make_labeled_spin(vb,
		"GET READY! wipe (sec)  (OQ1)",
		0.0, 3.0, 0.1, GameConfig.phase_transition_sec,
		func(v: float):
			GameConfig.phase_transition_sec = v
			_refresh_debug_status())

	# OQ2 — aim ricochet count
	_dbg_ricochet_spin = _make_labeled_spin(vb,
		"Aim ricochets  (OQ2)",
		0, 3, 1, GameConfig.aim_ricochet_count,
		func(v: float):
			GameConfig.aim_ricochet_count = int(v)
			if cannon: cannon.ricochet_count = int(v)
			_refresh_debug_status())

	_dbg_status_label = Label.new()
	_dbg_status_label.add_theme_font_size_override("font_size", 13)
	_dbg_status_label.add_theme_color_override("font_color", Color(0.75, 0.85, 1))
	vb.add_child(_dbg_status_label)
	_refresh_debug_status()

# Builds: Label + SpinBox row inside `parent`. Returns the SpinBox.
func _make_labeled_spin(parent: Node, label_text: String,
		min_v: float, max_v: float, step: float, init_v: float,
		on_change: Callable) -> SpinBox:
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 13)
	parent.add_child(lbl)
	var spin := SpinBox.new()
	spin.min_value = min_v
	spin.max_value = max_v
	spin.step = step
	spin.value = init_v
	spin.custom_minimum_size = Vector2(120, 28)
	spin.value_changed.connect(on_change)
	parent.add_child(spin)
	return spin

func _toggle_debug_panel() -> void:
	if _debug_panel == null: return
	_debug_panel.visible = not _debug_panel.visible
	if _debug_panel.visible:
		_refresh_debug_status()

func _refresh_debug_status() -> void:
	if _dbg_status_label == null: return
	_dbg_status_label.text = "stage %d  •  hp %d  •  phase %s  •  heroes carried: %d" % [
		stage_num, player_hp, _phase_name(), RunState.run_heroes.size()]

func _phase_name() -> String:
	match _phase:
		Phase.PHASE_1:     return "P1"
		Phase.TRANSITION:  return "TR"
		Phase.PHASE_2:     return "P2"
		Phase.STAGE_CLEAR: return "CLR"
		Phase.STAGE_FAIL:  return "FAIL"
		_:                 return "?"
