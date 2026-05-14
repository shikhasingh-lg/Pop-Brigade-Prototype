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
# Hit-stop — brief global time-scale dip on big/fatal hits.
# Gated by a cooldown so cleave/AoE bursts don't stack into a stall.
# Timer uses ignore_time_scale=true so the restore fires in real seconds.
# ----------------------------------------------------------------
var _hit_stop_until_ms: int = 0

func hit_stop(duration_sec: float = 0.04, scale_factor: float = 0.05,
		cooldown_ms: int = 250) -> void:
	var now: int = Time.get_ticks_msec()
	if now < _hit_stop_until_ms: return
	_hit_stop_until_ms = now + cooldown_ms
	Engine.time_scale = scale_factor
	# 4th arg = ignore_time_scale → restore fires after real `duration_sec`,
	# not duration_sec / scale_factor.
	var t := get_tree().create_timer(duration_sec, true, false, true)
	t.timeout.connect(func():
		Engine.time_scale = 1.0)


# ----------------------------------------------------------------
# Damage number — floating label spawned at `local_pos` in parent's space.
# parent should be a Node2D in lane/match space; the holder is a Node2D
# so position/modulate tweens just work.
# ----------------------------------------------------------------
func damage_number(parent: Node, local_pos: Vector2, amount: int,
		color: Color, is_crit: bool = false) -> void:
	if parent == null or not is_instance_valid(parent): return
	if amount <= 0: return
	var holder := Node2D.new()
	holder.position = local_pos
	holder.z_index = 100
	parent.add_child(holder)

	var label := Label.new()
	label.text = str(amount) if not is_crit else str(amount) + "!"
	var font_size: int = 26 if is_crit else 18
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(label)
	# Centre the label on the holder. get_minimum_size is reliable pre-frame.
	var ms: Vector2 = label.get_minimum_size()
	label.position = Vector2(-ms.x * 0.5, -ms.y * 0.5)

	var dx: float = randf_range(-14.0, 14.0)
	var dy: float = -48.0 if is_crit else -36.0
	var dur: float = 0.7 if is_crit else 0.55
	var tw := holder.create_tween()
	tw.tween_property(holder, "position", local_pos + Vector2(dx, dy), dur) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(holder, "modulate:a", 0.0, dur)
	tw.tween_callback(func():
		if is_instance_valid(holder): holder.queue_free())


# ----------------------------------------------------------------
# Death burst — radial spray of small colored quads on unit death.
# Parent the burst on the dying unit's parent (Lane) so it survives queue_free.
# ----------------------------------------------------------------
func death_burst(parent: Node, world_pos: Vector2, color: Color,
		particle_count: int = 8) -> void:
	if parent == null or not is_instance_valid(parent): return
	for i in particle_count:
		var p := Polygon2D.new()
		p.color = color
		var sz: float = randf_range(4.0, 8.0)
		p.polygon = PackedVector2Array([
			Vector2(-sz, -sz), Vector2(sz, -sz),
			Vector2(sz, sz), Vector2(-sz, sz),
		])
		p.z_index = 60
		parent.add_child(p)
		p.global_position = world_pos
		var ang: float = TAU * float(i) / float(particle_count) + randf_range(-0.25, 0.25)
		var dist: float = randf_range(38.0, 64.0)
		var dest: Vector2 = world_pos + Vector2(cos(ang), sin(ang)) * dist
		var dur: float = randf_range(0.20, 0.28)
		var tw := p.create_tween()
		tw.tween_property(p, "global_position", dest, dur) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(p, "scale", Vector2(0.2, 0.2), dur)
		tw.parallel().tween_property(p, "rotation", randf_range(-PI, PI), dur)
		tw.parallel().tween_property(p, "modulate:a", 0.0, dur)
		tw.tween_callback(func():
			if is_instance_valid(p): p.queue_free())


# ----------------------------------------------------------------
# Color-counter badge — quick outline ring at target in attacker color.
# Signals "type advantage!" — separate from execute so the two read distinct.
# ----------------------------------------------------------------
func color_counter_badge(parent: Node, local_pos: Vector2, color: Color) -> void:
	if parent == null or not is_instance_valid(parent): return
	var ring := _Ring.new()
	ring.fill_color = color
	ring.z_index = 70
	parent.add_child(ring)
	ring.position = local_pos
	# _Ring._ready sets scale to (0.2, 0.2); override AFTER add_child fires _ready.
	ring.scale = Vector2(0.4, 0.4)
	var tw := ring.create_tween()
	tw.tween_property(ring, "scale", Vector2(2.0, 2.0), 0.32) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.32)
	tw.tween_callback(func():
		if is_instance_valid(ring): ring.queue_free())


# ----------------------------------------------------------------
# Floating badge — short text label that pops in, holds, drifts up, fades out.
# Used for "CLEAVE!" / similar proc callouts above the attacker.
# ----------------------------------------------------------------
func floating_badge(parent: Node, local_pos: Vector2, text: String, color: Color) -> void:
	if parent == null or not is_instance_valid(parent): return
	var holder := Node2D.new()
	holder.position = local_pos
	holder.z_index = 110
	holder.modulate.a = 0.0
	parent.add_child(holder)

	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(label)
	var ms: Vector2 = label.get_minimum_size()
	label.position = Vector2(-ms.x * 0.5, -ms.y * 0.5)
	holder.scale = Vector2(0.3, 0.3)

	var tw := holder.create_tween()
	# Pop in.
	tw.tween_property(holder, "scale", Vector2(1.0, 1.0), 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(holder, "modulate:a", 1.0, 0.12)
	# Hold.
	tw.tween_interval(0.18)
	# Drift up + fade.
	tw.tween_property(holder, "position", local_pos + Vector2(0, -32), 0.35) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(holder, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func():
		if is_instance_valid(holder): holder.queue_free())


# ----------------------------------------------------------------
# Color helpers
# ----------------------------------------------------------------
func color_for_bubble(bubble_color: int) -> Color:
	if GameConfig.COLOR_HEX.has(bubble_color):
		return Color.html(GameConfig.COLOR_HEX[bubble_color])
	return Color.WHITE
