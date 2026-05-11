# Main — top-level screen switcher (§ UI flow doc §2).
# v1 has 8 screens. This is the scene that loads on app boot.
#
# For W1, this just shows a "Pop Brigade v1 scaffold loaded" label
# so the project opens and runs without errors.
# Replace with full screen-switching logic in W3.

extends Node2D

@onready var status_label: Label = $StatusLabel

func _ready() -> void:
	var cfg_ok := Engine.has_singleton("GameConfig") or get_node_or_null("/root/GameConfig") != null
	var tel_ok := Engine.has_singleton("Telemetry") or get_node_or_null("/root/Telemetry") != null
	status_label.text = "Pop Brigade v1 — scaffold loaded\n\n" \
		+ "GameConfig autoload: " + ("✓" if cfg_ok else "✗") + "\n" \
		+ "Telemetry autoload:  " + ("✓" if tel_ok else "✗") + "\n\n" \
		+ "Cluster descent rate: " + str(GameConfig.cluster_descent_rate_sec) + "s\n" \
		+ "Stage 1 start rows:   " + str(GameConfig.get_stage_start_rows(1)) + "\n\n" \
		+ "▶ TAP ANYWHERE to enter MatchScene"
	Telemetry.start_session("dev")

func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed):
		get_tree().change_scene_to_file("res://scenes/MatchScene.tscn")
	# TODO §UI 2: full screen switching:
	#   Boot → MetaHub → Loadout → Match → (Clear|Fail) → RunEnd → MetaHub
