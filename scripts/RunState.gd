# RunState — autoload singleton holding per-run state shared across screens.
#
# Lives between MetaHub → Loadout → MatchScene → StageClear/StageFail → RunEnd.
# Reset on every new run via begin_new_run(). Lifetime stats (runs_completed)
# persist to user://run_save.json.

extends Node

const SAVE_PATH := "user://run_save.json"

# Lifetime (persisted)
var runs_completed: int = 0

# Per-run (reset by begin_new_run)
var run_boons: Array[String] = []          # boon_ids picked across stages
# Heroes carried across stages. Each entry: {color: int, tier: String, hp: int, row: int, col: int}.
# Snapshot taken at stage clear; restored at the next stage's start.
var run_heroes: Array = []
var run_start_ms: int = 0
var stages_cleared: int = 0
var last_stage_reached: int = 1
var completion: String = "in_progress"     # "win" | "fail" | "quit"
var last_fail_reason: String = ""

# Per-run rollup stats (for RunEnd display + log_run_end)
var total_bubbles_fired: int = 0
var total_pops: int = 0
var total_bubbles_lost: int = 0
var total_heroes_spawned: int = 0
var total_enemies_killed: int = 0
var total_enemies_leaked: int = 0
var total_frenzies: int = 0
var run_max_chain: int = 0


func _ready() -> void:
	_load()


func begin_new_run() -> void:
	run_boons.clear()
	run_heroes.clear()
	run_start_ms = Time.get_ticks_msec()
	stages_cleared = 0
	last_stage_reached = 1
	completion = "in_progress"
	last_fail_reason = ""
	total_bubbles_fired = 0
	total_pops = 0
	total_bubbles_lost = 0
	total_heroes_spawned = 0
	total_enemies_killed = 0
	total_enemies_leaked = 0
	total_frenzies = 0
	run_max_chain = 0


func add_boon(boon_id: String) -> void:
	run_boons.append(boon_id)


func record_stage_clear(stage_num: int, pops: int, misses: int, max_chain: int,
		enemies_killed: int, enemies_leaked: int) -> void:
	stages_cleared = max(stages_cleared, stage_num)
	last_stage_reached = stage_num
	total_pops += pops
	total_bubbles_lost += misses
	total_enemies_killed += enemies_killed
	total_enemies_leaked += enemies_leaked
	run_max_chain = max(run_max_chain, max_chain)


func record_stage_fail(stage_num: int, reason: String) -> void:
	last_stage_reached = stage_num
	last_fail_reason = reason


func finish_run(completion_kind: String) -> void:
	completion = completion_kind
	if completion_kind == "win":
		runs_completed += 1
		_save()


func total_run_ms() -> int:
	return Time.get_ticks_msec() - run_start_ms


# ============================================================
# Persistence (only runs_completed survives across app launches)
# ============================================================
func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null: return
	var raw := f.get_as_text()
	f.close()
	var data: Variant = JSON.parse_string(raw)
	if typeof(data) == TYPE_DICTIONARY:
		runs_completed = int(data.get("runs_completed", 0))


func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("RunState: failed to write %s" % SAVE_PATH)
		return
	f.store_string(JSON.stringify({ "runs_completed": runs_completed }))
	f.close()
