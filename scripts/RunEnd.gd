# RunEnd — screen 8 (v1-ui-flow §3.8).
# Stats + log_run_end + CONTINUE → MetaHub.

extends Control

signal continue_pressed

@onready var _title: Label = $Title
@onready var _stats: Label = $Stats
@onready var _continue_button: Button = $ContinueButton

func _ready() -> void:
	_continue_button.pressed.connect(func(): continue_pressed.emit())

func setup() -> void:
	# Title reflects completion kind.
	match RunState.completion:
		"win":  _title.text = "RUN COMPLETE"
		"fail": _title.text = "RUN OVER"
		"quit": _title.text = "RUN QUIT"
		_:      _title.text = "RUN ENDED"
	_stats.text = "Stages cleared:   %d / 5\nBubbles fired:    %d\nHeroes spawned:   %d\nEnemies defeated: %d\nColor frenzies:   %d\nBest chain:       %d" % [
		RunState.stages_cleared,
		RunState.total_bubbles_fired,
		RunState.total_heroes_spawned,
		RunState.total_enemies_killed,
		RunState.total_frenzies,
		RunState.run_max_chain,
	]
	Telemetry.log_run_end(
		RunState.stages_cleared,
		RunState.total_run_ms(),
		RunState.total_pops,
		RunState.total_bubbles_lost,
		RunState.total_heroes_spawned,
		RunState.total_enemies_killed,
		RunState.total_frenzies,
		RunState.run_max_chain,
		RunState.completion,
	)
