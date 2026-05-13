# MatchScene — orchestrates a single stage of gameplay (V8: Phased Cluster→Wave).
# Owns Cluster, Lane, Cannon. Listens to all gameplay signals and runs the
# per-stage phase state machine: PHASE_1 → TRANSITION → PHASE_2 → CLEAR/FAIL.

class_name MatchScene
extends Node2D

@onready var cluster: Cluster = $ClusterZone/Cluster
@onready var lane: Lane = $LaneZone/Lane
@onready var cannon: Cannon = $HUDBottom/Cannon
@onready var hud_hp_bar: ProgressBar = $HUDTop/HPBar
@onready var hud_stage_label: Label = $HUDTop/StageLabel

enum Phase { PHASE_1, TRANSITION, PHASE_2, STAGE_CLEAR, STAGE_FAIL }

var stage_num: int = 1
var player_hp: int = 100
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

# Descent is deferred until the player's shot resolves so the cluster doesn't
# drop out from under an in-flight bubble. Queued on fire, relieved on pop,
# net applied on bubble_resolved.
var _pending_descent_rows: int = 0
var _pending_descent_relief: int = 0

# GET READY! / phase banner (created at runtime — no scene edit needed).
var _phase_banner: Label = null

# ============================================================
# Lifecycle
# ============================================================
func _ready() -> void:
	_setup_phase_banner()
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
	# v1 dev flow: auto-start Stage 1 with no boons. Replace with MetaHub→Loadout in W3.
	start_stage(1, [])

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
	hud_stage_label.text = "Stage %d/5" % num
	if cannon:
		cannon.current_stage_num = num
	for boon_id in run_boons:
		_apply_boon(boon_id)
	Telemetry.log_stage_start(num, GameConfig.get_stage_start_rows(num), player_hp)
	_enter_phase_1()

# ============================================================
# Phase transitions
# ============================================================
func _enter_phase_1() -> void:
	_phase = Phase.PHASE_1
	_phase_start_ms = Time.get_ticks_msec()
	_phase1_time_remaining = GameConfig.get_phase1_cap_sec(stage_num)
	if cannon: cannon.set_input_enabled(true)
	if lane:
		lane.combat_enabled = false
		lane.frenzied_colors = {}
	Telemetry.log_phase1_start(stage_num, GameConfig.get_stage_start_rows(stage_num), 0)
	_show_banner("PHASE 1 — BUILD", 0.8)

func _enter_transition(reason: String) -> void:
	if _phase != Phase.PHASE_1: return
	_phase = Phase.TRANSITION
	_transition_timer = GameConfig.phase_transition_sec
	if cannon: cannon.set_input_enabled(false)
	_p1_ms = Time.get_ticks_msec() - _phase_start_ms
	# Telemetry rollup payload — heroes_by_color not tracked yet, pass empty.
	Telemetry.log_phase1_end(stage_num, _p1_ms, reason,
		0, {}, _bubbles_fired, _total_pops, _bubbles_lost, _max_chain,
		_frenzy_buffed_colors.keys())
	_show_banner("GET READY!", GameConfig.phase_transition_sec)

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
	var wave_comp: Dictionary = {"R": 0, "B": 0, "Y": 0}
	for c in _wave_queue:
		match c:
			GameConfig.BubbleColor.RED:    wave_comp["R"] += 1
			GameConfig.BubbleColor.BLUE:   wave_comp["B"] += 1
			GameConfig.BubbleColor.YELLOW: wave_comp["Y"] += 1
	Telemetry.log_phase2_start(stage_num, 0, {}, _wave_size_total, wave_comp)
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
	_phase2_time_remaining -= delta
	# Spawn next wave enemy on cadence.
	if not _wave_queue.is_empty():
		_wave_spawn_timer -= delta
		if _wave_spawn_timer <= 0:
			var color: int = _wave_queue.pop_front()
			lane.spawn_wave_enemy(color, _wave_next_col, _wave_index)
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

func _on_match_popped(color: int, match_size: int, chain_count: int, _positions: Array) -> void:
	_total_pops += 1
	_max_chain = max(_max_chain, chain_count)
	# V1 simplification: exactly ONE hero per pop. Tier scales with match size,
	# but no extra bronze for big matches and no cascade heroes — kept the rule
	# legible for paper-testing the V8 phase model (was: 1 + extras + cascade).
	var tier: String = "bronze"
	if match_size >= 5: tier = "gold"
	elif match_size == 4: tier = "silver"
	var spawn_col: int = _column_for_match(_positions)
	lane.spawn_hero(color, tier, spawn_col, "match")
	var spawned: Array = [{"color": color, "tier": tier}]
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
	if player_hp <= 0:
		_fail_stage("hp")

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
	_show_banner("STAGE %d CLEAR" % stage_num, 1.5)
	# Auto-advance to next stage (no boon pick UI yet — that's W3).
	if stage_num < 5:
		var next: int = stage_num + 1
		var tw := create_tween()
		tw.tween_interval(1.8)
		tw.tween_callback(func(): start_stage(next, []))
	else:
		_show_banner("RUN COMPLETE", 2.5)

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
	_show_banner("STAGE %d FAILED" % stage_num, 2.5)

# ============================================================
# §4.2 — apply a boon at stage start
# ============================================================
func _apply_boon(boon_id: String) -> void:
	cannon.apply_boon(boon_id)
	match boon_id:
		"red_dmg":    lane.apply_damage_boon(GameConfig.BubbleColor.RED,    1.25)
		"blue_dmg":   lane.apply_damage_boon(GameConfig.BubbleColor.BLUE,   1.25)
		"yellow_dmg": lane.apply_damage_boon(GameConfig.BubbleColor.YELLOW, 1.25)
		_: pass

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
