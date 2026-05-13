# Cluster — manages the hex grid of bubbles + descent + match detection.
# Design spec §3.2.
# This is THE V2 cluster-as-spawner core. Most playtest signal lives here.

class_name Cluster
extends Node2D

signal cluster_grew(new_height: int)
signal cluster_descended(rows_now: int)
signal match_popped(color: int, match_size: int, chain_count: int, positions: Array, hero_colors: Array)
# Bubble vanished past the spawn line (V8: lost opportunity only, no enemy spawn).
# Source = "descent" (cluster bubble crossed during descent) or "below_line_fire"
# (fired bubble's chosen cell was below the line). Used for telemetry + fade VFX.
signal bubble_lost_below_line(color: int, col: int, source: String)
signal cluster_reached_lane()  # game over signal
# Emitted after every attach_bubble call completes (pop, miss, or below-line convert).
# MatchScene listens to this to apply queued descent AFTER the player's shot landed,
# so descent never moves the cluster out from under an in-flight bubble.
signal bubble_resolved(was_pop: bool)

const COLS_EVEN := 8
const COLS_ODD  := 7   # offset rows have 1 less for hex packing
const BUBBLE_SIZE_PX := 64.0
const BUBBLE_RADIUS_PX := 32.0  # half BUBBLE_SIZE_PX; used for visual-edge spawn-line checks
const ROW_HEIGHT_PX  := 56.0  # tighter than diameter for hex tessellation

# Grid storage: rows × cols. null = empty cell.
var grid: Array = []        # grid[row][col] = Bubble | null
var current_height: int = 0
var _consecutive_misses: int = 0
var _last_descend_ms: int = 0
var _initial_y: float = 0.0
var _is_descending: bool = false
var _stage_over: bool = false
var _spawn_line_world_y: float = 0.0  # fixed world Y of the spawn line, cached at stage start
var _pending_rows: int = 0            # shot-triggered descent queue

@export var bubble_scene: PackedScene
@export var spawn_line_y: float = 0.0   # set by MatchScene, in Cluster-local space

# ============================================================
# Lifecycle
# ============================================================
func _ready() -> void:
	_initial_y = position.y

func setup_for_stage(stage_num: int) -> void:
	current_height = GameConfig.get_stage_start_rows(stage_num)
	_clear_visual_grid()
	grid.clear()
	for row in range(current_height):
		var is_offset := row % 2 == 1
		var cols_this_row := COLS_ODD if is_offset else COLS_EVEN
		var row_data: Array = []
		for col in range(cols_this_row):
			var b: Bubble = bubble_scene.instantiate()
			b.color = _pick_random_color()
			# 1 color bomb on stage >= 4 (§3.7)
			if stage_num >= 4 and row == 1 and col == 3:
				b.is_special_color_bomb = true
			b.position = _cell_to_local_pos(row, col)
			add_child(b)
			b.grid_row = row
			b.grid_col = col
			row_data.append(b)
		grid.append(row_data)
	_seed_hero_bubbles(GameConfig.get_hero_bubble_count(stage_num))
	position.y = _initial_y
	_consecutive_misses = 0
	_stage_over = false
	_pending_rows = 0
	_is_descending = false
	# Spawn line is a FIXED world Y captured at stage start. Without caching, the
	# crossing check would chase the cluster down and never trigger.
	_spawn_line_world_y = global_position.y + spawn_line_y
	_last_descend_ms = Time.get_ticks_msec()

func _clear_visual_grid() -> void:
	for child in get_children():
		if child is Bubble:
			child.queue_free()

func _pick_random_color() -> int:
	var colors := GameConfig.all_bubble_colors()
	return colors[randi() % colors.size()]

# Flip N random eligible cells in the freshly-built grid to hero bubbles.
# Eligible = not a color bomb and not already a hero bubble. Caps at the
# available eligible cell count.
func _seed_hero_bubbles(count: int) -> void:
	if count <= 0: return
	var candidates: Array = []
	for r in range(grid.size()):
		var row_data: Array = grid[r]
		for c in range(row_data.size()):
			var b: Bubble = row_data[c]
			if b == null or b.is_special_color_bomb or b.is_hero_bubble:
				continue
			candidates.append(b)
	candidates.shuffle()
	var n: int = min(count, candidates.size())
	for i in range(n):
		(candidates[i] as Bubble).set_hero_bubble(true)

func _cell_to_local_pos(row: int, col: int) -> Vector2:
	var is_offset := row % 2 == 1
	var x := col * BUBBLE_SIZE_PX + (BUBBLE_SIZE_PX * 0.5 if is_offset else 0.0)
	var y := row * ROW_HEIGHT_PX
	return Vector2(x, y)

func _cols_for_row(row: int) -> int:
	return COLS_ODD if row % 2 == 1 else COLS_EVEN

# ============================================================
# Hex adjacency (§3.2)
# Even rows (cols 0..7): NW/NE neighbors are (r-1, c-1) and (r-1, c).
# Odd  rows (cols 0..6): NW/NE neighbors are (r-1, c)   and (r-1, c+1).
# Same logic for SW/SE (r+1).
# ============================================================
func _hex_neighbors(row: int, col: int) -> Array:
	var out: Array = []
	var is_offset := row % 2 == 1
	# Same row
	if col - 1 >= 0:
		out.append(Vector2i(row, col - 1))
	if col + 1 < _cols_for_row(row):
		out.append(Vector2i(row, col + 1))
	# Row above
	if row - 1 >= 0:
		var above_cols := _cols_for_row(row - 1)
		if is_offset:
			# odd → above is even: neighbors at (r-1, c) and (r-1, c+1)
			if col < above_cols:           out.append(Vector2i(row - 1, col))
			if col + 1 < above_cols:       out.append(Vector2i(row - 1, col + 1))
		else:
			# even → above is odd: neighbors at (r-1, c-1) and (r-1, c)
			if col - 1 >= 0 and col - 1 < above_cols: out.append(Vector2i(row - 1, col - 1))
			if col < above_cols:                       out.append(Vector2i(row - 1, col))
	# Row below
	if row + 1 < grid.size():
		var below_cols := _cols_for_row(row + 1)
		if is_offset:
			if col < below_cols:           out.append(Vector2i(row + 1, col))
			if col + 1 < below_cols:       out.append(Vector2i(row + 1, col + 1))
		else:
			if col - 1 >= 0 and col - 1 < below_cols: out.append(Vector2i(row + 1, col - 1))
			if col < below_cols:                       out.append(Vector2i(row + 1, col))
	return out

# ============================================================
# §3.2 — Descent (shot-triggered; no time-based pressure)
# Cluster only moves when the player fires. Each shot pushes the cluster down
# by N rows (per-stage, see GameConfig.get_stage_descent_rows_per_shot).
# ============================================================
func descend_rows(n: int) -> void:
	if _stage_over or n <= 0: return
	_pending_rows += n
	if not _is_descending:
		_descend_pending()

func _descend_pending() -> void:
	if _pending_rows <= 0: return
	var rows: int = _pending_rows
	_pending_rows = 0
	_is_descending = true
	var tween := create_tween()
	# Tween scales with row count so multi-row descents feel weighty but not slow.
	var duration: float = clamp(0.25 + 0.08 * float(rows), 0.25, 0.7)
	tween.tween_property(self, "position:y", position.y + ROW_HEIGHT_PX * rows, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(_on_descent_finished)
	var now_ms := Time.get_ticks_msec()
	Telemetry.log_cluster_descend(current_height, now_ms - _last_descend_ms)
	_last_descend_ms = now_ms
	emit_signal("cluster_descended", current_height)

func _on_descent_finished() -> void:
	_is_descending = false
	# V8 spec (§3.2, §3.5, §5.1): bubbles that descend past the spawn line VANISH.
	# No enemy is produced in Phase 1 — only a lost-opportunity event for telemetry.
	# Compare bubble BOTTOM edge so the visual matches the rule the player sees.
	var any_remaining := false
	for r in range(grid.size()):
		var row_data: Array = grid[r]
		for c in range(row_data.size()):
			var b: Bubble = row_data[c]
			if b == null: continue
			if b.global_position.y + BUBBLE_RADIUS_PX >= _spawn_line_world_y:
				emit_signal("bubble_lost_below_line", b.color, c, "descent")
				row_data[c] = null
				b.queue_free()
			else:
				any_remaining = true
	if not any_remaining and grid.size() > 0:
		_stage_over = true
		emit_signal("cluster_reached_lane")
	# Drain queued descents that arrived mid-tween.
	if _pending_rows > 0:
		call_deferred("_descend_pending")

func refund_descent_rows(n: int) -> void:
	# Pop reward: pull the cluster back up by N rows (cancels part of a queued descent
	# OR rewinds prior descents to relieve pressure). Never above the stage's starting y.
	if n <= 0 or _stage_over: return
	if _pending_rows > 0:
		var absorbed: int = min(n, _pending_rows)
		_pending_rows -= absorbed
		n -= absorbed
	if n <= 0: return
	var target_y: float = max(_initial_y, position.y - ROW_HEIGHT_PX * n)
	if is_equal_approx(target_y, position.y): return
	var tween := create_tween()
	tween.tween_property(self, "position:y", target_y, 0.25) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func pause_descent(_seconds: float) -> void:
	# Legacy no-op (time-based pacing replaced with shot-triggered descent).
	pass

# ============================================================
# §3.2 — Attach + match
# ============================================================
# Finds the nearest empty hex cell to a local position, allowing the grid
# to grow downward (new row appended) when the closest empty slot is below
# the current bottom row.
func _find_nearest_empty_cell(local_pos: Vector2) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_dist := INF
	# Existing rows: empty cells
	for r in range(grid.size()):
		var row_data: Array = grid[r]
		for c in range(row_data.size()):
			if row_data[c] != null: continue
			var d := _cell_to_local_pos(r, c).distance_to(local_pos)
			if d < best_dist:
				best_dist = d
				best = Vector2i(r, c)
	# Allow extending downward by 1 row (next-row candidates)
	var next_row := grid.size()
	for c in range(_cols_for_row(next_row)):
		var d := _cell_to_local_pos(next_row, c).distance_to(local_pos)
		if d < best_dist:
			best_dist = d
			best = Vector2i(next_row, c)
	return best

func attach_bubble(bubble: Bubble, at_world_pos: Vector2) -> void:
	var local_pos := to_local(at_world_pos)
	var cell := _find_nearest_empty_cell(local_pos)
	if cell.x < 0:
		bubble.queue_free()
		emit_signal("bubble_resolved", false)
		return
	var target_local := _cell_to_local_pos(cell.x, cell.y)
	# V8 spec (§3.5 "bubble_lost_below_line"): fired bubble whose nearest cell is
	# below the spawn line VANISHES — no enemy, no hero, just a wasted shot.
	var target_world_y: float = global_position.y + target_local.y
	if target_world_y + BUBBLE_RADIUS_PX >= _spawn_line_world_y:
		emit_signal("bubble_lost_below_line", bubble.color, cell.y, "below_line_fire")
		bubble.queue_free()
		emit_signal("bubble_resolved", false)
		return
	# Grow grid downward if needed
	while cell.x >= grid.size():
		var new_row: Array = []
		for _i in range(_cols_for_row(grid.size())):
			new_row.append(null)
		grid.append(new_row)
	grid[cell.x][cell.y] = bubble
	bubble.attach_to_grid_cell(self, cell.x, cell.y, target_local)
	Telemetry.log_bubble_attached(bubble.color, cell.x, cell.y, _count_bubbles())
	# Match detection
	var match_positions := _find_match(cell.x, cell.y, bubble.color)
	var was_pop := match_positions.size() >= 3
	if was_pop:
		_consecutive_misses = 0
		_pop_match(bubble.color, match_positions)
	else:
		_consecutive_misses += 1
		if _consecutive_misses >= GameConfig.cluster_grow_trigger_misses:
			_consecutive_misses = 0
			_grow_top_row()
	emit_signal("bubble_resolved", was_pop)

# §3.2: flood-fill same-color from (row, col). Color bombs match any color.
func _find_match(row: int, col: int, target_color: int) -> Array:
	var start_bubble: Bubble = grid[row][col]
	if start_bubble == null: return []
	var visited: Dictionary = {}
	var stack: Array = [Vector2i(row, col)]
	var result: Array = []
	while stack.size() > 0:
		var p: Vector2i = stack.pop_back()
		var key := "%d,%d" % [p.x, p.y]
		if visited.has(key): continue
		visited[key] = true
		if p.x < 0 or p.x >= grid.size(): continue
		if p.y < 0 or p.y >= grid[p.x].size(): continue
		var b: Bubble = grid[p.x][p.y]
		if b == null: continue
		var matches := (b.color == target_color) or b.is_special_color_bomb
		if not matches: continue
		result.append(p)
		for n in _hex_neighbors(p.x, p.y):
			stack.append(n)
	return result

func _pop_match(color: int, positions: Array) -> void:
	# §3.4: hero-tier mapping is handled in MatchScene._on_match_popped.
	# Here: free the bubbles, run cascade, emit match_popped.
	# Heroes only spawn from hero bubbles, so collect their colors before freeing.
	var burst_color: Color = Vfx.color_for_bubble(color)
	var burst_parent: Node = get_parent()  # ClusterZone — keeps the burst above the zone bg
	var hero_colors: Array = []
	for p in positions:
		var b: Bubble = grid[p.x][p.y]
		if b != null:
			if b.is_hero_bubble:
				hero_colors.append(b.color)
			Vfx.pop_burst(burst_parent, b.global_position, burst_color)
			b.queue_free()
			grid[p.x][p.y] = null
	var cascade_colors := _process_falling()
	# Match-detector returns Vector2i; convert to plain arrays MatchScene can read.
	var positions_arr: Array = []
	for p in positions:
		positions_arr.append(Vector2(p.y, p.x))  # (col, row) — MatchScene uses centroid.x for column
	emit_signal("match_popped", color, positions.size(), cascade_colors.size(), positions_arr, hero_colors)
	pause_descent(GameConfig.cluster_descent_pause_after_pop_sec)

# §3.2: any bubble disconnected from the top row falls.
# Returns array of colors (one per fallen bubble) — used by MatchScene to spawn cascade heroes.
func _process_falling() -> Array:
	if grid.is_empty(): return []
	# Flood-fill connectivity from every bubble in row 0 (ANY color).
	var reached: Dictionary = {}
	var stack: Array = []
	for c in range(grid[0].size()):
		if grid[0][c] != null:
			stack.append(Vector2i(0, c))
	while stack.size() > 0:
		var p: Vector2i = stack.pop_back()
		var key := "%d,%d" % [p.x, p.y]
		if reached.has(key): continue
		if p.x < 0 or p.x >= grid.size(): continue
		if p.y < 0 or p.y >= grid[p.x].size(): continue
		if grid[p.x][p.y] == null: continue
		reached[key] = true
		for n in _hex_neighbors(p.x, p.y):
			stack.append(n)
	# Anything not reached falls.
	var fallen_colors: Array = []
	for r in range(grid.size()):
		var row_data: Array = grid[r]
		for c in range(row_data.size()):
			var b: Bubble = row_data[c]
			if b == null: continue
			var key := "%d,%d" % [r, c]
			if not reached.has(key):
				fallen_colors.append(b.color)
				b.queue_free()
				row_data[c] = null
	return fallen_colors

# §3.2: after 8 consecutive non-pop shots, add a new row at the top.
func _grow_top_row() -> void:
	# Shift every existing bubble's grid index down by 1 and visually tween down.
	# Note: row parity flips for every bubble (was row R, becomes row R+1) — odd/even widths
	# may not match for the existing bubbles. We tolerate this for W1 since grow happens
	# rarely; positions stay visually consistent because we tween in world space.
	# Insert new row 0
	var new_row: Array = []
	var new_row_is_offset := false  # new row 0 is even
	var new_row_cols := COLS_ODD if new_row_is_offset else COLS_EVEN
	# Tween existing bubbles down by ROW_HEIGHT_PX in local space
	for r in range(grid.size()):
		var row_data: Array = grid[r]
		for c in range(row_data.size()):
			var b: Bubble = row_data[c]
			if b == null: continue
			b.grid_row = r + 1
			var tw := create_tween()
			tw.tween_property(b, "position:y", b.position.y + ROW_HEIGHT_PX, 0.25)
	for c in range(new_row_cols):
		var b: Bubble = bubble_scene.instantiate()
		b.color = _pick_random_color()
		if randf() < GameConfig.hero_bubble_grow_chance:
			b.is_hero_bubble = true
		b.position = _cell_to_local_pos(0, c)
		add_child(b)
		b.grid_row = 0
		b.grid_col = c
		new_row.append(b)
	grid.insert(0, new_row)
	current_height = grid.size()
	emit_signal("cluster_grew", current_height)

# ============================================================
# Helpers
# ============================================================
func _count_bubbles() -> int:
	var n := 0
	for row in grid:
		for cell in row:
			if cell != null: n += 1
	return n

# V8 §3.8: Phase 1 ends when the cluster has zero bubbles remaining ABOVE the
# spawn line (popped or descended). MatchScene polls this each tick.
func bubbles_above_spawn_line_count() -> int:
	var n := 0
	for r in range(grid.size()):
		var row_data: Array = grid[r]
		for c in range(row_data.size()):
			var b: Bubble = row_data[c]
			if b == null: continue
			if b.global_position.y + BUBBLE_RADIUS_PX < _spawn_line_world_y:
				n += 1
	return n

# V8 §3.8: Phase 1 time cap hit — remaining cluster bubbles are wiped (no enemy).
func sweep_all() -> void:
	for r in range(grid.size()):
		var row_data: Array = grid[r]
		for c in range(row_data.size()):
			var b: Bubble = row_data[c]
			if b == null: continue
			emit_signal("bubble_lost_below_line", b.color, c, "phase1_cap_sweep")
			row_data[c] = null
			b.queue_free()
	_stage_over = true

# §3.3: colors still present in cluster (used by Cannon to filter the queue palette).
func get_active_colors() -> Array:
	var seen: Dictionary = {}
	for row in grid:
		for cell in row:
			if cell == null: continue
			if cell.is_special_color_bomb: continue
			seen[cell.color] = true
	return seen.keys()

# §4.2 Color Lock boon support — counts per color in the live cluster.
# Returns { color_enum: int }. Color bombs excluded (they're not a real color).
func get_color_counts() -> Dictionary:
	var counts: Dictionary = {}
	for row in grid:
		for cell in row:
			if cell == null: continue
			if cell.is_special_color_bomb: continue
			counts[cell.color] = int(counts.get(cell.color, 0)) + 1
	return counts

# ============================================================
# Open question OQ8 (§7.1): should falling bubbles convert to enemies?
# v1 = NO. Re-test in v2 if Q2 passes "too easy".
# ============================================================
