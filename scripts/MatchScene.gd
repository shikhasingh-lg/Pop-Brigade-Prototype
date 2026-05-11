# MatchScene — orchestrates a single stage of gameplay.
# Owns Cluster, Lane, Cannon. Listens to all gameplay signals and
# runs the stage win/lose state machine (§3.8).

class_name MatchScene
extends Node2D

@onready var cluster: Cluster = $ClusterZone/Cluster
@onready var lane: Lane = $LaneZone/Lane
@onready var cannon: Cannon = $HUDBottom/Cannon
@onready var hud_hp_bar: ProgressBar = $HUDTop/HPBar
@onready var hud_stage_label: Label = $HUDTop/StageLabel

var stage_num: int = 1
var player_hp: int = 100
var stage_start_ms: int = 0
var _stage_active: bool = false
var _no_enemy_timer: float = 0.0

# Stage-level counters for telemetry rollup at end-of-stage
var _total_pops: int = 0
var _total_misses: int = 0
var _max_chain: int = 0

# ============================================================
# Lifecycle
# ============================================================
func start_stage(num: int, run_boons: Array) -> void:
	stage_num = num
	player_hp = GameConfig.stage_start_hp
	stage_start_ms = Time.get_ticks_msec()
	_stage_active = true
	_total_pops = 0
	_total_misses = 0
	_max_chain = 0
	cluster.setup_for_stage(num)
	hud_hp_bar.value = player_hp
	hud_stage_label.text = "Stage %d/5" % num
	# Apply boons collected so far this run.
	for boon_id in run_boons:
		_apply_boon(boon_id)
	Telemetry.log_stage_start(num, GameConfig.get_stage_start_rows(num), player_hp)

# ============================================================
# Signal hookups (wire in editor or _ready)
# ============================================================
func _ready() -> void:
	if cluster:
		cluster.match_popped.connect(_on_match_popped)
		cluster.bubble_crossed_spawn_line.connect(_on_bubble_crossed_spawn_line)
		cluster.cluster_reached_lane.connect(_on_cluster_reached_lane)
	if lane:
		lane.enemy_reached_cannon.connect(_on_enemy_reached_cannon)
		lane.lane_cleared.connect(_on_lane_cleared)
	# v1 dev flow: auto-start Stage 1 with no boons. Replace with MetaHub→Loadout in W3.
	start_stage(1, [])

# ============================================================
# §3.2 cluster → hero spawn
# ============================================================
func _on_match_popped(color: int, match_size: int, chain_count: int, _positions: Array) -> void:
	_total_pops += 1
	_max_chain = max(_max_chain, chain_count)
	# §3.4 tier mapping
	var spawned: Array = []
	if match_size >= 5:
		lane.spawn_hero(color, "gold", _column_for_match(_positions), "match")
		spawned.append({"color": color, "tier": "gold"})
		for i in range(match_size - 5):
			lane.spawn_hero(color, "bronze", _column_for_match(_positions), "match")
			spawned.append({"color": color, "tier": "bronze"})
	elif match_size == 4:
		lane.spawn_hero(color, "silver", _column_for_match(_positions), "match")
		spawned.append({"color": color, "tier": "silver"})
	else: # 3
		lane.spawn_hero(color, "bronze", _column_for_match(_positions), "match")
		spawned.append({"color": color, "tier": "bronze"})
	# Cascade bronze heroes for chained falls (chain_count > 0)
	for i in range(chain_count):
		lane.spawn_hero(color, "bronze", _column_for_match(_positions), "cascade")
		spawned.append({"color": color, "tier": "bronze"})
	Telemetry.log_match_pop(match_size, color, chain_count, spawned)
	# TODO: detect if the cluster now has zero bubbles of `color` → trigger color frenzy.

func _column_for_match(positions: Array) -> int:
	# Use centroid column (§3.4).
	if positions.is_empty(): return 0
	var sum := 0
	for p in positions:
		sum += int(p.x)  # assuming Vector2(col, row)
	return int(sum / positions.size())

# ============================================================
# §3.2 cluster → enemy spawn (V2 cluster-as-spawner)
# ============================================================
func _on_bubble_crossed_spawn_line(color: int, col: int) -> void:
	Telemetry.log_bubble_converted_to_enemy(color, col, "descent")
	lane.spawn_enemy_from_conversion(color, col)

# ============================================================
# §3.8 — win / lose
# ============================================================
func _on_enemy_reached_cannon(hp_damage: int) -> void:
	player_hp = max(0, player_hp - hp_damage)
	hud_hp_bar.value = player_hp
	if player_hp <= 0:
		_fail_stage("hp")

func _on_cluster_reached_lane() -> void:
	_fail_stage("cluster_reached_lane")

func _on_lane_cleared() -> void:
	# §3.8: stage clears after "no enemies on lane for 3s" — grace period.
	_no_enemy_timer = GameConfig.stage_clear_no_enemies_sec

func _process(delta: float) -> void:
	if not _stage_active: return
	if _no_enemy_timer > 0:
		_no_enemy_timer -= delta
		if _no_enemy_timer <= 0:
			_clear_stage()

func _clear_stage() -> void:
	_stage_active = false
	var ms_elapsed := Time.get_ticks_msec() - stage_start_ms
	Telemetry.log_stage_clear(stage_num, player_hp, ms_elapsed,
		_total_pops, _total_misses, _max_chain)
	# TODO: switch to StageClear screen (boon pick UI).
	push_warning("MatchScene: stage cleared — show StageClear UI")

func _fail_stage(reason: String) -> void:
	_stage_active = false
	var ms_elapsed := Time.get_ticks_msec() - stage_start_ms
	Telemetry.log_stage_fail(stage_num, player_hp, reason, ms_elapsed)
	# TODO: switch to StageFail screen.
	push_warning("MatchScene: stage failed — show StageFail UI")

# ============================================================
# §4.2 — apply a boon (called by MatchScene at stage start for each run boon)
# ============================================================
func _apply_boon(boon_id: String) -> void:
	cannon.apply_boon(boon_id)
	match boon_id:
		"red_dmg":    lane.apply_damage_boon(GameConfig.BubbleColor.RED,    1.25)
		"blue_dmg":   lane.apply_damage_boon(GameConfig.BubbleColor.BLUE,   1.25)
		"yellow_dmg": lane.apply_damage_boon(GameConfig.BubbleColor.YELLOW, 1.25)
		_: pass
