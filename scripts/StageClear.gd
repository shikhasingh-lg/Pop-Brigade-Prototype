# StageClear — screen 6 (v1-ui-flow §3.6).
# 3 boon cards drawn from BoonDB.BOONS (rarity-weighted). Tap a card →
# log + commit + continue. Cards are tinted by rarity so testers can see
# what tier they're picking.

extends Control

signal boon_picked(boon_id: String)

var stage_num: int = 1
var _offered: Array[String] = []

@onready var _title: Label = $Title
@onready var _cards: Array[Button] = [$Cards/Card1, $Cards/Card2, $Cards/Card3]

# Per-card rarity-banner label, created at runtime and parented under each card.
var _rarity_labels: Array[Label] = []

func _ready() -> void:
	for i in range(_cards.size()):
		var btn := _cards[i]
		var idx := i
		btn.pressed.connect(func(): _on_card_pressed(idx))
		_rarity_labels.append(_build_rarity_label(btn))

func _build_rarity_label(btn: Button) -> Label:
	var lbl := Label.new()
	lbl.name = "RarityLabel"
	lbl.text = ""
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(btn.size.x, 28)
	lbl.position = Vector2(0, 8)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(lbl)
	return lbl

func setup(stage_just_cleared: int) -> void:
	stage_num = stage_just_cleared
	_title.text = "STAGE %d CLEAR" % stage_just_cleared
	_offered = _draw_three_boons()
	for i in range(_cards.size()):
		_apply_card_style(_cards[i], _rarity_labels[i], _offered[i])

func _draw_three_boons() -> Array[String]:
	return BoonDB.draw_n_weighted(3)

# Paints the card according to the boon's rarity:
# - background StyleBox tinted by rarity
# - rarity name printed on a banner at the top
# - body text shows the boon label
func _apply_card_style(btn: Button, rarity_lbl: Label, boon_id: String) -> void:
	var rarity: int = BoonDB.get_rarity(boon_id)
	var tint: Color = BoonDB.RARITY_TINT[rarity]
	btn.text = BoonDB.get_label(boon_id)
	rarity_lbl.text = BoonDB.RARITY_LABEL[rarity]

	var sb_normal := StyleBoxFlat.new()
	sb_normal.bg_color = tint.darkened(0.55)
	sb_normal.border_color = tint
	sb_normal.border_width_left = 4
	sb_normal.border_width_right = 4
	sb_normal.border_width_top = 4
	sb_normal.border_width_bottom = 4
	sb_normal.corner_radius_top_left = 12
	sb_normal.corner_radius_top_right = 12
	sb_normal.corner_radius_bottom_left = 12
	sb_normal.corner_radius_bottom_right = 12
	# Legendary gets an extra glow via shadow.
	if rarity == BoonDB.Rarity.LEGENDARY:
		sb_normal.shadow_color = tint
		sb_normal.shadow_size = 14

	var sb_hover := sb_normal.duplicate() as StyleBoxFlat
	sb_hover.bg_color = tint.darkened(0.35)
	var sb_pressed := sb_normal.duplicate() as StyleBoxFlat
	sb_pressed.bg_color = tint.darkened(0.20)

	btn.add_theme_stylebox_override("normal",  sb_normal)
	btn.add_theme_stylebox_override("hover",   sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_pressed)
	btn.add_theme_stylebox_override("focus",   sb_hover)
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.96))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))

func _on_card_pressed(idx: int) -> void:
	if idx < 0 or idx >= _offered.size(): return
	var picked: String = _offered[idx]
	var alternatives: Array = []
	for i in range(_offered.size()):
		if i != idx:
			alternatives.append(_offered[i])
	var rarity_str: String = BoonDB.RARITY_LABEL[BoonDB.get_rarity(picked)]
	Telemetry.log_boon_picked(stage_num, picked, alternatives, rarity_str)
	RunState.add_boon(picked)
	boon_picked.emit(picked)
