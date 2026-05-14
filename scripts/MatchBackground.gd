# MatchBackground — full-screen night sky with gradient, twinkling stars,
# twin moons, distant tower silhouette, and slow-drifting energy motes.
# All drawn in _draw with deterministic placement (seeded RNG) so the scene
# looks the same every run. Placed BEHIND every other MatchScene node via
# z_index = -50; covers the cluster zone area only — LaneZone and HUDBottom
# have their own opaque backgrounds.

extends Node2D

const VIEW_W := 720.0
const VIEW_H := 1560.0
const SKY_END_Y := 1020.0     # below this the lane / wall / cannon take over

const STAR_COUNT := 55
const PARTICLE_COUNT := 12

var _stars: Array = []
var _particles: Array = []
var _time: float = 0.0

func _ready() -> void:
	z_index = -50
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337  # fixed seed so placement is deterministic
	for i in STAR_COUNT:
		_stars.append({
			"pos": Vector2(rng.randf() * VIEW_W, rng.randf_range(30.0, 880.0)),
			"base_a": rng.randf_range(0.20, 0.85),
			"phase": rng.randf() * TAU,
			"size": rng.randf_range(0.8, 2.3),
		})
	for i in PARTICLE_COUNT:
		_particles.append({
			"x": rng.randf() * VIEW_W,
			"y": rng.randf_range(180.0, 990.0),
			"phase": rng.randf() * TAU,
			"speed": rng.randf_range(0.12, 0.30),
			"amp": rng.randf_range(8.0, 22.0),
			"size": rng.randf_range(1.6, 3.4),
			"hue": rng.randf_range(0.55, 0.85),
			"rise": rng.randf_range(4.0, 9.0),
		})
	set_process(true)

func _process(delta: float) -> void:
	_time += delta
	# Drift particles upward; wrap back to the bottom of the sky band.
	for p in _particles:
		p.y -= p.rise * delta
		if p.y < 140.0:
			p.y = 1020.0
	queue_redraw()

func _draw() -> void:
	_draw_gradient()
	_draw_moons()
	_draw_stars()
	_draw_horizon()
	_draw_particles()

# Banded vertical gradient across the sky region.
func _draw_gradient() -> void:
	var bands := 28
	for i in bands:
		var t: float = float(i) / float(bands)
		var t_next: float = float(i + 1) / float(bands)
		var y0: float = t * SKY_END_Y
		var y1: float = t_next * SKY_END_Y + 1.0
		var c: Color
		if t < 0.5:
			c = Color(0.06, 0.04, 0.13).lerp(Color(0.16, 0.09, 0.22), t / 0.5)
		elif t < 0.8:
			c = Color(0.16, 0.09, 0.22).lerp(Color(0.20, 0.12, 0.26), (t - 0.5) / 0.3)
		else:
			c = Color(0.20, 0.12, 0.26).lerp(Color(0.10, 0.07, 0.16), (t - 0.8) / 0.2)
		draw_rect(Rect2(0, y0, VIEW_W, y1 - y0), c, true)
	# Below sky: dark floor (LaneZone bg covers it, but defined defensively).
	draw_rect(Rect2(0, SKY_END_Y, VIEW_W, VIEW_H - SKY_END_Y),
		Color(0.045, 0.045, 0.065, 1), true)

func _draw_moons() -> void:
	# Large pale moon, upper-right.
	draw_circle(Vector2(560, 200), 42.0, Color(1, 0.95, 0.80, 0.18))     # outer glow
	draw_circle(Vector2(560, 200), 32.0, Color(0.98, 0.94, 0.78, 0.95))  # disc
	draw_circle(Vector2(550, 192), 5.0, Color(0.78, 0.72, 0.55, 0.7))    # craters
	draw_circle(Vector2(570, 208), 4.0, Color(0.78, 0.72, 0.55, 0.55))
	draw_circle(Vector2(555, 215), 2.5, Color(0.78, 0.72, 0.55, 0.5))
	# Smaller violet moon, mid-left.
	draw_circle(Vector2(120, 320), 28.0, Color(0.7, 0.55, 0.95, 0.12))
	draw_circle(Vector2(120, 320), 16.0, Color(0.72, 0.55, 0.95, 0.85))

func _draw_stars() -> void:
	for s in _stars:
		var a: float = clamp(s.base_a + sin(_time * 1.4 + s.phase) * 0.35, 0.05, 1.0)
		draw_circle(s.pos, s.size, Color(1, 1, 1, a))

# Jagged silhouette + a couple of distant tower spires sitting on the horizon.
func _draw_horizon() -> void:
	var base_y: float = 985.0
	var col := Color(0.025, 0.02, 0.05, 0.95)
	var pts := PackedVector2Array()
	pts.append(Vector2(0, SKY_END_Y))
	pts.append(Vector2(0, base_y + 20))
	var ridge := [
		Vector2(50, base_y), Vector2(90, base_y - 28), Vector2(130, base_y + 5),
		Vector2(170, base_y - 32), Vector2(195, base_y - 5),
		# Distant single spire.
		Vector2(220, base_y - 5), Vector2(220, base_y - 55),
		Vector2(232, base_y - 65),
		Vector2(244, base_y - 55), Vector2(244, base_y - 5),
		Vector2(280, base_y - 12), Vector2(320, base_y - 38),
		Vector2(360, base_y - 18), Vector2(400, base_y - 42),
		# Twin spires.
		Vector2(430, base_y - 10), Vector2(440, base_y - 50),
		Vector2(455, base_y - 50), Vector2(465, base_y - 10),
		Vector2(490, base_y - 20), Vector2(530, base_y - 5),
		Vector2(580, base_y - 25), Vector2(630, base_y - 8),
		Vector2(680, base_y - 20),
	]
	for p in ridge:
		pts.append(p)
	pts.append(Vector2(VIEW_W, base_y + 20))
	pts.append(Vector2(VIEW_W, SKY_END_Y))
	draw_colored_polygon(pts, col)

# Drifting energy motes — slow upward float with horizontal sine sway.
func _draw_particles() -> void:
	for p in _particles:
		var x: float = p.x + sin(_time * p.speed + p.phase) * p.amp
		var c: Color = Color.from_hsv(p.hue, 0.6, 1.0)
		c.a = 0.35 + sin(_time * 1.1 + p.phase) * 0.18
		draw_circle(Vector2(x, p.y), p.size, c)
