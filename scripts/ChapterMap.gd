# ChapterMap — §9.2 realm select.
# 5 realm tiles, vertically stacked. Each tile shows realm name, theme color,
# star count (e.g. ★★★★★ 15/15), state (locked/available/completed).

extends Control

signal realm_selected(realm: int)
signal back_pressed

const TILE_HEIGHT: float = 200.0

@onready var _tiles: VBoxContainer = $Tiles
@onready var _back_button: Button = $BackButton

func _ready() -> void:
	_back_button.pressed.connect(func(): back_pressed.emit())
	_build_tiles()

func _build_tiles() -> void:
	for child in _tiles.get_children():
		child.queue_free()
	for r in range(1, RunState.REALM_COUNT + 1):
		_tiles.add_child(_build_tile(r))

func _build_tile(realm: int) -> Control:
	var unlocked: bool = RunState.is_realm_unlocked(realm)
	var completed: bool = RunState.is_realm_completed(realm)
	var stars: int = RunState.total_stars_in_realm(realm)
	var max_stars: int = RunState.STAGES_PER_REALM * 3
	var tile := Button.new()
	tile.custom_minimum_size = Vector2(0, TILE_HEIGHT)
	tile.focus_mode = Control.FOCUS_NONE
	tile.disabled = not unlocked
	tile.text = ""
	# Style the button background by realm theme color.
	var base_color: Color = GameConfig.realm_theme_color(realm)
	var bg := StyleBoxFlat.new()
	if not unlocked:
		bg.bg_color = Color(0.15, 0.15, 0.18, 1)
		bg.border_color = Color(0.30, 0.30, 0.35, 1)
	elif completed:
		bg.bg_color = base_color.darkened(0.10)
		bg.border_color = Color(1.0, 0.84, 0.20, 1)
	else:
		bg.bg_color = base_color.darkened(0.30)
		bg.border_color = base_color.lightened(0.20)
	bg.set_border_width_all(4)
	bg.set_corner_radius_all(16)
	var hover := bg.duplicate() as StyleBoxFlat
	hover.bg_color = bg.bg_color.lightened(0.10)
	var pressed := bg.duplicate() as StyleBoxFlat
	pressed.bg_color = bg.bg_color.darkened(0.10)
	tile.add_theme_stylebox_override("normal",  bg)
	tile.add_theme_stylebox_override("hover",   hover)
	tile.add_theme_stylebox_override("pressed", pressed)
	tile.add_theme_stylebox_override("disabled", bg)
	# Realm label.
	var name_lbl := Label.new()
	name_lbl.text = "R%d · %s" % [realm, GameConfig.realm_name(realm)]
	name_lbl.add_theme_font_size_override("font_size", 36)
	name_lbl.add_theme_color_override("font_color",
		Color(1, 1, 1, 1.0 if unlocked else 0.40))
	name_lbl.position = Vector2(24, 18)
	name_lbl.size = Vector2(560, 50)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(name_lbl)
	# Boss name.
	var boss_lbl := Label.new()
	boss_lbl.text = "boss: %s" % GameConfig.boss_name(realm)
	boss_lbl.add_theme_font_size_override("font_size", 22)
	boss_lbl.add_theme_color_override("font_color",
		Color(0.95, 0.90, 0.65, 1.0 if unlocked else 0.30))
	boss_lbl.position = Vector2(24, 72)
	boss_lbl.size = Vector2(560, 32)
	boss_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(boss_lbl)
	# Star count.
	var stars_lbl := Label.new()
	var glyph_count: int = clamp(stars, 0, max_stars)
	stars_lbl.text = "%s   %d / %d" % [
		"★".repeat(glyph_count) + "☆".repeat(max(0, max_stars - glyph_count)),
		stars, max_stars,
	]
	stars_lbl.add_theme_font_size_override("font_size", 24)
	stars_lbl.add_theme_color_override("font_color",
		Color(1.0, 0.85, 0.20, 1.0 if unlocked else 0.30))
	stars_lbl.position = Vector2(24, 110)
	stars_lbl.size = Vector2(560, 32)
	stars_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(stars_lbl)
	# State pill.
	var state_lbl := Label.new()
	if not unlocked:
		state_lbl.text = "🔒 LOCKED"
		state_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.60, 1))
	elif completed:
		state_lbl.text = "✓ COMPLETED"
		state_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.30, 1))
	else:
		state_lbl.text = "▶ AVAILABLE"
		state_lbl.add_theme_color_override("font_color", Color(0.55, 1.0, 0.55, 1))
	state_lbl.add_theme_font_size_override("font_size", 22)
	state_lbl.position = Vector2(24, 150)
	state_lbl.size = Vector2(560, 32)
	state_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(state_lbl)
	tile.pressed.connect(func():
		if unlocked: realm_selected.emit(realm))
	return tile
