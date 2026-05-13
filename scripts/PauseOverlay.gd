# PauseOverlay — screen 5 (v1-ui-flow §3.5).
# Sets get_tree().paused = true while shown. RESUME unpauses; QUIT emits quit_run.

extends Control

signal resume_pressed
signal quit_run_pressed

var _pause_open_ms: int = 0

@onready var _resume_btn: Button = $Modal/Resume
@onready var _quit_btn: Button = $Modal/Quit

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # respond while tree is paused
	_resume_btn.pressed.connect(_on_resume)
	_quit_btn.pressed.connect(_on_quit)
	visible = false

func open(stage_num: int, phase: int, ms_into_stage: int) -> void:
	Telemetry.log_pause_open(stage_num, phase, ms_into_stage)
	_pause_open_ms = Time.get_ticks_msec()
	visible = true
	get_tree().paused = true

func _on_resume() -> void:
	_close()
	resume_pressed.emit()

func _on_quit() -> void:
	_close()
	quit_run_pressed.emit()

func _close() -> void:
	get_tree().paused = false
	visible = false
	var duration: int = Time.get_ticks_msec() - _pause_open_ms
	Telemetry.log_pause_resume(duration)
