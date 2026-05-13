# EnemyCard — display widget for a named enemy portrait.
# Mirrors HeroCard. Use anywhere you need to show an enemy by slug.

class_name EnemyCard
extends Control

@export var enemy_slug: String = "red-goblin":
	set(value):
		enemy_slug = value
		if is_inside_tree():
			_refresh()

@export var show_name: bool = true:
	set(value):
		show_name = value
		if is_inside_tree():
			_refresh()

@export var use_cutout: bool = true:
	set(value):
		use_cutout = value
		if is_inside_tree():
			_refresh()

@onready var _portrait: TextureRect = $Portrait
@onready var _name_label: Label = $NameLabel

func _ready() -> void:
	_refresh()

func set_enemy(slug: String) -> void:
	enemy_slug = slug

func _refresh() -> void:
	var entry: Dictionary = EnemyRoster.get_entry(enemy_slug)
	if entry.is_empty():
		push_warning("EnemyCard: unknown slug '%s'" % enemy_slug)
		return
	_portrait.texture = EnemyRoster.get_cutout(enemy_slug) if use_cutout else EnemyRoster.get_portrait(enemy_slug)
	_name_label.text = entry["name"]
	_name_label.visible = show_name
