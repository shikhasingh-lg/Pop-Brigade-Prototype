# StageClear — screen 6 (v1-ui-flow §3.6).
# 3 boon cards drawn from GameConfig.BOON_IDS. Tap a card → log + commit + continue.

extends Control

signal boon_picked(boon_id: String)

const BOON_LABELS := {
	"red_bias":      "+30%\nRED\nbubbles",
	"blue_bias":     "+30%\nBLUE\nbubbles",
	"yellow_bias":   "+30%\nYELLOW\nbubbles",
	"red_dmg":       "+25%\nRED\nhero dmg",
	"blue_dmg":      "+25%\nBLUE\nhero dmg",
	"yellow_dmg":    "+25%\nYELLOW\nhero dmg",
	"extra_special": "+1\nspecial\nbubble /30s",
	"faster_fire":   "Faster\ncannon\nfire rate",
	"ricochet_plus": "+1\nbounce\noff walls",
}

var stage_num: int = 1
var _offered: Array[String] = []

@onready var _title: Label = $Title
@onready var _cards: Array[Button] = [$Cards/Card1, $Cards/Card2, $Cards/Card3]

func _ready() -> void:
	for i in range(_cards.size()):
		var btn := _cards[i]
		var idx := i
		btn.pressed.connect(func(): _on_card_pressed(idx))

func setup(stage_just_cleared: int) -> void:
	stage_num = stage_just_cleared
	_title.text = "STAGE %d CLEAR" % stage_just_cleared
	_offered = _draw_three_boons()
	for i in range(_cards.size()):
		_cards[i].text = BOON_LABELS.get(_offered[i], _offered[i])

func _draw_three_boons() -> Array[String]:
	var pool: Array = GameConfig.BOON_IDS.duplicate()
	pool.shuffle()
	var out: Array[String] = []
	for i in range(min(3, pool.size())):
		out.append(pool[i])
	return out

func _on_card_pressed(idx: int) -> void:
	if idx < 0 or idx >= _offered.size(): return
	var picked: String = _offered[idx]
	var alternatives: Array = []
	for i in range(_offered.size()):
		if i != idx:
			alternatives.append(_offered[i])
	Telemetry.log_boon_picked(stage_num, picked, alternatives)
	RunState.add_boon(picked)
	boon_picked.emit(picked)
