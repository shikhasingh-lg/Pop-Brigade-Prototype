# BubbleVisual — renders a bubble cutout texture for HUD slots
# (cannon's loaded shot + on-deck preview). Heroes/enemies remain rectangular.
#
# Texture is resolved through the BubbleRoster autoload, so adding v2 colors
# (GREEN, PURPLE) requires no edits here — just drop assets in place and
# update BubbleRoster.

class_name BubbleVisual
extends Node2D

# Display radius (px). Cannon HUD slot is ~22 px so the texture renders at 44×44.
@export var radius: float = 22.0:
	set(v):
		radius = v
		queue_redraw()

# BubbleColor enum (RED=0, BLUE=1, YELLOW=2, GREEN=3 v2, PURPLE=4 v2).
# Set by Cannon._refresh_queue_visuals.
@export var bubble_color: int = 0:
	set(v):
		bubble_color = v
		queue_redraw()

const _VISUAL_OVERSIZE := 1.7  # texture has transparent padding around the bubble

func _draw() -> void:
	var tex: Texture2D = BubbleRoster.get_cutout(bubble_color)
	if tex == null:
		return
	var half: float = radius * _VISUAL_OVERSIZE
	var rect := Rect2(Vector2(-half, -half), Vector2(half * 2.0, half * 2.0))
	draw_texture_rect(tex, rect, false)

# Compatibility setter — Cannon used to pass an engine Color. Kept as a no-op
# fallback in case anything else calls it; prefer set_bubble_color(int).
func set_color(_c: Color) -> void:
	pass

func set_bubble_color(c: int) -> void:
	bubble_color = c
