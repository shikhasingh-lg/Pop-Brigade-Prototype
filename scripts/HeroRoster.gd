# HeroRoster — autoload singleton
#
# Registry of named hero archetypes for v1 + v2.
# Maps slug → metadata (display name, archetype, portrait path, BubbleColor binding).
#
# v1 active: fire-knight (RED), ice-mage (BLUE), archer (YELLOW).
# v2 reserved: druid (GREEN/heal), wizard (PURPLE/AOE).
#
# Usage:
#   HeroRoster.get("fire-knight").portrait     -> Texture2D
#   HeroRoster.get("fire-knight").color        -> GameConfig.BubbleColor.RED
#   HeroRoster.get_for_color(GameConfig.BubbleColor.RED) -> Dictionary (entry)

extends Node

const ROSTER := {
	"fire-knight": {
		"name":     "Ember",
		"archetype": "Fire Knight",
		"role":      "Tank / melee bruiser",
		"portrait":  "res://assets/heroes/fire-knight/fire-knight.png",
		"color":     0,        # BubbleColor.RED
		"v1_active": true,
	},
	"ice-mage": {
		"name":     "Frost",
		"archetype": "Ice Mage",
		"role":      "Ranged AoE slow",
		"portrait":  "res://assets/heroes/ice-mage/ice-mage.png",
		"color":     1,        # BubbleColor.BLUE
		"v1_active": true,
	},
	"archer": {
		"name":     "Robin",
		"archetype": "Archer",
		"role":      "Ranged single-target",
		"portrait":  "res://assets/heroes/archer/archer.png",
		"color":     2,        # BubbleColor.YELLOW
		"v1_active": true,
	},
	"druid": {
		"name":     "Willow",
		"archetype": "Druid",
		"role":      "Healer / support",
		"portrait":  "res://assets/heroes/druid/druid.png",
		"color":     3,        # BubbleColor.GREEN (R3+)
		"v1_active": true,
	},
	"wizard": {
		"name":     "Merlin",
		"archetype": "Wizard",
		"role":      "Ranged AOE burst",
		"portrait":  "res://assets/heroes/wizard/wizard.png",
		"color":     4,        # BubbleColor.PURPLE (R5+)
		"v1_active": true,
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

func get_portrait(slug: String) -> Texture2D:
	# White-background portrait (cards, menus, post-game results).
	var entry := get_entry(slug)
	if entry.is_empty():
		return null
	var path: String = entry["portrait"]
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

func get_cutout(slug: String) -> Texture2D:
	# Transparent-background cutout (lane sprites, in-game compositing).
	# Falls back to portrait if cutout doesn't exist on disk.
	var entry := get_entry(slug)
	if entry.is_empty():
		return null
	var path: String = (entry["portrait"] as String).replace(".png", "-cutout.png")
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	var portrait: String = entry["portrait"]
	if ResourceLoader.exists(portrait):
		return load(portrait) as Texture2D
	return null

# Returns the first active hero entry bound to a given BubbleColor.
func get_for_color(color: int) -> Dictionary:
	for slug in active_slugs():
		if ROSTER[slug]["color"] == color:
			var entry: Dictionary = ROSTER[slug].duplicate()
			entry["slug"] = slug
			return entry
	return {}
