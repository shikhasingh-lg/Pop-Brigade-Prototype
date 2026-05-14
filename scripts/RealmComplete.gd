# RealmComplete — §9.2.
# First clear of a realm's boss → star tally + next-realm reveal animation.

extends Control

signal continue_pressed

@onready var _title: Label = $Title
@onready var _realm_label: Label = $RealmLabel
@onready var _stars: Label = $Stars
@onready var _stars_count: Label = $StarsCount
@onready var _next_label: Label = $NextRealmLabel
@onready var _reward_label: Label = $RewardLabel
@onready var _continue_button: Button = $ContinueButton

func _ready() -> void:
	_continue_button.pressed.connect(func(): continue_pressed.emit())

func setup(realm: int) -> void:
	realm = clamp(realm, 1, RunState.REALM_COUNT)
	var stars: int = RunState.total_stars_in_realm(realm)
	var max_stars: int = RunState.STAGES_PER_REALM * 3
	_realm_label.text = "R%d · %s" % [realm, GameConfig.realm_name(realm)]
	_stars.text = "★".repeat(stars) + "☆".repeat(max_stars - stars)
	_stars_count.text = "%d / %d stars" % [stars, max_stars]
	# Reward stub (§8.7).
	_reward_label.text = "Reward (post-meta): 1 premium chest · 50 shards · 500 gems"
	# Next realm reveal — animate from greyed locked → highlighted unlocked.
	if realm < RunState.REALM_COUNT:
		var nxt: int = realm + 1
		_next_label.text = "Now unlocked: R%d · %s" % [nxt, GameConfig.realm_name(nxt)]
		# Flicker the reveal label so the unlock reads.
		_next_label.modulate = Color(1, 1, 1, 0)
		var tw := create_tween()
		tw.tween_interval(0.4)
		tw.tween_property(_next_label, "modulate:a", 1.0, 0.8) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		_next_label.text = "All realms complete — the game is yours."
