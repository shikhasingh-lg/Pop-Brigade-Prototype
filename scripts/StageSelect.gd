# StageSelect — §9.2 stage select.
# 5 stage nodes per realm + star display + locked/available state.

extends Control

signal stage_selected(realm: int, stage: int)
signal back_pressed

const STAGE_BUTTON_HEIGHT: float = 180.0

var realm_num: int = 1

@onready var _title: Label = $Title
@onready var _subtitle: Label = $Subtitle
@onready var _stages_root: VBoxContainer = $Stages
@onready var _back_button: Button = $BackButton

func _ready() -> void:
	_back_button.pressed.connect(func(): back_pressed.emit())

func setup(realm: int) -> void:
	realm_num = clamp(realm, 1, RunState.REALM_COUNT)
	_title.text = "R%d · %s" % [realm_num, GameConfig.realm_name(realm_num)]
	_title.add_theme_color_override("font_color",
		GameConfig.realm_theme_color(realm_num).lightened(0.30))
	_subtitle.text = "boss: %s" % GameConfig.boss_name(realm_num)
	_build_stage_buttons()

func _build_stage_buttons() -> void:
	for child in _stages_root.get_children():
		child.queue_free()
	for s in range(1, RunState.STAGES_PER_REALM + 1):
		_stages_root.add_child(_build_stage_button(s))

func _build_stage_button(stage: int) -> Control:
	var unlocked: bool = RunState.is_stage_unlocked(realm_num, stage)
	var stars: int = RunState.get_stars(realm_num, stage)
	var is_boss_stage: bool = stage >= RunState.STAGES_PER_REALM
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, STAGE_BUTTON_HEIGHT)
	btn.focus_mode = Control.FOCUS_NONE
	btn.disabled = not unlocked
	btn.text = ""
	# Style.
	var base_color: Color = GameConfig.realm_theme_color(realm_num)
	var bg := StyleBoxFlat.new()
	if not unlocked:
		bg.bg_color = Color(0.15, 0.15, 0.18, 1)
		bg.border_color = Color(0.30, 0.30, 0.35, 1)
	elif is_boss_stage:
		bg.bg_color = Color(0.45, 0.18, 0.18, 1)
		bg.border_color = Color(1.0, 0.55, 0.30, 1)
	else:
		bg.bg_color = base_color.darkened(0.45)
		bg.border_color = base_color.lightened(0.10)
	bg.set_border_width_all(4 if is_boss_stage else 3)
	bg.set_corner_radius_all(14)
	if is_boss_stage and unlocked:
		bg.shadow_color = Color(1.0, 0.55, 0.30, 0.8)
		bg.shadow_size = 10
	var hover := bg.duplicate() as StyleBoxFlat
	hover.bg_color = bg.bg_color.lightened(0.12)
	var pressed := bg.duplicate() as StyleBoxFlat
	pressed.bg_color = bg.bg_color.darkened(0.10)
	btn.add_theme_stylebox_override("normal",  bg)
	btn.add_theme_stylebox_override("hover",   hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", bg)
	# Stage label.
	var name_lbl := Label.new()
	if is_boss_stage:
		name_lbl.text = "S%d · BOSS · %s" % [stage, GameConfig.boss_name(realm_num)]
	else:
		name_lbl.text = "Stage %d" % stage
	name_lbl.add_theme_font_size_override("font_size", 32)
	name_lbl.add_theme_color_override("font_color",
		Color(1, 1, 1, 1.0 if unlocked else 0.40))
	name_lbl.position = Vector2(22, 22)
	name_lbl.size = Vector2(500, 42)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(name_lbl)
	# Stars.
	var stars_lbl := Label.new()
	stars_lbl.text = "★".repeat(stars) + "☆".repeat(3 - stars)
	stars_lbl.add_theme_font_size_override("font_size", 36)
	stars_lbl.add_theme_color_override("font_color",
		Color(1.0, 0.85, 0.20, 1.0 if unlocked else 0.30))
	stars_lbl.position = Vector2(22, 72)
	stars_lbl.size = Vector2(500, 42)
	stars_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(stars_lbl)
	# State pill.
	var state_lbl := Label.new()
	if not unlocked:
		state_lbl.text = "🔒 Beat the boss to replay"
		state_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.60, 1))
	elif stars == 0:
		state_lbl.text = "▶ New"
		state_lbl.add_theme_color_override("font_color", Color(0.55, 1.0, 0.55, 1))
	else:
		state_lbl.text = "↻ Replay (best: %s)" % ("★".repeat(stars))
		state_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 1.0, 1))
	state_lbl.add_theme_font_size_override("font_size", 20)
	state_lbl.position = Vector2(22, 122)
	state_lbl.size = Vector2(500, 32)
	state_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(state_lbl)
	btn.pressed.connect(func():
		if unlocked: stage_selected.emit(realm_num, stage))
	return btn
