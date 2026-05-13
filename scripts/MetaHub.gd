# MetaHub — screen 2 (v1-ui-flow §3.2).
# Single PLAY button, run counter, v1 build label.

extends Control

signal play_pressed

@onready var _runs_label: Label = $RunsLabel
@onready var _play_button: Button = $PlayButton

func _ready() -> void:
	_runs_label.text = "Runs completed: %d" % RunState.runs_completed
	_play_button.pressed.connect(func(): play_pressed.emit())
