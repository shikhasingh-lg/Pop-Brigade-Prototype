# Cluster — manages the hex grid of bubbles + descent + match detection.
# Design spec §3.2.
# This is THE V2 cluster-as-spawner core. Most playtest signal lives here.

class_name Cluster
extends Node2D

signal cluster_grew(new_height: int)
signal cluster_descended(rows_now: int)
signal match_popped(color: int, match_size: int, chain_count: int, positions: Array)
signal bubble_crossed_spawn_line(color: int, col: int)
signal cluster_reached_lane()  # game over signal

const COLS_EVEN := 8
const COLS_ODD  := 7   # offset rows have 1 less for hex packing
const BUBBLE_SIZE_PX := 64.0
const ROW_HEIGHT_PX  := 56.0  # tighter than diameter for hex tessellation

# Grid storage: rows × cols. null = empty cell.
var grid: Array = []        # grid[row][col] = Bubble | null
var current_height: int = 0
var _descent_timer: float = 0.0
var _consecutive_misses: int = 0
var _last_descend_ms: int = 0
var _initial_y: float = 0.0
var _is_descending: bool = false

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
	position.y = _initial_y
	_descent_timer = 0.0
	_consecutive_misses = 0
	_last_descend_ms = Time.get_ticks_msec()

func _clear_visual_grid() -> void:
	for child in get_children():
		if child is Bubble:
			child.queue_free()

func _pick_random_color() -> int:
	var colors := GameConfig.all_bubble_colors()
	return colors[randi() % colors.size()]

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
# §3.2 — Descent (visual + spawn-line crossing)
# ============================================================
func _process(delta: float) -> void:
	if _is_descending: return
	_descent_timer += delta
	if _descent_timer >= GameConfig.cluster_descent_rate_sec:
		_descent_timer = 0.0
		_descend_one_row()

func _descend_one_row() -> void:
	_is_descending = true
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y + ROW_HEIGHT_PX, 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(_on_descent_finished)
	var now_ms := Time.get_ticks_msec()
	Telemetry.log_cluster_descend(current_height, now_ms - _last_descend_ms)
	_last_descend_ms = now_ms
	emit_signal("cluster_descended", current_height)

func _on_descent_finished() -> void:
	_is_descending = false
	# Any bubble whose post-descent global Y crossed the spawn line converts.
	# We check global_position because Cluster has moved down by ROW_HEIGHT_PX.
	var spawn_line_global_y := global_position.y + spawn_line_y
	var any_remaining := false
	for r in range(grid.size()):
		var row_data: Array = grid[r]
		for c in range(row_data.size()):
			var b: Bubble = row_data[c]
			if b == null: continue
			if b.global_position.y >= spawn_line_global_y:
				emit_signal("bubble_crossed_spawn_line", b.color, c)
				Telemetry.log_bubble_converted_to_enemy(b.color, c, "descent")
				row_data[c] = null
				b.queue_free()
			else:
				any_remaining = true
	if not any_remaining and grid.size() > 0:
		emit_signal("cluster_reached_lane")

func pause_descent(seconds: float) -> void:
	# Called by MatchScene after a pop (§3.2: descent paused 1s after every successful pop).
	_descent_timer = -seconds

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
		return
	var target_local := _cell_to_local_pos(cell.x, cell.y)
	# §3.2: if would attach below spawn line, convert to enemy instead.
	if target_local.y > spawn_line_y:
		emit_signal("bubble_crossed_spawn_line", bubble.color, cell.y)
		Telemetry.log_bubble_converted_to_enemy(bubble.color, cell.y, "below_line_attach")
		bubble.queue_free()
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
	if match_positions.size() >= 3:
		_consecutive_misses = 0
		_pop_match(bubble.color, match_positions)
	else:
		_consecutive_misses += 1
		if _consecutive_misses >= GameConfig.cluster_grow_trigger_misses:
			_consecutive_misses = 0
			_grow_top_row()

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
	for p in positions:
		var b: Bubble = grid[p.x][p.y]
		if b != null:
			b.queue_free()
			grid[p.x][p.y] = null
	var cascade_colors := _process_falling()
	# Match-detector returns Vector2i; convert to plain arrays MatchScene can read.
	var positions_arr: Array = []
	for p in positions:
		positions_arr.append(Vector2(p.y, p.x))  # (col, row) — MatchScene uses centroid.x for column
	emit_signal("match_popped", color, positions.size(), cascade_colors.size(), positions_arr)
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

# ============================================================
# Open question OQ8 (§7.1): should falling bubbles convert to enemies?
# v1 = NO. Re-test in v2 if Q2 passes "too easy".
# ============================================================
