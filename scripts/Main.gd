# Main — top-level screen router (v1-ui-flow §2).
#
# Owns the eight-screen flow:
#   Boot → MetaHub → Loadout → MatchScene → (StageClear | StageFail) → RunEnd → MetaHub
# Pause is overlaid on MatchScene itself (PauseOverlay.tscn) and can quit-run
# back to RunEnd directly.

extends Node2D

const META_HUB_SCENE   := preload("res://scenes/MetaHub.tscn")
const MATCH_SCENE      := preload("res://scenes/MatchScene.tscn")
const STAGE_CLEAR_SCENE := preload("res://scenes/StageClear.tscn")
const STAGE_FAIL_SCENE  := preload("res://scenes/StageFail.tscn")
const RUN_END_SCENE     := preload("res://scenes/RunEnd.tscn")

var _current: Node = null
var _match_pending_stage: int = 1

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
	RunState.begin_new_run()
	_match_pending_stage = 1
	_show_match()

func _show_match() -> void:
	var m: MatchScene = MATCH_SCENE.instantiate()
	m.start_stage_num = _match_pending_stage
	m.stage_cleared.connect(_on_stage_cleared)
	m.stage_failed.connect(_on_stage_failed)
	m.quit_run_requested.connect(_on_quit_run_requested)
	_swap_to(m)

func _show_stage_clear(stage_num: int) -> void:
	var s = STAGE_CLEAR_SCENE.instantiate()
	s.boon_picked.connect(_on_boon_picked)
	_swap_to(s)
	s.setup(stage_num)

func _show_stage_fail(stage_num: int) -> void:
	var s = STAGE_FAIL_SCENE.instantiate()
	s.end_run_pressed.connect(_show_run_end)
	_swap_to(s)
	s.setup(stage_num)

func _show_run_end() -> void:
	var s = RUN_END_SCENE.instantiate()
	s.continue_pressed.connect(_show_meta_hub)
	_swap_to(s)
	s.setup()

# ============================================================
# Match → screen flow
# ============================================================
func _on_stage_cleared(stage_num: int) -> void:
	if stage_num >= 5:
		# Final stage clear = run win. Skip boon pick, go straight to RunEnd.
		RunState.finish_run("win")
		_show_run_end()
	else:
		_match_pending_stage = stage_num + 1
		_show_stage_clear(stage_num)

func _on_stage_failed(stage_num: int, _reason: String) -> void:
	RunState.finish_run("fail")
	_show_stage_fail(stage_num)

func _on_quit_run_requested(stage_num: int) -> void:
	RunState.last_stage_reached = stage_num
	RunState.finish_run("quit")
	_show_run_end()

func _on_boon_picked(_boon_id: String) -> void:
	# Next stage starts with the new boon stack applied via RunState.run_boons.
	_show_match()
