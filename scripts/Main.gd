# Main — top-level screen router (v1-ui-flow §2 + §9.2 chapter UI).
#
# Owns the screen flow:
#   Boot → MetaHub → ChapterMap → StageSelect → MatchScene →
#     (StageClear | StageFail) → [RealmComplete if R{n}S5 win] → ChapterMap
# Pause is overlaid on MatchScene (PauseOverlay.tscn). Quit-run goes to RunEnd.

extends Node2D

const META_HUB_SCENE        := preload("res://scenes/MetaHub.tscn")
const CHAPTER_MAP_SCENE     := preload("res://scenes/ChapterMap.tscn")
const STAGE_SELECT_SCENE    := preload("res://scenes/StageSelect.tscn")
const MATCH_SCENE           := preload("res://scenes/MatchScene.tscn")
const STAGE_CLEAR_SCENE     := preload("res://scenes/StageClear.tscn")
const STAGE_FAIL_SCENE      := preload("res://scenes/StageFail.tscn")
const RUN_END_SCENE         := preload("res://scenes/RunEnd.tscn")
const REALM_COMPLETE_SCENE  := preload("res://scenes/RealmComplete.tscn")

var _current: Node = null
var _match_pending_stage: int = 1
var _match_pending_realm: int = 1

@onready var _screen_root: Node = $ScreenRoot

func _ready() -> void:
	Telemetry.start_session("dev")
	_show_meta_hub()

# ============================================================
# Screen factory
# ============================================================
func _swap_to(node: Node) -> void:
	if _current != null:
		_current.queue_free()
	_current = node
	_screen_root.add_child(node)

func _show_meta_hub() -> void:
	var s: Control = META_HUB_SCENE.instantiate()
	s.play_pressed.connect(_on_play_pressed)
	_swap_to(s)

func _on_play_pressed() -> void:
	_show_chapter_map()

func _show_chapter_map() -> void:
	var s = CHAPTER_MAP_SCENE.instantiate()
	s.realm_selected.connect(_on_realm_selected)
	s.back_pressed.connect(_show_meta_hub)
	_swap_to(s)

func _on_realm_selected(realm: int) -> void:
	_show_stage_select(realm)

func _show_stage_select(realm: int) -> void:
	var s = STAGE_SELECT_SCENE.instantiate()
	s.stage_selected.connect(_on_stage_selected)
	s.back_pressed.connect(_show_chapter_map)
	_swap_to(s)
	s.setup(realm)

func _on_stage_selected(realm: int, stage: int) -> void:
	RunState.begin_new_run(realm)
	_match_pending_realm = realm
	_match_pending_stage = stage
	_show_match()

func _show_match() -> void:
	var m: MatchScene = MATCH_SCENE.instantiate()
	m.start_realm_num = _match_pending_realm
	m.start_stage_num = _match_pending_stage
	m.stage_cleared.connect(_on_stage_cleared)
	m.stage_failed.connect(_on_stage_failed)
	m.quit_run_requested.connect(_on_quit_run_requested)
	_swap_to(m)

func _show_stage_clear(realm: int, stage: int) -> void:
	var s = STAGE_CLEAR_SCENE.instantiate()
	s.boon_picked.connect(_on_boon_picked)
	_swap_to(s)
	s.setup(stage)
	# Suppress an unused-var warning — realm is here for future per-realm rewards.
	_match_pending_realm = realm

func _show_stage_fail(stage_num: int) -> void:
	var s = STAGE_FAIL_SCENE.instantiate()
	s.end_run_pressed.connect(_show_run_end)
	_swap_to(s)
	s.setup(stage_num)

func _show_run_end() -> void:
	var s = RUN_END_SCENE.instantiate()
	s.continue_pressed.connect(_show_chapter_map)
	_swap_to(s)
	s.setup()

func _show_realm_complete(realm: int) -> void:
	var s = REALM_COMPLETE_SCENE.instantiate()
	s.continue_pressed.connect(_show_chapter_map)
	_swap_to(s)
	s.setup(realm)

# ============================================================
# Match → screen flow
# ============================================================
func _on_stage_cleared(stage_num: int) -> void:
	var cleared_realm: int = _match_pending_realm
	if stage_num >= RunState.STAGES_PER_REALM:
		# Realm boss cleared.
		RunState.finish_run("win")
		# Show RealmComplete (which also gates next-realm reveal). Then
		# ChapterMap. If R5S5, go to RunEnd instead for the final celebration.
		if cleared_realm >= RunState.REALM_COUNT:
			_show_run_end()
		else:
			_show_realm_complete(cleared_realm)
	else:
		# Mid-realm clear → boon pick, then next stage.
		_match_pending_stage = stage_num + 1
		_show_stage_clear(cleared_realm, stage_num)

func _on_stage_failed(stage_num: int, _reason: String) -> void:
	RunState.finish_run("fail")
	_show_stage_fail(stage_num)

func _on_quit_run_requested(stage_num: int) -> void:
	RunState.last_stage_reached = stage_num
	RunState.finish_run("quit")
	_show_run_end()

func _on_boon_picked(_boon_id: String) -> void:
	# Next stage uses the same realm with the new boon stack via RunState.run_boons.
	_show_match()
