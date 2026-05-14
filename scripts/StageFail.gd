# StageFail — screen 7 (v1-ui-flow §3.7).
# Two options: RETRY STAGE re-enters the failed stage with the run's boons
# and heroes intact (HP refills since you died). END RUN → RunEnd.

extends Control

signal end_run_pressed
signal retry_pressed(stage_num: int)

var _stage_num: int = 1

@onready var _reached_label: Label = $Modal/Reached
@onready var _end_button: Button = $Modal/EndButton
@onready var _retry_button: Button = $Modal/RetryButton

func _ready() -> void:
	_end_button.pressed.connect(func(): end_run_pressed.emit())
	_retry_button.pressed.connect(func(): retry_pressed.emit(_stage_num))

func setup(stage_reached: int) -> void:
	_stage_num = stage_reached
	_reached_label.text = "Reached Stage %d/5" % stage_reached
