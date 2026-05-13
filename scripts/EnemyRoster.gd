# EnemyRoster — autoload singleton
#
# Registry of named enemy archetypes for v1 + v2 + boss.
# Mirrors HeroRoster pattern. Stats sourced from GameConfig (§3.6).
#
# v1 active: red-goblin (RED), blue-slime (BLUE), yellow-brute (YELLOW).
# v2 reserved: green-spore (GREEN), purple-wisp (PURPLE — art not yet generated).
# Boss: goop-king (Stage 5).
#
# Usage:
#   EnemyRoster.get_portrait("red-goblin")
#   EnemyRoster.get_cutout("red-goblin")
#   EnemyRoster.get_for_color(GameConfig.BubbleColor.RED)
#   EnemyRoster.boss_slug() -> "goop-king"

extends Node

const ROSTER := {
	"red-goblin": {
		"name":      "Snag",
		"archetype": "Red Goblin",
		"role":      "Fast melee rusher",
		"portrait":  "res://assets/enemies/red-goblin/red-goblin.png",
		"color":     0,       # BubbleColor.RED
		"v1_active": true,
		"is_boss":   false,
	},
	"blue-slime": {
		"name":      "Glub",
		"archetype": "Blue Slime",
		"role":      "Slow tank",
		"portrait":  "res://assets/enemies/blue-slime/blue-slime.png",
		"color":     1,       # BubbleColor.BLUE
		"v1_active": true,
		"is_boss":   false,
	},
	"yellow-brute": {
		"name":      "Zap",
		"archetype": "Yellow Brute",
		"role":      "Heavy hitter",
		"portrait":  "res://assets/enemies/yellow-brute/yellow-brute.png",
		"color":     2,       # BubbleColor.YELLOW
		"v1_active": true,
		"is_boss":   false,
	},
	"green-spore": {
		"name":      "Mossy",
		"archetype": "Green Spore",
		"role":      "Healer-minion (v2)",
		"portrait":  "res://assets/enemies/green-spore/green-spore.png",
		"color":     -1,      # v2 GREEN reserved
		"v1_active": false,
		"is_boss":   false,
	},
	"goop-king": {
		"name":      "Goop King",
		"archetype": "Boss",
		"role":      "Stage 5 boss",
		"portrait":  "res://assets/enemies/goop-king/goop-king.png",
		"color":     -1,      # multi-color phases
		"v1_active": true,
		"is_boss":   true,
	},
}

func get_entry(slug: String) -> Dictionary:
	return ROSTER.get(slug, {})

func has(slug: String) -> bool:
	return ROSTER.has(slug)

func all_slugs() -> Array:
	return ROSTER.keys()

func active_slugs() -> Array:
	return ROSTER.keys().filter(func(s): return ROSTER[s]["v1_active"])

func walker_slugs() -> Array:
	# Non-boss enemies that appear in waves.
	return ROSTER.keys().filter(func(s): return ROSTER[s]["v1_active"] and not ROSTER[s]["is_boss"])

func boss_slug() -> String:
	for s in ROSTER.keys():
		if ROSTER[s]["is_boss"]:
			return s
	return ""

func get_portrait(slug: String) -> Texture2D:
	var entry := get_entry(slug)
	if entry.is_empty():
		return null
	return load(entry["portrait"]) as Texture2D

func get_cutout(slug: String) -> Texture2D:
	var entry := get_entry(slug)
	if entry.is_empty():
		return null
	var path: String = (entry["portrait"] as String).replace(".png", "-cutout.png")
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return load(entry["portrait"]) as Texture2D

func get_for_color(color: int) -> Dictionary:
	for slug in walker_slugs():
		if ROSTER[slug]["color"] == color:
			var entry: Dictionary = ROSTER[slug].duplicate()
			entry["slug"] = slug
			return entry
	return {}
