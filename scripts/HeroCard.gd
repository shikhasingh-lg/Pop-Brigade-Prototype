# HeroCard — display widget for a named hero portrait.
#
# Use as a child node anywhere you need to show a hero by slug:
# selection screens, lane portraits, post-game results, debug overlays.
#
# Set `hero_slug` in the Inspector or call `set_hero(slug)` at runtime.

class_name HeroCard
extends Control

@export var hero_slug: String = "fire-knight":
	set(value):
		hero_slug = value
		if is_inside_tree():
			_refresh()

@export var show_name: bool = true:
	set(value):
		show_name = value
		if is_inside_tree():
			_refresh()

# true  → transparent cutout (lane sprites, dark UIs)
# false → white-bg portrait (light card UIs)
@export var use_cutout: bool = true:
	set(value):
		use_cutout = value
		if is_inside_tree():
			_refresh()

@onready var _portrait: TextureRect = $Portrait
@onready var _name_label: Label = $NameLabel

func _ready() -> void:
	_refresh()

func set_hero(slug: String) -> void:
	hero_slug = slug

func _refresh() -> void:
	var entry: Dictionary = HeroRoster.get_entry(hero_slug)
	if entry.is_empty():
		push_warning("HeroCard: unknown slug '%s'" % hero_slug)
		return
	_portrait.texture = HeroRoster.get_cutout(hero_slug) if use_cutout else HeroRoster.get_portrait(hero_slug)
	_name_label.text = entry["name"]
	_name_label.visible = show_name
