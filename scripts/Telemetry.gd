# Telemetry — autoload singleton
#
# Logs every gameplay event to a JSONL file per session.
# Schema mirrors design spec §6.2 exactly.
#
# Output location:
#   user://logs/pop-brigade-v1-<tester_id>-<utc_ts>.jsonl
#   On macOS: ~/Library/Application Support/Godot/app_userdata/Pop Brigade v1/logs/
#
# Tester workflow:
#   1. Set tester_id at session start (call Telemetry.start_session("T07"))
#   2. Gameplay code calls log_event("event_name", { payload })
#   3. Session ends → file is closed + path printed to console
#   4. Facilitator pulls .jsonl off device for analysis

extends Node

var _file: FileAccess = null
var _tester_id: String = "unknown"
var _session_start_ms: int = 0
var _file_path: String = ""

# Sample 1-in-N for hero_attack events to keep volume manageable (§6.2 note)
const HERO_ATTACK_SAMPLE_RATE: int = 10
var _attack_counter: int = 0


func start_session(tester_id: String) -> void:
	_tester_id = tester_id
	_session_start_ms = Time.get_ticks_msec()
	var ts := Time.get_datetime_string_from_system(true).replace(":", "-")
	var dir := "user://logs"
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	_file_path = "%s/pop-brigade-v1-%s-%s.jsonl" % [dir, tester_id, ts]
	_file = FileAccess.open(_file_path, FileAccess.WRITE)
	if _file == null:
		push_error("Telemetry: failed to open log file at " + _file_path)
		return
	log_event("session_start", {
		"tester_id": tester_id,
		"build_version": ProjectSettings.get_setting("application/config/version", "v1-greybox"),
		"device_model": OS.get_model_name(),
		"os_version":   OS.get_version(),
	})


func end_session(runs_completed: int) -> void:
	if _file == null: return
	log_event("session_end", {
		"runs_completed": runs_completed,
		"total_session_ms": Time.get_ticks_msec() - _session_start_ms,
	})
	_file.close()
	print("[Telemetry] Session log written to: ", _file_path)
	_file = null


# Core logger — every event flows through here.
func log_event(event_name: String, payload: Dictionary = {}) -> void:
	if _file == null:
		# Allow logging before session starts during development;
		# print so engineer sees events but doesn't crash.
		print("[Telemetry/no-session] %s %s" % [event_name, payload])
		return
	# §6.2 sampling: hero_attack is volume-heavy, sample 1-in-10.
	if event_name == "hero_attack":
		_attack_counter += 1
		if _attack_counter % HERO_ATTACK_SAMPLE_RATE != 0:
			return
	var line := {
		"event_name": event_name,
		"ts_ms": Time.get_ticks_msec() - _session_start_ms,
	}
	for k in payload:
		line[k] = payload[k]
	_file.store_line(JSON.stringify(line))


# ============================================================
# Typed convenience wrappers — match §6.2 payload schema exactly.
# Use these so payload field names stay consistent across the codebase.
# ============================================================

func log_loadout_pick(cannon_color: int) -> void:
	log_event("loadout_pick", { "cannon_color": cannon_color })

func log_stage_start(stage_num: int, cluster_start_rows: int, hp: int, heroes_carried_in: int = 0) -> void:
	log_event("stage_start", {
		"stage_num": stage_num,
		"cluster_start_rows": cluster_start_rows,
		"hp": hp,
		"heroes_carried_in": heroes_carried_in,
	})

func log_phase1_start(stage_num: int, cluster_start_rows: int, heroes_carried_in: int) -> void:
	log_event("phase1_start", {
		"stage_num": stage_num,
		"cluster_start_rows": cluster_start_rows,
		"heroes_carried_in": heroes_carried_in,
	})

func log_phase1_end(stage_num: int, ms_elapsed: int, reason: String,
		heroes_built_total: int, heroes_by_color: Dictionary,
		bubbles_fired: int, bubbles_popped: int, bubbles_lost: int,
		max_chain: int, frenzied_colors: Array) -> void:
	# reason ∈ { "cluster_cleared", "time_cap", "descent_complete" }
	log_event("phase1_end", {
		"stage_num": stage_num,
		"ms_elapsed": ms_elapsed,
		"reason": reason,
		"heroes_built_total": heroes_built_total,
		"heroes_by_color": heroes_by_color,
		"bubbles_fired": bubbles_fired,
		"bubbles_popped": bubbles_popped,
		"bubbles_lost": bubbles_lost,
		"max_chain": max_chain,
		"frenzied_colors": frenzied_colors,
	})

func log_phase2_start(stage_num: int, hero_count: int, hero_composition: Dictionary,
		wave_size: int, wave_composition: Dictionary) -> void:
	log_event("phase2_start", {
		"stage_num": stage_num,
		"hero_count": hero_count,
		"hero_composition": hero_composition,
		"wave_size": wave_size,
		"wave_composition": wave_composition,
	})

func log_phase2_end(stage_num: int, ms_elapsed: int, result: String,
		hp_remaining: int, enemies_killed: int, enemies_leaked: int, heroes_lost: int) -> void:
	# result ∈ { "clear", "fail" }
	log_event("phase2_end", {
		"stage_num": stage_num,
		"ms_elapsed": ms_elapsed,
		"result": result,
		"hp_remaining": hp_remaining,
		"enemies_killed": enemies_killed,
		"enemies_leaked": enemies_leaked,
		"heroes_lost": heroes_lost,
	})

func log_bubble_fired(stage_num: int, bubble_color: int, queue_swap_used: bool,
		aim_angle_deg: float, time_to_fire_ms: int) -> void:
	log_event("bubble_fired", {
		"stage_num": stage_num,
		"bubble_color": bubble_color,
		"queue_swap_used": queue_swap_used,
		"aim_angle_deg": aim_angle_deg,
		"time_to_fire_ms": time_to_fire_ms,
	})

func log_bubble_attached(bubble_color: int, attached_row: int, attached_col: int,
		cluster_size_after: int) -> void:
	log_event("bubble_attached", {
		"bubble_color": bubble_color,
		"attached_row": attached_row,
		"attached_col": attached_col,
		"cluster_size_after": cluster_size_after,
	})

func log_match_pop(match_size: int, color: int, cascade_chain_count: int,
		heroes_spawned: Array) -> void:
	log_event("match_pop", {
		"match_size": match_size,
		"color": color,
		"cascade_chain_count": cascade_chain_count,
		"heroes_spawned": heroes_spawned,
	})

func log_cluster_descend(rows_now: int, time_since_last_descend_ms: int) -> void:
	log_event("cluster_descend", {
		"rows_now": rows_now,
		"time_since_last_descend_ms": time_since_last_descend_ms,
	})

func log_bubble_lost_below_line(color: int, source: String) -> void:
	# Phase 1 only — bubble vanished without producing a hero or enemy.
	# source ∈ { "descent", "below_line_fire" }
	# Replaces the deprecated log_bubble_converted_to_enemy (V2 design, removed 2026-05-12).
	log_event("bubble_lost_below_line", {
		"color": color,
		"source": source,
	})

func log_hero_spawn(color: int, tier: String, lane_col: int, lane_row: int, source: String) -> void:
	# tier ∈ { "bronze", "silver", "gold" }
	# source ∈ { "match", "cascade", "carryover" }
	log_event("hero_spawn", {
		"color": color, "tier": tier,
		"lane_col": lane_col, "lane_row": lane_row,
		"source": source,
	})

func log_hero_attack(hero_id: int, target_id: int, damage_dealt: int) -> void:
	log_event("hero_attack", {
		"hero_id": hero_id, "target_id": target_id, "damage_dealt": damage_dealt,
	})

func log_hero_death(hero_id: int, color: int, tier: String, lifetime_ms: int, damage_total: int) -> void:
	log_event("hero_death", {
		"hero_id": hero_id, "color": color, "tier": tier,
		"lifetime_ms": lifetime_ms, "damage_dealt_total": damage_total,
	})

func log_enemy_spawn(enemy_id: int, color: int, lane_col: int, lane_row_top: int, wave_index: int = -1) -> void:
	log_event("enemy_spawn", {
		"enemy_id": enemy_id, "color": color,
		"lane_col": lane_col, "lane_row_top": lane_row_top,
		"wave_index": wave_index,
	})

func log_enemy_death(enemy_id: int, color: int, killed_by_color: int, lifetime_ms: int) -> void:
	log_event("enemy_death", {
		"enemy_id": enemy_id, "color": color,
		"killed_by_color": killed_by_color, "lifetime_ms": lifetime_ms,
	})

func log_enemy_reached_cannon(enemy_id: int, color: int, hp_damage: int) -> void:
	log_event("enemy_reached_cannon", {
		"enemy_id": enemy_id, "color": color, "hp_damage": hp_damage,
	})

func log_color_frenzy(color: int, heroes_at_trigger_count: int) -> void:
	# Triggered in Phase 1 when a color is fully cleared from the cluster.
	# Buff persists through Phase 2 (does not expire mid-combat in V8 design).
	log_event("color_frenzy_trigger", {
		"color": color, "heroes_at_trigger_count": heroes_at_trigger_count,
	})

func log_boon_picked(stage_num: int, boon_id: String, alternatives: Array) -> void:
	log_event("boon_picked", {
		"stage_num": stage_num,
		"boon_id": boon_id,
		"alternatives": alternatives,
	})

func log_stage_clear(stage_num: int, hp_remaining: int, total_ms: int,
		p1_ms: int, p2_ms: int,
		total_pops: int, total_misses: int, max_chain: int) -> void:
	log_event("stage_clear", {
		"stage_num": stage_num, "hp_remaining": hp_remaining,
		"total_ms": total_ms, "p1_ms": p1_ms, "p2_ms": p2_ms,
		"total_pops": total_pops, "total_misses": total_misses, "max_chain": max_chain,
	})

func log_stage_fail(stage_num: int, hp_remaining: int, reason: String, ms_elapsed: int) -> void:
	# V8 design: only "hp" is a fail reason. Cluster reaching the lane in Phase 1
	# is no longer a fail — Phase 1 just ends and Phase 2 begins.
	# reason ∈ { "hp" }
	log_event("stage_fail", {
		"stage_num": stage_num, "hp_remaining": hp_remaining,
		"reason": reason, "ms_elapsed": ms_elapsed,
	})

func log_run_end(stages_cleared: int, total_ms: int, total_pops: int, total_misses: int,
		total_heroes: int, total_enemies_killed: int, total_frenzies: int,
		max_chain: int, completion: String) -> void:
	# completion ∈ { "win", "fail", "quit" }
	log_event("run_end", {
		"stages_cleared": stages_cleared,
		"total_ms": total_ms,
		"total_pops": total_pops, "total_misses": total_misses,
		"total_heroes": total_heroes, "total_enemies_killed": total_enemies_killed,
		"total_frenzies": total_frenzies, "max_chain": max_chain,
		"completion": completion,
	})

func log_pause_open(stage_num: int, phase: int, ms_into_stage: int) -> void:
	# phase ∈ { 1, 2 }
	log_event("pause_open", { "stage_num": stage_num, "phase": phase, "ms_into_stage": ms_into_stage })

func log_pause_resume(pause_duration_ms: int) -> void:
	log_event("pause_resume", { "pause_duration_ms": pause_duration_ms })
