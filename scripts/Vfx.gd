# Vfx — autoload helper module. Stateless. Every function spawns ephemeral
# nodes that tween + queue_free themselves.
#
# v1 minimum-viable VFX per v1-ui-flow §5:
#   pop_burst, spawn_flash, hit_flash, screen_shake, edge_tint_pulse
#
# All effects are deliberately cheap (one Node2D + one tween each) so they
# can fire dozens per second during a cascade without dragging frame time.

extends Node


# ----------------------------------------------------------------
# Pop burst — expanding colored ring at world_pos.
# Parent should be a Node2D in MatchScene-space so the ring sits on top
# of the cluster but under HUD overlays.
# ----------------------------------------------------------------
func pop_burst(parent: Node, world_pos: Vector2, color: Color, radius: float = 44.0) -> void:
	if parent == null or not is_instance_valid(parent): return
	var ring := _Ring.new()
	ring.fill_color = color
	ring.global_position = world_pos
	ring.z_index = 50
	parent.add_child(ring)
	var tw := ring.create_tween()
	tw.tween_property(ring, "scale", Vector2(1.0, 1.0) * (radius / 20.0), 0.22) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.22)
	tw.tween_callback(func(): if is_instance_valid(ring): ring.queue_free())


# Inner Node2D that draws an expanding outline ring. Defined inline so the
# autoload owns it — no extra file.
class _Ring extends Node2D:
	var fill_color: Color = Color.WHITE

	func _ready() -> void:
		scale = Vector2(0.2, 0.2)
		queue_redraw()

	func _draw() -> void:
		draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 32, fill_color, 4.0, true)


# ----------------------------------------------------------------
# Spawn flash — brief bright modulate ramp on a CanvasItem.
# Used for new heroes hitting the lane.
# ----------------------------------------------------------------
func spawn_flash(target: CanvasItem, duration: float = 0.35) -> void:
	if target == null or not is_instance_valid(target): return
	var original: Color = target.modulate
	target.modulate = Color(1.8, 1.8, 1.4, 1.0)
	var tw := target.create_tween()
	tw.tween_property(target, "modulate", original, duration) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)


# ----------------------------------------------------------------
# Hit flash — short white flash on a CanvasItem taking damage.
# Cheap variant of the in-Hero target flash for AoE/cleave hits.
# ----------------------------------------------------------------
func hit_flash(target: CanvasItem, duration: float = 0.12) -> void:
	if target == null or not is_instance_valid(target): return
	var original: Color = target.modulate
	target.modulate = Color(1.6, 1.6, 1.6, 1.0)
	var tw := target.create_tween()
	tw.tween_property(target, "modulate", original, duration)


# ----------------------------------------------------------------
# Screen shake — decaying random translate jitter on a Node2D.
# Restores original position when done.
# ----------------------------------------------------------------
func screen_shake(node: Node2D, intensity_px: float = 14.0, duration: float = 0.35) -> void:
	if node == null or not is_instance_valid(node): return
	var origin: Vector2 = node.position
	var steps: int = 8
	var step_sec: float = duration / float(steps)
	var tw := node.create_tween()
	for i in range(steps):
		var decay: float = float(steps - i) / float(steps)
		var dx: float = randf_range(-1.0, 1.0) * intensity_px * decay
		var dy: float = randf_range(-1.0, 1.0) * intensity_px * decay
		tw.tween_property(node, "position", origin + Vector2(dx, dy), step_sec)
	tw.tween_property(node, "position", origin, step_sec)


# ----------------------------------------------------------------
# Edge tint pulse — full-screen colored gradient pulse around the edges.
# Used for color-frenzy triggers in Phase 1.
# Spawns a CanvasLayer overlay so it always renders on top regardless of where
# `parent` lives in the tree.
# ----------------------------------------------------------------
func edge_tint_pulse(parent: Node, color: Color, duration: float = 0.7) -> void:
	if parent == null or not is_instance_valid(parent): return
	var layer := CanvasLayer.new()
	layer.layer = 100
	parent.add_child(layer)
	var rect := _EdgePulse.new()
	rect.pulse_color = color
	layer.add_child(rect)
	var tw := rect.create_tween()
	tw.tween_property(rect, "modulate:a", 1.0, duration * 0.25) \
		.set_trans(Tween.TRANS_SINE)
	tw.tween_property(rect, "modulate:a", 0.0, duration * 0.75) \
		.set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		if is_instance_valid(layer): layer.queue_free())


# Full-screen edge gradient — draws a thick translucent border so the
# centre of the screen stays clear (gameplay still readable).
class _EdgePulse extends Control:
	var pulse_color: Color = Color(1, 1, 1, 1)
	const BORDER_PX: float = 110.0

	func _ready() -> void:
		anchor_right = 1.0
		anchor_bottom = 1.0
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		modulate.a = 0.0

	func _draw() -> void:
		var w: float = size.x if size.x > 0.0 else 720.0
		var h: float = size.y if size.y > 0.0 else 1560.0
		# Outer to inner: alpha ramps down from 0.55 to 0 across BORDER_PX.
		var steps: int = 12
		for i in range(steps):
			var t: float = float(i) / float(steps - 1)
			var inset: float = t * BORDER_PX
			var alpha: float = (1.0 - t) * 0.55
			var col := Color(pulse_color.r, pulse_color.g, pulse_color.b, alpha)
			# Top + bottom + left + right rectangles, 1px tall each band.
			draw_rect(Rect2(inset, inset, w - 2.0 * inset, 1.0), col, true)
			draw_rect(Rect2(inset, h - 1.0 - inset, w - 2.0 * inset, 1.0), col, true)
			draw_rect(Rect2(inset, inset, 1.0, h - 2.0 * inset), col, true)
			draw_rect(Rect2(w - 1.0 - inset, inset, 1.0, h - 2.0 * inset), col, true)


# ----------------------------------------------------------------
# Color helpers
# ----------------------------------------------------------------
func color_for_bubble(bubble_color: int) -> Color:
	if GameConfig.COLOR_HEX.has(bubble_color):
		return Color.html(GameConfig.COLOR_HEX[bubble_color])
	return Color.WHITE
