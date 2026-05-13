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

# Boon-derived run state — recomputed at every stage start from run_boons so
# the values stay idempotent (no compounding across stages). See
# RunState.recompute_boon_state() + MatchScene.start_stage.
var boon_global_dmg_mult: float = 1.0
var boon_global_hp_mult: float = 1.0
var boon_global_atk_speed_mult: float = 1.0       # >1 = faster (divides fire_rate_sec)
var boon_special_proc_mult: float = 1.0           # Elemental Surge — cleave/exec/slow chance
var boon_coin_mult: float = 1.0
var boon_berserker_rage: bool = false
var boon_vampiric_strike: bool = false
var boon_hero_synergy: bool = false
var boon_double_hero_drops: bool = false
var boon_periodic_hero_spawn: bool = false
var boon_chain_pop: bool = false
var boon_treasure_next_wave: bool = false
# One-shot flags consumed by the next stage / next hero.
var boon_first_hero_gold_pending: bool = false
var boon_next_hero_silver_plus_pending: bool = false
var boon_pending_extra_heroes_next_stage: int = 0
var boon_pending_extra_heroes_now: int = 0
var boon_time_stop_pending_sec: float = 0.0

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
	# Reset boon one-shots so old picks from prior runs don't leak.
	boon_first_hero_gold_pending = false
	boon_next_hero_silver_plus_pending = false
	boon_pending_extra_heroes_next_stage = 0
	boon_pending_extra_heroes_now = 0
	boon_time_stop_pending_sec = 0.0


func add_boon(boon_id: String) -> void:
	run_boons.append(boon_id)
	# One-shot effects (extra heroes next stage, time stop, etc.) need to fire
	# exactly once at the moment of pick, so record them now. Multiplier-type
	# effects are recomputed deterministically at every stage start.
	record_new_boon(boon_id)


# Reset all boon-derived multipliers/flags to defaults and replay run_boons.
# Idempotent — safe to call every stage start. Effects that are "one-shot"
# (e.g. spawn 3 heroes next stage) accumulate across stages via the run_boons
# replay but are decremented on consumption by MatchScene/Lane.
func recompute_boon_state() -> void:
	boon_global_dmg_mult = 1.0
	boon_global_hp_mult = 1.0
	boon_global_atk_speed_mult = 1.0
	boon_special_proc_mult = 1.0
	boon_coin_mult = 1.0
	boon_berserker_rage = false
	boon_vampiric_strike = false
	boon_hero_synergy = false
	boon_double_hero_drops = false
	boon_periodic_hero_spawn = false
	boon_chain_pop = false
	boon_treasure_next_wave = false
	# NOTE: pending one-shots are NOT reset here — they're set by MatchScene
	# only on freshly added boons (see record_new_boon) so they fire once.
	for id in run_boons:
		var key: String = BoonDB.get_effect_key(id)
		match key:
			"global_dmg_bonus":      boon_global_dmg_mult *= 1.10
			"global_dmg_bonus_15":   boon_global_dmg_mult *= 1.15
			"global_hp_bonus_20":    boon_global_hp_mult  *= 1.20
			"global_atk_speed_15":   boon_global_atk_speed_mult *= 1.15
			"global_special_proc_25":boon_special_proc_mult *= 1.25
			"coins_x1_5":            boon_coin_mult *= 1.5
			"berserker_rage":        boon_berserker_rage = true
			"vampiric_strike":       boon_vampiric_strike = true
			"hero_synergy":          boon_hero_synergy = true
			"double_hero_drops":     boon_double_hero_drops = true
			"periodic_hero_spawn":   boon_periodic_hero_spawn = true
			"cluster_chain_pop":     boon_chain_pop = true
			"treasure_next_wave":    boon_treasure_next_wave = true
			_: pass  # other effects applied directly on Cannon / Lane / MatchScene


# Called by MatchScene when a boon is freshly added (one-shot setup).
func record_new_boon(boon_id: String) -> void:
	var key: String = BoonDB.get_effect_key(boon_id)
	match key:
		"first_hero_gold":           boon_first_hero_gold_pending = true
		"next_hero_silver_plus":     boon_next_hero_silver_plus_pending = true
		"spawn_3_heroes_next_stage": boon_pending_extra_heroes_next_stage += 3
		"spawn_1_hero_now":          boon_pending_extra_heroes_now += 1
		"time_stop_10s":             boon_time_stop_pending_sec += 10.0
		_: pass


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
