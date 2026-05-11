# Bubble — single bubble entity (in flight or attached to cluster).
# Design spec §3.2 (cluster) and §3.3 (aim/fire).

class_name Bubble
extends Area2D

signal attached_to_cluster(row: int, col: int)
signal converted_to_enemy(color: int, lane_col: int)

@export_enum("Red", "Blue", "Yellow") var color: int = 0
@export var is_special_color_bomb: bool = false

var grid_row: int = -1
var grid_col: int = -1
var velocity: Vector2 = Vector2.ZERO
var in_flight: bool = false

@onready var sprite: ColorRect = $Sprite

# TODO §3.3: When fired, set velocity and is_flight=true. Move in _physics_process.
# TODO §3.2: On collision with cluster bubble or top wall, call attach_to_grid(row, col).
# TODO §3.3: On collision with side wall, reflect velocity.x (ricochet).
# TODO §3.2: If attaching below spawn line, emit converted_to_enemy() instead.

func _ready() -> void:
	_apply_color()

func set_color(c: int) -> void:
	color = c
	if sprite:
		_apply_color()

func _apply_color() -> void:
	if sprite == null: return
	if is_special_color_bomb:
		sprite.color = Color(1, 1, 1, 1)  # placeholder for rainbow; later: shader
		return
	match color:
		GameConfig.BubbleColor.RED:    sprite.color = Color.html("#e74c3c")
		GameConfig.BubbleColor.BLUE:   sprite.color = Color.html("#3498db")
		GameConfig.BubbleColor.YELLOW: sprite.color = Color.html("#f1c40f")

func attach_to_grid(row: int, col: int) -> void:
	grid_row = row
	grid_col = col
	in_flight = false
	velocity = Vector2.ZERO
	emit_signal("attached_to_cluster", row, col)

# Place this bubble into a Cluster's local grid at the given local position.
# Used by the W1 debug harness (tap-to-place) and by W2 flight-collision code.
# Reparents into `new_parent` if not already a child.
func attach_to_grid_cell(new_parent: Node, row: int, col: int, local_pos: Vector2) -> void:
	if get_parent() != new_parent:
		if get_parent() != null:
			get_parent().remove_child(self)
		new_parent.add_child(self)
	position = local_pos
	attach_to_grid(row, col)
