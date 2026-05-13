# StageFail — screen 7 (v1-ui-flow §3.7).
# No retry. END RUN → RunEnd.

extends Control

signal end_run_pressed

@onready var _reached_label: Label = $Modal/Reached
@onready var _end_button: Button = $Modal/EndButton

func _ready() -> void:
	_end_button.pressed.connect(func(): end_run_pressed.emit())

func setup(stage_reached: int) -> void:
	_reached_label.text = "Reached Stage %d/5" % stage_reached
