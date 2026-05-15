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
@onready var hud_stage_label: Label = $HUDTop/StageLabel
@onready var pause_icon: Label = $HUDTop/PauseIcon

# Base / defended object (added in MatchScene.tscn). HP shown on the base
# itself, plus damage tint + smoke + shake when enemies reach the wall.
@onready var base_node: Node2D = $Base
@onready var base_wall: ColorRect = $Base/Wall
# HP bar sits just above the parapet — slim strip across the full battlement.
@onready var base_hp_bar_fill: ColorRect = $Base/HPBarFill
@onready var base_crack: ColorRect = $Base/Crack
@onready var base_smoke: ColorRect = $Base/Smoke

# Battle-line red trim. Dim in Phase 1, pulses in Phase 2.
@onready var spawn_line: ColorRect = $SpawnLine
var _spawn_line_tween: Tween = null
# HP-bar pulse: brightens base_hp_bar_fill when player HP < 50% (faster under 25%).
var _hp_pulse_t: float = 0.0
const BASE_HP_BAR_LEFT: float = 42.0
const BASE_HP_BAR_RIGHT: float = 678.0
const BASE_WALL_FULL: Color = Color(0.275, 0.212, 0.157, 1)
const BASE_WALL_HURT: Color = Color(0.45, 0.20, 0.12, 1)   # at 0 HP

enum Phase { PHASE_1, TRANSITION, PHASE_2, STAGE_CLEAR, STAGE_FAIL }

# Set by Main router before _ready() so we boot into the right stage/realm.
var start_stage_num: int = 1
var start_realm_num: int = 1

var realm_num: int = 1
var stage_num: int = 1
var player_hp: int = 100
var _max_player_hp: int = 100
var _start_moves: int = 0    # for star calc — moves unused fraction
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
var _boss_ref: Enemy = null

# §8.6 — Voidcrown Twins phase B (R5S5).
var _twin_phase_b_spawned: bool = false
var _phase_b_alive: bool = false
var _phase_b_ref: Enemy = null

# Mini-boss (R5S3 Echo of Voidcrown).
var _mini_boss_pending: bool = false
var _mini_boss_alive: bool = false
var _mini_boss_ref: Enemy = null
var _echo_phaser_timer: float = 0.0

# Realm gimmick timers — cluster shake (R2 S3-5) + cluster descent (R4 all stages, R5 S3-5).
var _shake_timer: float = 0.0
var _descent_timer: float = 0.0
var _descent_period: float = 0.0       # 0 = no descent this stage
var _shake_enabled: bool = false

# Boss mechanic timers.
var _zap_telegraph_timer: float = 0.0  # Storm Tyrant
var _zap_active_timer: float = 0.0
var _zap_column: int = -1
var _zap_overlay: ColorRect = null
var _warden_vine_timer: float = 0.0
var _warden_vines_alive: int = 0
var _ravager_slam_timer: float = 0.0
var _ravager_telegraph: ColorRect = null
var _twins_lumen_beam_timer: float = 0.0
var _twins_lumen_beam_col: int = -1
var _twins_lumen_beam_telegraph_t: float = 0.0
var _twins_umbra_swap_timer: float = 0.0

# §4.2 Reinforcements boon: every 30 s of Phase 2, +1 hero.
const PERIODIC_HERO_INTERVAL_SEC: float = 30.0
var _periodic_hero_timer: float = 0.0
var _periodic_hero_spawned_this_stage: int = 0

# §4.2 Time Stop boon: pause wave processing for N seconds at Phase 2 start.
var _time_stop_remaining: float = 0.0

# Move-budget model (concept.md §3.2): Phase 1 ends when the player runs out of
# shots. Decremented on each cannon fire; transition fires on 0.
var _moves_remaining: int = 0

# HUD: moves counter — created at runtime, top-right of the cannon HUD.
var _moves_label: Label = null

# Low-moves urgency (design-spec §3.5 / ui-flow "Low-moves urgency"):
# At moves_remaining == 5 we flash a golden highlight box behind the counter
# for ~2 s with a subtle pulse, then fade out. Fires once per stage; re-arms
# if moves are added back above the threshold via boons.
var _moves_highlight: Panel = null
var _low_moves_alerted: bool = false
const _LOW_MOVES_THRESHOLD: int = 5
const _LOW_MOVES_HIGHLIGHT_HOLD_SEC: float = 2.0
const _LOW_MOVES_HIGHLIGHT_FADE_SEC: float = 0.3

# GET READY! / phase banner (created at runtime — no scene edit needed).
var _phase_banner: Label = null

# Wave progress (Phase 2 only) — thin bar across the top of the lane plus a
# "WAVE n/m" label. Created at runtime so no .tscn churn. Shown/hidden on
# phase transitions; updated on every wave spawn.
var _wave_bar_bg: ColorRect = null
var _wave_bar_fill: ColorRect = null
var _wave_progress_label: Label = null
const _WAVE_BAR_Y: float = 1032.0
const _WAVE_BAR_LEFT: float = 30.0
const _WAVE_BAR_RIGHT: float = 530.0
const _WAVE_BAR_HEIGHT: float = 8.0

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
	_setup_wave_progress()
	_setup_moves_label()
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
	# Boot into start_realm_num/start_stage_num (set by Main router) with run boons.
	start_stage(start_stage_num, RunState.run_boons, start_realm_num)

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
			if lane != null and lane.try_activate_merge_at_world_pos(mb.position):
				get_viewport().set_input_as_handled()
				return
			_try_begin_hero_drag(mb.position)
		elif _drag_hero != null:
			_end_hero_drag(mb.position)
	elif event is InputEventMouseMotion and _drag_hero != null:
		_update_hero_drag(event.position)

func _try_begin_hero_drag(touch_pos: Vector2) -> void:
	if lane == null: return
	var h: Hero = lane.find_hero_at_world_pos(touch_pos)
	if h == null: return
	lane.clear_merge_options()
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
	lane.refresh_merge_options()
	if end_col >= 0 and end_col != _drag_start_col:
		var dragged_ms: int = Time.get_ticks_msec() - _drag_start_ms
		Telemetry.log_hero_drag(h.get_instance_id(), _drag_start_col, end_col,
			dragged_ms, h.color, h.tier)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: int = event.keycode
	if key == KEY_F2:
		# Advance to next stage; on S5 wrap to next realm's S1.
		var nxt_stage: int = stage_num + 1
		var nxt_realm: int = realm_num
		if nxt_stage > 5:
			nxt_stage = 1
			nxt_realm = realm_num + 1
			if nxt_realm > RunState.REALM_COUNT:
				nxt_realm = 1
		realm_num = nxt_realm
		_debug_jump_to_stage(nxt_stage)
	elif key == KEY_F3:
		_debug_jump_to_stage(stage_num)
	elif key == KEY_F4:
		_toggle_debug_panel()
	elif key >= KEY_1 and key <= KEY_5:
		_debug_jump_to_stage(key - KEY_0)
	elif key == KEY_F5 or key == KEY_F6 or key == KEY_F7 or key == KEY_F8 or key == KEY_F9:
		# F5..F9 → jump to R1..R5 S1.
		_debug_jump_to_realm(key - KEY_F4)

func _debug_jump_to_stage(num: int) -> void:
	num = clamp(num, 1, 5)
	print("[Debug] Jumping to R%dS%d" % [realm_num, num])
	if lane: lane.reset()
	start_stage(num, [], realm_num)

func _debug_jump_to_realm(r: int) -> void:
	r = clamp(r, 1, RunState.REALM_COUNT)
	print("[Debug] Jumping to R%dS1" % r)
	if lane: lane.reset()
	start_stage(1, [], r)

func start_stage(num: int, run_boons: Array, realm: int = 1) -> void:
	stage_num = num
	realm_num = clamp(realm, 1, RunState.REALM_COUNT)
	RunState.realm_num = realm_num
	# HP carries across stages within a realm. Stage 1 = entering a new realm
	# (or new run) → fresh HP. Stages 2-5 → carry HP from the prior stage via
	# RunState.run_player_hp (which is reset to 0 by begin_new_run).
	if num <= 1 or RunState.run_player_hp <= 0:
		player_hp = GameConfig.stage_start_hp
	else:
		player_hp = min(RunState.run_player_hp, GameConfig.stage_start_hp)
	_max_player_hp = GameConfig.stage_start_hp
	RunState.run_player_hp = player_hp
	stage_start_ms = Time.get_ticks_msec()
	_stage_active = true
	_total_pops = 0
	_bubbles_fired = 0
	_bubbles_lost = 0
	_max_chain = 0
	_enemies_killed = 0
	_enemies_leaked = 0
	_moves_remaining = GameConfig.get_realm_move_budget(realm_num, num)
	_start_moves = _moves_remaining
	_no_enemy_timer = 0.0
	_low_moves_alerted = false
	if _moves_highlight != null:
		_moves_highlight.visible = false
		_moves_highlight.modulate.a = 1.0
	_refresh_moves_label()
	_frenzy_buffed_colors = {}
	_boss_pending = false
	_boss_alive = false
	_boss_ref = null
	_twin_phase_b_spawned = false
	_phase_b_alive = false
	_phase_b_ref = null
	_mini_boss_pending = GameConfig.realm_has_mini_boss(realm_num, num)
	_mini_boss_alive = false
	_mini_boss_ref = null
	_echo_phaser_timer = 0.0
	# Realm gimmicks: cluster shake + time-based descent (§8.3/§8.5/§8.6).
	_shake_enabled = GameConfig.realm_has_cluster_shake(realm_num, num)
	_shake_timer = GameConfig.cluster_shake_interval_sec if _shake_enabled else 0.0
	_descent_period = GameConfig.realm_descent_sec_per_row(realm_num, num)
	_descent_timer = _descent_period
	# Boss mechanic state.
	_zap_telegraph_timer = 0.0
	_zap_active_timer = 0.0
	_zap_column = -1
	_clear_zap_overlay()
	_warden_vine_timer = 0.0
	_warden_vines_alive = 0
	_ravager_slam_timer = 0.0
	_clear_ravager_telegraph()
	_twins_lumen_beam_timer = 0.0
	_twins_lumen_beam_col = -1
	_twins_lumen_beam_telegraph_t = 0.0
	_twins_umbra_swap_timer = 0.0
	cluster.setup_for_stage(num, realm_num)
	_update_base_visuals()
	hud_stage_label.text = "R%dS%d — %s" % [realm_num, num, GameConfig.realm_name(realm_num)]
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
	Telemetry.log_stage_start(num, GameConfig.get_realm_cluster_rows(realm_num, num), player_hp, heroes_carried_in)
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
	_spawn_line_set_phase(Phase.PHASE_1)
	Telemetry.log_phase1_start(stage_num, GameConfig.get_realm_cluster_rows(realm_num, stage_num), heroes_carried_in)
	_show_banner("PHASE 1 — BUILD", 0.8)
	_set_wave_progress_visible(false)

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
	if _moves_label: _moves_label.visible = false
	if _moves_highlight: _moves_highlight.visible = false
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
	_wave_queue = GameConfig.get_wave_composition(realm_num, stage_num)
	_wave_size_total = _wave_queue.size()
	_boss_pending = (stage_num == 5)   # every realm's S5 appends a boss
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
	_spawn_line_set_phase(Phase.PHASE_2)
	# wave_composition rollup for telemetry.
	var wave_comp: Dictionary = {"R": 0, "B": 0, "Y": 0, "G": 0, "P": 0}
	for entry in _wave_queue:
		var c: int = entry["color"]
		match c:
			GameConfig.BubbleColor.RED:    wave_comp["R"] += 1
			GameConfig.BubbleColor.BLUE:   wave_comp["B"] += 1
			GameConfig.BubbleColor.YELLOW: wave_comp["Y"] += 1
			GameConfig.BubbleColor.GREEN:  wave_comp["G"] += 1
			GameConfig.BubbleColor.PURPLE: wave_comp["P"] += 1
	Telemetry.log_phase2_start(stage_num, 0, {}, _wave_size_total, wave_comp)
	# §4.2 Time Stop: drain pending stop-seconds at P2 start. One-shot per pick.
	if RunState.boon_time_stop_pending_sec > 0.0:
		_time_stop_remaining = RunState.boon_time_stop_pending_sec
		RunState.boon_time_stop_pending_sec = 0.0
		_show_banner("TIME STOP — %ds" % int(_time_stop_remaining), 1.0)
	else:
		_show_banner("PHASE 2 — DEFEND", 0.8)
	_refresh_wave_progress()
	_set_wave_progress_visible(true)

# Drive the battle-line red trim per phase:
#   PHASE_1 / TRANSITION → dim to α 0.45, no pulse (planning mode).
#   PHASE_2              → pulse α 0.6 ↔ 1.0 every 1.2s (combat is live).
#   STAGE_CLEAR / FAIL   → freeze at α 1.0 (clear) or fade to α 0.25 (fail).
func _spawn_line_set_phase(phase: int) -> void:
	if spawn_line == null: return
	if _spawn_line_tween != null and _spawn_line_tween.is_valid():
		_spawn_line_tween.kill()
	_spawn_line_tween = null
	match phase:
		Phase.PHASE_1, Phase.TRANSITION:
			spawn_line.modulate.a = 0.45
		Phase.PHASE_2:
			spawn_line.modulate.a = 1.0
			_spawn_line_tween = create_tween().set_loops()
			_spawn_line_tween.tween_property(spawn_line, "modulate:a", 0.6, 0.6) \
				.set_trans(Tween.TRANS_SINE)
			_spawn_line_tween.tween_property(spawn_line, "modulate:a", 1.0, 0.6) \
				.set_trans(Tween.TRANS_SINE)
		Phase.STAGE_CLEAR:
			spawn_line.modulate.a = 1.0
		Phase.STAGE_FAIL:
			spawn_line.modulate.a = 0.25

# ============================================================
# Per-frame phase tick
# ============================================================
func _process(delta: float) -> void:
	if not _stage_active: return
	_tick_hp_pulse(delta)
	match _phase:
		Phase.PHASE_1:     _process_phase_1(delta)
		Phase.TRANSITION:  _process_transition(delta)
		Phase.PHASE_2:     _process_phase_2(delta)
		_: pass

# Pulsing HP-bar tell: under 50% HP, base_hp_bar_fill glows brighter on a sine;
# under 25% the cadence roughly doubles for the "we're dying" read.
func _tick_hp_pulse(delta: float) -> void:
	if base_hp_bar_fill == null: return
	var max_hp: float = float(GameConfig.stage_start_hp)
	if max_hp <= 0.0: return
	var frac: float = clamp(float(player_hp) / max_hp, 0.0, 1.0)
	if frac >= 0.5:
		_hp_pulse_t = 0.0
		base_hp_bar_fill.modulate = Color(1, 1, 1, 1)
		return
	var freq: float = 7.0 if frac < 0.25 else 3.5
	_hp_pulse_t += delta * freq
	var amp: float = 0.45 if frac < 0.25 else 0.30
	var k: float = (sin(_hp_pulse_t) + 1.0) * 0.5  # 0..1
	var v: float = 1.0 + amp * k
	base_hp_bar_fill.modulate = Color(v, v * 0.85, v * 0.85, 1)

func _process_phase_1(delta: float) -> void:
	_phase1_time_remaining -= delta
	# §8.3 R2 cluster shake — every N sec during P1, descend 1 row.
	if _shake_enabled and _shake_timer > 0.0:
		_shake_timer -= delta
		if _shake_timer <= 0.0:
			_shake_timer = GameConfig.cluster_shake_interval_sec
			if cluster:
				cluster.descend_rows(1)
				Vfx.screen_shake(self, 10.0, 0.20)
	# §8.5 R4 / §8.6 R5 — time-based cluster descent.
	if _descent_period > 0.0:
		_descent_timer -= delta
		if _descent_timer <= 0.0:
			_descent_timer = _descent_period
			if cluster: cluster.descend_rows(1)
	# End Phase 1 when no bubbles remain above the spawn line.
	if cluster and cluster.bubbles_above_spawn_line_count() == 0:
		_enter_transition("cluster_cleared")
		return
	# End Phase 1 once every hero bubble has been captured — no point making
	# the player pop the rest of the cluster after all heroes are collected.
	# Gated on _bubbles_fired > 0 so a stage seeded with 0 hero bubbles doesn't
	# auto-skip on frame 1.
	if cluster and _bubbles_fired > 0 and cluster.hero_bubbles_above_spawn_line_count() == 0:
		cluster.sweep_all()
		_enter_transition("heroes_collected")
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
			lane.spawn_wave_enemy(color, _wave_next_col, _wave_index, variant, stage_num, realm_num)
			_wave_next_col = (_wave_next_col + 1) % Lane.COLS
			_wave_index += 1
			_wave_spawn_timer = GameConfig.wave_spawn_interval_sec
	# Every S5: append the boss one beat after the last walker spawns.
	# R5S3 mini-boss (Echo of Voidcrown) — spawn mid-wave (after first 1/3 of wave drained).
	elif _boss_pending:
		_wave_spawn_timer -= delta
		if _wave_spawn_timer <= 0:
			_spawn_boss()
			_boss_pending = false
	if _mini_boss_pending and not _mini_boss_alive:
		# Drop the Echo once the wave_queue has run for a beat (drain about half).
		if float(_wave_queue.size()) <= float(_wave_size_total) * 0.5:
			_spawn_mini_boss()
			_mini_boss_pending = false
	# Boss mechanic ticker — pegged to whichever S5 boss this realm has.
	_process_boss_mechanics(delta)
	# Phase 2 time cap: if hit with enemies still alive → fail.
	if _phase2_time_remaining <= 0:
		_fail_stage("phase2_cap")
		return
	# Refresh wave progress bar (cheap — one list scan).
	_refresh_wave_progress()
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
	# Move-budget model: each shot costs 1 move. Transition fires once the
	# in-flight bubble resolves (handled in _on_bubble_resolved) so a final
	# match still counts.
	_moves_remaining = max(0, _moves_remaining - 1)
	_refresh_moves_label()

func _on_match_popped(color: int, match_size: int, chain_count: int, _positions: Array, hero_colors: Array) -> void:
	_total_pops += 1
	_max_chain = max(_max_chain, chain_count)
	# v2: heroes only spawn from matched hero bubbles. One hero per hero bubble
	# in the cleared group, each spawning a unit of its own color (red hero
	# bubble → Fire Knight, blue → Ice Mage, etc.). Tier still scales with the
	# overall match size so chaining hero bubbles into bigger matches matters.
	# §3.4 tier thresholds: 3-5 = Bronze, 6-9 = Silver, 10+ = Gold (widened 2026-05-13).
	# Spawn-Gold now rare — Color Bomb on stages 4-5 or a 10-bubble chain.
	# Merge ladder is the primary path to Gold (see §3.5.1).
	var tier: String = "bronze"
	if match_size >= GameConfig.tier_gold_match_threshold: tier = "gold"
	elif match_size >= GameConfig.tier_silver_match_threshold: tier = "silver"
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
	var cluster_col: float = float(sum) / float(positions.size())
	var max_cluster_col: float = max(1.0, float(Cluster.COLS_EVEN - 1))
	return int(round((cluster_col / max_cluster_col) * float(Lane.COLS - 1)))

func _on_bubble_resolved(_was_pop: bool) -> void:
	# Cluster's active-color set is now post-pop; re-validate the cannon queue so
	# we don't keep showing colors no longer present in the cluster.
	if cannon:
		cannon.refresh_queue_against_cluster()
	if _phase != Phase.PHASE_1: return
	# Move-budget model: once the final shot resolves and the budget is gone,
	# end Phase 1. (Cluster-cleared end is still handled in _process_phase_1.)
	# Leftover bubbles are swept on the way out so they don't sit in P2 visually.
	# TODO concept.md §3.5: leftover bubbles SHOULD convert to enemies at this point
	# (combat-design.md OQ8 = NO for v1, but concept.md is now authoritative).
	if _moves_remaining <= 0 and cluster and cluster.bubbles_above_spawn_line_count() > 0:
		cluster.sweep_all()
		_enter_transition("budget_exhausted")

func _on_bubble_lost_below_line(color: int, _col: int, source: String) -> void:
	_bubbles_lost += 1
	Telemetry.log_bubble_lost_below_line(color, source)

func _on_enemy_reached_cannon(hp_damage: int) -> void:
	if _phase != Phase.PHASE_2: return
	_enemies_leaked += 1
	player_hp = max(0, player_hp - hp_damage)
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
	# Per-realm S5 boss. Color, HP, and damage come from GameConfig realm tables.
	var center_col: int = int(Lane.COLS / 2)
	var boss_color: int = GameConfig.boss_color_for_realm(realm_num)
	var boss: Enemy = lane.spawn_boss(boss_color, center_col, realm_num, stage_num)
	if boss == null: return
	_boss_ref = boss
	_boss_alive = true
	# Lane.lane_cleared fires from Lane's listener before our _boss_alive flips.
	# Re-run the clear check after flipping so the grace timer starts on S5.
	boss.died.connect(func(_id, _c, _src, _life):
		_boss_alive = false
		_boss_ref = null
		_on_lane_cleared()
	)
	boss.reached_cannon.connect(func(_id, _c, _dmg):
		_boss_alive = false
		_boss_ref = null
		_on_lane_cleared()
	)
	_show_banner("%s — BOSS!" % GameConfig.boss_name(realm_num).to_upper(), 1.2)

# §8.6 R5S3 Echo of Voidcrown — mini-boss that periodically spawns Phasers.
func _spawn_mini_boss() -> void:
	var center_col: int = int(Lane.COLS / 2)
	var color: int = GameConfig.BubbleColor.PURPLE
	var echo: Enemy = lane.spawn_boss(color, center_col, realm_num, stage_num,
		GameConfig.echo_hp, GameConfig.echo_damage_on_reach)
	if echo == null: return
	_mini_boss_ref = echo
	_mini_boss_alive = true
	_echo_phaser_timer = GameConfig.echo_phaser_spawn_interval_sec
	echo.died.connect(func(_id, _c, _src, _life):
		_mini_boss_alive = false
		_mini_boss_ref = null
		_on_lane_cleared()
	)
	echo.reached_cannon.connect(func(_id, _c, _dmg):
		_mini_boss_alive = false
		_mini_boss_ref = null
		_on_lane_cleared()
	)
	_show_banner("ECHO OF VOIDCROWN", 1.2)

# §8.6 R5S5 — Voidcrown Twins phase B (Sister Umbra) spawns when Lumen drops
# below 50% HP. Both alive triggers synergy buffs.
func _spawn_twin_phase_b() -> void:
	var spawn_col: int = (int(Lane.COLS / 2) + 1) % Lane.COLS
	var umbra_color: int = GameConfig.boss_phase_b_color(realm_num)
	var umbra: Enemy = lane.spawn_boss(umbra_color, spawn_col, realm_num, stage_num)
	if umbra == null: return
	_phase_b_ref = umbra
	_phase_b_alive = true
	umbra.died.connect(func(_id, _c, _src, _life):
		_phase_b_alive = false
		_phase_b_ref = null
		_on_lane_cleared()
	)
	umbra.reached_cannon.connect(func(_id, _c, _dmg):
		_phase_b_alive = false
		_phase_b_ref = null
		_on_lane_cleared()
	)
	_show_banner("SISTER UMBRA AWAKENS", 1.2)

# ============================================================
# §8.x — Per-realm boss mechanic tickers
# ============================================================
func _process_boss_mechanics(delta: float) -> void:
	# Echo (R5S3): periodic Phaser spawn while alive.
	if _mini_boss_alive:
		_echo_phaser_timer -= delta
		if _echo_phaser_timer <= 0.0:
			_echo_phaser_timer = GameConfig.echo_phaser_spawn_interval_sec
			lane.spawn_wave_enemy(GameConfig.BubbleColor.PURPLE,
				randi() % Lane.COLS, _wave_index, "phaser", stage_num, realm_num)
			_wave_index += 1
	if not _boss_alive: return
	# R2S5 Storm Tyrant — electrified column.
	if realm_num == 2 and stage_num == 5:
		_tick_storm_tyrant(delta)
	# R3S5 Verdant Warden — vine root pillars.
	elif realm_num == 3 and stage_num == 5:
		_tick_warden(delta)
	# R4S5 Spire Ravager — lane slam.
	elif realm_num == 4 and stage_num == 5:
		_tick_ravager(delta)
	# R5S5 Voidcrown Twins — phase A (Lumen) beam + phase B trigger.
	elif realm_num == 5 and stage_num == 5:
		_tick_twins(delta)

func _tick_storm_tyrant(delta: float) -> void:
	# Telegraph → active → cooldown loop.
	if _zap_active_timer > 0.0:
		_zap_active_timer -= delta
		if _zap_active_timer <= 0.0:
			_end_zap()
	elif _zap_telegraph_timer > 0.0:
		_zap_telegraph_timer -= delta
		if _zap_telegraph_timer <= 0.0:
			_start_zap_active()
	else:
		# Cooldown ticks via _zap_active_timer being 0 + zap_telegraph_timer 0.
		# Use _ravager_slam_timer? No — different mech. We'll piggyback: every
		# storm_tyrant_zap_interval_sec, kick off a new telegraph.
		if _zap_column == -1:
			_zap_column = _begin_zap_telegraph()

func _begin_zap_telegraph() -> int:
	# Pick a random column that has at least one row-0 hero (more interesting).
	var col: int = randi() % Lane.COLS
	for c in Lane.COLS:
		var test_c: int = (col + c) % Lane.COLS
		if lane._heroes_by_cell[0][test_c] != null:
			col = test_c
			break
	_zap_column = col
	_zap_telegraph_timer = GameConfig.storm_tyrant_zap_telegraph_sec
	_show_zap_overlay(col, true)
	return col

func _start_zap_active() -> void:
	_zap_active_timer = GameConfig.storm_tyrant_zap_active_sec
	_show_zap_overlay(_zap_column, false)
	# Apply damage_taken_mult to heroes in column.
	if _zap_column >= 0:
		var h: Hero = lane._heroes_by_cell[0][_zap_column]
		if h != null and is_instance_valid(h):
			h.damage_taken_mult = GameConfig.storm_tyrant_zap_damage_mult

func _end_zap() -> void:
	if _zap_column >= 0:
		var h: Hero = lane._heroes_by_cell[0][_zap_column]
		if h != null and is_instance_valid(h):
			h.damage_taken_mult = 1.0
	_zap_column = -1
	_clear_zap_overlay()
	# Cooldown delay before next telegraph.
	_zap_telegraph_timer = 0.0
	_zap_active_timer = 0.0
	# Defer next strike via a one-shot timer.
	var t := get_tree().create_timer(GameConfig.storm_tyrant_zap_interval_sec - GameConfig.storm_tyrant_zap_telegraph_sec - GameConfig.storm_tyrant_zap_active_sec)
	t.timeout.connect(func():
		if _phase == Phase.PHASE_2 and _boss_alive:
			_zap_column = _begin_zap_telegraph())

func _show_zap_overlay(col: int, is_telegraph: bool) -> void:
	_clear_zap_overlay()
	if col < 0: return
	var col_w: float = Lane.CELL_W
	var col_h: float = float(Lane.ROWS) * Lane.CELL_H + 200.0
	var rect := ColorRect.new()
	rect.color = Color(1.0, 0.95, 0.4, 0.20 if is_telegraph else 0.45)
	rect.size = Vector2(col_w, col_h)
	rect.position = Vector2(col_w * float(col), -col_h * 0.6)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.z_index = 30
	lane.add_child(rect)
	_zap_overlay = rect

func _clear_zap_overlay() -> void:
	if _zap_overlay != null and is_instance_valid(_zap_overlay):
		_zap_overlay.queue_free()
	_zap_overlay = null

func _tick_warden(delta: float) -> void:
	# Spawn vine-root pillars every N sec. While at least one alive, boss takes
	# -50% damage (handled via boss take_damage mult set when vines alive).
	_warden_vine_timer -= delta
	if _warden_vine_timer <= 0.0:
		_warden_vine_timer = GameConfig.warden_vine_pillar_interval_sec
		_spawn_warden_vine_pillar()
	# Apply / clear damage modifier on the boss based on vine count.
	if _boss_ref != null and is_instance_valid(_boss_ref):
		if _warden_vines_alive > 0:
			_boss_ref.set_meta("dmg_taken_mult", GameConfig.warden_damage_taken_while_vines_alive)
		else:
			_boss_ref.set_meta("dmg_taken_mult", 1.0)

func _spawn_warden_vine_pillar() -> void:
	var col: int = randi() % Lane.COLS
	lane.spawn_wave_enemy(GameConfig.BubbleColor.GREEN, col,
		_wave_index, "walker", stage_num, realm_num)
	# spawn_wave_enemy returns void; grab the just-spawned enemy off the lane list.
	if lane._enemies.is_empty(): return
	var v: Enemy = lane._enemies[-1]
	if v == null or not is_instance_valid(v): return
	v.hp = GameConfig.warden_vine_root_hp
	v.max_hp = GameConfig.warden_vine_root_hp
	v.set_meta("is_vine", true)
	_warden_vines_alive += 1
	v.died.connect(func(_id, _c, _src, _life):
		_warden_vines_alive = max(0, _warden_vines_alive - 1))
	v.reached_cannon.connect(func(_id, _c, _dmg):
		_warden_vines_alive = max(0, _warden_vines_alive - 1))
	_wave_index += 1

func _tick_ravager(delta: float) -> void:
	_ravager_slam_timer -= delta
	if _ravager_telegraph != null and is_instance_valid(_ravager_telegraph):
		# Telegraph countdown.
		if _ravager_slam_timer <= 0.0:
			_do_ravager_slam()
	elif _ravager_slam_timer <= 0.0:
		# Start telegraph.
		_ravager_slam_timer = GameConfig.ravager_slam_telegraph_sec
		_show_ravager_telegraph()

func _show_ravager_telegraph() -> void:
	_clear_ravager_telegraph()
	var crack := ColorRect.new()
	crack.color = Color(0.95, 0.55, 0.20, 0.55)
	crack.size = Vector2(Lane.COLS * Lane.CELL_W, 14.0)
	crack.position = Vector2(0, -7.0)
	crack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crack.z_index = 30
	lane.add_child(crack)
	_ravager_telegraph = crack
	Vfx.screen_shake(self, 6.0, 0.40)

func _clear_ravager_telegraph() -> void:
	if _ravager_telegraph != null and is_instance_valid(_ravager_telegraph):
		_ravager_telegraph.queue_free()
	_ravager_telegraph = null

func _do_ravager_slam() -> void:
	_clear_ravager_telegraph()
	# Collapse all row-0 heroes to col 0+ in FIFO. Heroes at col 0 stay, others
	# pack left into the next empty slot.
	if lane != null:
		var heroes_in_order: Array = []
		for c in Lane.COLS:
			var h: Hero = lane._heroes_by_cell[0][c]
			if h != null and is_instance_valid(h):
				heroes_in_order.append(h)
		# Clear row 0, then re-place in slots starting at col 0.
		for c in Lane.COLS:
			lane._heroes_by_cell[0][c] = null
		for i in range(heroes_in_order.size()):
			var h: Hero = heroes_in_order[i]
			if i < Lane.COLS:
				lane._heroes_by_cell[0][i] = h
				h.lane_col = i
				h.position = lane.cell_to_local_pos(0, i)
				h.position.y = -Lane.CELL_H * 0.5
		lane.refresh_merge_options()
	Vfx.screen_shake(self, 22.0, 0.45)
	_ravager_slam_timer = GameConfig.ravager_slam_interval_sec

func _tick_twins(delta: float) -> void:
	# Phase A (Lumen) — beam fires periodically on a random column.
	_twins_lumen_beam_timer -= delta
	if _twins_lumen_beam_telegraph_t > 0.0:
		_twins_lumen_beam_telegraph_t -= delta
		if _twins_lumen_beam_telegraph_t <= 0.0:
			_fire_lumen_beam()
	elif _twins_lumen_beam_timer <= 0.0:
		_begin_lumen_beam()
	# Phase B trigger: Lumen at <50%.
	if not _twin_phase_b_spawned and _boss_ref != null and is_instance_valid(_boss_ref):
		var ratio: float = float(_boss_ref.hp) / max(1.0, float(_boss_ref.max_hp))
		if ratio < GameConfig.twins_phase_b_trigger_hp_pct:
			_twin_phase_b_spawned = true
			_spawn_twin_phase_b()
	# Synergy buff while both alive — heal each other + bonus dmg.
	if _phase_b_alive and _boss_alive:
		var heal: int = GameConfig.twins_synergy_heal_per_sec
		var tick: float = delta
		# Scale heal by delta so it ticks once-per-sec smoothly.
		if _boss_ref != null and is_instance_valid(_boss_ref):
			_boss_ref.hp = min(_boss_ref.max_hp,
				_boss_ref.hp + int(round(float(heal) * tick)))
		if _phase_b_ref != null and is_instance_valid(_phase_b_ref):
			_phase_b_ref.hp = min(_phase_b_ref.max_hp,
				_phase_b_ref.hp + int(round(float(heal) * tick)))
	# Umbra (phase B) swap heroes' positions periodically.
	if _phase_b_alive:
		_twins_umbra_swap_timer -= delta
		if _twins_umbra_swap_timer <= 0.0:
			_twins_umbra_swap_timer = GameConfig.twins_umbra_swap_interval_sec
			_umbra_swap_heroes()

func _begin_lumen_beam() -> void:
	_twins_lumen_beam_col = randi() % Lane.COLS
	_twins_lumen_beam_telegraph_t = GameConfig.twins_lumen_beam_telegraph_sec
	_show_zap_overlay(_twins_lumen_beam_col, true)

func _fire_lumen_beam() -> void:
	# Instant-kill any hero in the marked column on hit.
	_clear_zap_overlay()
	var col: int = _twins_lumen_beam_col
	if col >= 0:
		var h: Hero = lane._heroes_by_cell[0][col]
		if h != null and is_instance_valid(h):
			h.take_damage(99999)
	_twins_lumen_beam_col = -1
	_twins_lumen_beam_telegraph_t = 0.0
	_twins_lumen_beam_timer = GameConfig.twins_lumen_beam_interval_sec
	Vfx.screen_shake(self, 18.0, 0.30)

func _umbra_swap_heroes() -> void:
	if lane == null: return
	# Pick two heroes in row 0 and swap.
	var present: Array = []
	for c in Lane.COLS:
		var h: Hero = lane._heroes_by_cell[0][c]
		if h != null and is_instance_valid(h):
			present.append({"h": h, "c": c})
	if present.size() < 2: return
	present.shuffle()
	var a = present[0]
	var b = present[1]
	lane._heroes_by_cell[0][a.c] = b.h
	lane._heroes_by_cell[0][b.c] = a.h
	b.h.lane_col = a.c
	a.h.lane_col = b.c
	b.h.position = lane.cell_to_local_pos(0, a.c)
	b.h.position.y = -Lane.CELL_H * 0.5
	a.h.position = lane.cell_to_local_pos(0, b.c)
	a.h.position.y = -Lane.CELL_H * 0.5
	lane.refresh_merge_options()

func _on_cluster_reached_lane() -> void:
	# V8 §3.8: cluster reaching the lane in Phase 1 is NOT a fail —
	# just end Phase 1 and start the wave with the army built so far.
	if _phase == Phase.PHASE_1:
		_enter_transition("descent_complete")

func _on_lane_cleared() -> void:
	# Phase 2 stage-clear grace: 2s after last enemy death, only once the WHOLE
	# wave has spawned AND any boss/mini-boss/twin-phase-B is dead.
	if _phase != Phase.PHASE_2: return
	if not _wave_queue.is_empty(): return
	if _boss_pending or _boss_alive: return
	if _mini_boss_pending or _mini_boss_alive: return
	if _phase_b_alive: return
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
	_set_wave_progress_visible(false)
	if cannon: cannon.set_input_enabled(false)
	if lane: lane.combat_enabled = false
	_spawn_line_set_phase(Phase.STAGE_CLEAR)
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
	# Carry the player's remaining HP into the next stage (same realm).
	# Reset back to full happens on stage 1 of the next realm via start_stage.
	RunState.run_player_hp = player_hp
	# Star award per §8.7. HP% + moves-unused% determine 1-3 stars.
	var hp_pct: float = 0.0 if _max_player_hp <= 0 else float(player_hp) / float(_max_player_hp)
	var moves_unused_pct: float = 0.0 if _start_moves <= 0 else float(_moves_remaining) / float(_start_moves)
	var stars: int = RunState.compute_stars(hp_pct, moves_unused_pct)
	RunState.award_stars(realm_num, stage_num, stars)
	var star_glyphs: String = "★".repeat(stars) + "☆".repeat(3 - stars)
	_show_banner("R%dS%d CLEAR  %s" % [realm_num, stage_num, star_glyphs], 1.6)
	# Hand off to Main router after a beat (lets banner read).
	var cleared_stage: int = stage_num
	var tw := create_tween()
	tw.tween_interval(1.5)
	tw.tween_callback(func(): stage_cleared.emit(cleared_stage))

func _fail_stage(reason: String) -> void:
	if _phase == Phase.STAGE_FAIL: return
	var prior_phase: int = _phase
	_phase = Phase.STAGE_FAIL
	_stage_active = false
	_set_wave_progress_visible(false)
	if cannon: cannon.set_input_enabled(false)
	if lane: lane.combat_enabled = false
	_spawn_line_set_phase(Phase.STAGE_FAIL)
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

# ============================================================
# Wave progress bar (Phase 2 only) — tells the player how much of the wave
# has been spawned so they can pace themselves. "ENEMIES LEFT" is more honest
# than "spawned" because it includes both queued + still-alive on lane.
# ============================================================
func _setup_wave_progress() -> void:
	_wave_bar_bg = ColorRect.new()
	_wave_bar_bg.name = "WaveBarBg"
	_wave_bar_bg.color = Color(0, 0, 0, 0.55)
	_wave_bar_bg.position = Vector2(_WAVE_BAR_LEFT, _WAVE_BAR_Y)
	_wave_bar_bg.size = Vector2(_WAVE_BAR_RIGHT - _WAVE_BAR_LEFT, _WAVE_BAR_HEIGHT)
	_wave_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wave_bar_bg.visible = false
	add_child(_wave_bar_bg)
	_wave_bar_fill = ColorRect.new()
	_wave_bar_fill.name = "WaveBarFill"
	_wave_bar_fill.color = Color(0.95, 0.55, 0.25, 0.95)
	_wave_bar_fill.position = Vector2(_WAVE_BAR_LEFT, _WAVE_BAR_Y)
	_wave_bar_fill.size = Vector2(_WAVE_BAR_RIGHT - _WAVE_BAR_LEFT, _WAVE_BAR_HEIGHT)
	_wave_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wave_bar_fill.visible = false
	add_child(_wave_bar_fill)
	_wave_progress_label = Label.new()
	_wave_progress_label.name = "WaveProgressLabel"
	_wave_progress_label.position = Vector2(_WAVE_BAR_RIGHT + 14.0, _WAVE_BAR_Y - 8.0)
	_wave_progress_label.size = Vector2(160.0, 24.0)
	_wave_progress_label.add_theme_font_size_override("font_size", 16)
	_wave_progress_label.add_theme_color_override("font_color", Color(0.95, 0.86, 0.62, 1))
	_wave_progress_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_wave_progress_label.add_theme_constant_override("outline_size", 3)
	_wave_progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wave_progress_label.visible = false
	add_child(_wave_progress_label)

func _setup_moves_label() -> void:
	# Top-left HUD moves counter for Phase 1 ("MOVES 10"). Hidden in P2.
	# Replaces the old HP bar in HUDTop — HP is shown on the base wall now.
	_moves_label = Label.new()
	_moves_label.name = "MovesLabel"
	_moves_label.add_theme_font_size_override("font_size", 28)
	_moves_label.add_theme_color_override("font_color", Color(1, 0.95, 0.6))
	_moves_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_moves_label.add_theme_constant_override("outline_size", 4)
	_moves_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_moves_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_moves_label.position = Vector2(30, 42)
	_moves_label.size = Vector2(260, 36)
	_moves_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Golden highlight panel — sits behind the label, hidden until moves drop to
	# the low-moves threshold. Added BEFORE the label so the label draws on top.
	_moves_highlight = Panel.new()
	_moves_highlight.name = "MovesHighlight"
	var hl_style := StyleBoxFlat.new()
	hl_style.bg_color = Color(1.0, 0.82, 0.20, 0.28)        # soft gold fill
	hl_style.border_color = Color(1.0, 0.78, 0.18, 1.0)     # solid gold border
	hl_style.set_border_width_all(4)
	hl_style.corner_radius_top_left = 10
	hl_style.corner_radius_top_right = 10
	hl_style.corner_radius_bottom_left = 10
	hl_style.corner_radius_bottom_right = 10
	hl_style.shadow_color = Color(1.0, 0.78, 0.18, 0.55)
	hl_style.shadow_size = 8
	_moves_highlight.add_theme_stylebox_override("panel", hl_style)
	# Sized slightly larger than the label so the border surrounds it.
	_moves_highlight.position = Vector2(_moves_label.position.x - 12, _moves_label.position.y - 8)
	_moves_highlight.size = Vector2(_moves_label.size.x + 24, _moves_label.size.y + 16)
	_moves_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_moves_highlight.visible = false
	_moves_highlight.pivot_offset = _moves_highlight.size * 0.5
	if has_node("HUDTop"):
		$HUDTop.add_child(_moves_highlight)
		$HUDTop.add_child(_moves_label)
	else:
		add_child(_moves_highlight)
		add_child(_moves_label)

func _refresh_moves_label() -> void:
	if _moves_label == null: return
	_moves_label.text = "MOVES %d" % _moves_remaining
	_moves_label.visible = (_phase == Phase.PHASE_1)
	# Flash red when low.
	if _moves_remaining <= 3:
		_moves_label.add_theme_color_override("font_color", Color(1, 0.45, 0.4))
	else:
		_moves_label.add_theme_color_override("font_color", Color(1, 0.95, 0.6))
	# Low-moves urgency: golden highlight when crossing into the threshold.
	# Fires once per stage; re-arms if moves climb back above threshold.
	if _phase == Phase.PHASE_1:
		if _moves_remaining > _LOW_MOVES_THRESHOLD:
			_low_moves_alerted = false
		elif _moves_remaining == _LOW_MOVES_THRESHOLD and not _low_moves_alerted:
			_low_moves_alerted = true
			_trigger_low_moves_highlight()

func _trigger_low_moves_highlight() -> void:
	if _moves_highlight == null: return
	_moves_highlight.visible = true
	_moves_highlight.modulate = Color(1, 1, 1, 1)
	_moves_highlight.scale = Vector2.ONE
	# Pulse scale (up-down twice) during the hold, then fade out.
	var pulse: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(_moves_highlight, "scale", Vector2(1.08, 1.12), 0.35)
	pulse.tween_property(_moves_highlight, "scale", Vector2.ONE, 0.35)
	pulse.tween_property(_moves_highlight, "scale", Vector2(1.06, 1.08), 0.35)
	pulse.tween_property(_moves_highlight, "scale", Vector2.ONE, 0.35)
	# Hold then fade.
	var fade: Tween = create_tween()
	fade.tween_interval(_LOW_MOVES_HIGHLIGHT_HOLD_SEC)
	fade.tween_property(_moves_highlight, "modulate:a", 0.0, _LOW_MOVES_HIGHLIGHT_FADE_SEC)
	fade.tween_callback(func() -> void:
		if _moves_highlight != null:
			_moves_highlight.visible = false
			_moves_highlight.modulate.a = 1.0
	)

func _set_wave_progress_visible(on: bool) -> void:
	if _wave_bar_bg != null: _wave_bar_bg.visible = on
	if _wave_bar_fill != null: _wave_bar_fill.visible = on
	if _wave_progress_label != null: _wave_progress_label.visible = on

# Remaining = enemies still in the spawn queue + enemies alive on the lane.
# Boss (if pending or alive) counts as one extra. Updates the fill width to
# reflect the fraction killed/leaked vs the original wave size.
func _refresh_wave_progress() -> void:
	if _wave_size_total <= 0 or _wave_bar_fill == null: return
	var alive: int = 0
	if lane != null:
		for e in lane._enemies:
			if e != null and is_instance_valid(e):
				alive += 1
	var queued: int = _wave_queue.size()
	var remaining: int = queued + alive
	var resolved: int = max(0, _wave_size_total - remaining)
	var frac: float = clamp(float(resolved) / float(_wave_size_total), 0.0, 1.0)
	var full_width: float = _WAVE_BAR_RIGHT - _WAVE_BAR_LEFT
	var sz: Vector2 = _wave_bar_fill.size
	sz.x = full_width * frac
	_wave_bar_fill.size = sz
	if _wave_progress_label != null:
		var label_text: String = "ENEMIES %d / %d" % [resolved, _wave_size_total]
		if _boss_pending or _boss_alive:
			label_text += " + BOSS"
		_wave_progress_label.text = label_text

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
