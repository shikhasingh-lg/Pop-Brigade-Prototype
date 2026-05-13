# BubbleRoster — autoload singleton
#
# Texture lookup for bubble PNGs, keyed by GameConfig.BubbleColor.
# Bubbles are drawn procedurally by default (BubbleVisual.gd `_draw()`).
# Use this when you want to swap to PNG art — e.g. in the cannon HUD,
# on-deck preview, results screen, codex.
#
# Usage:
#   BubbleRoster.get_texture(GameConfig.BubbleColor.RED)
#   BubbleRoster.get_cutout(GameConfig.BubbleColor.RED)

extends Node

# BubbleColor int → slug
const COLOR_TO_SLUG := {
	0: "red",      # BubbleColor.RED
	1: "blue",     # BubbleColor.BLUE
	2: "yellow",   # BubbleColor.YELLOW
	3: "green",    # BubbleColor.GREEN (v2)
	4: "purple",   # BubbleColor.PURPLE (v2)
}

func get_slug(color: int) -> String:
	return COLOR_TO_SLUG.get(color, "")

func get_texture(color: int) -> Texture2D:
	# White-bg version (UI, codex).
	var slug := get_slug(color)
	if slug.is_empty():
		return null
	var path := "res://assets/bubbles/%s/%s.png" % [slug, slug]
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

func get_cutout(color: int) -> Texture2D:
	# Transparent-bg version (in-game over lane/cluster).
	var slug := get_slug(color)
	if slug.is_empty():
		return null
	var path := "res://assets/bubbles/%s/%s-cutout.png" % [slug, slug]
	if not ResourceLoader.exists(path):
		# Fall back to white-bg version if cutout missing
		return get_texture(color)
	return load(path) as Texture2D

func all_colors() -> Array:
	return COLOR_TO_SLUG.keys()

# -----------------------------------------------------------------------------
# Hero bubbles — special bubble variant that spawns a hero when matched.
# Same color keying as regular bubbles; separate art set.
# -----------------------------------------------------------------------------

func get_hero_texture(color: int) -> Texture2D:
	# White-bg hero-bubble (UI, codex).
	var slug := get_slug(color)
	if slug.is_empty():
		return null
	var path := "res://assets/hero-bubbles/%s/%s.png" % [slug, slug]
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

func get_hero_cutout(color: int) -> Texture2D:
	# Transparent hero-bubble (in-game over lane/cluster).
	var slug := get_slug(color)
	if slug.is_empty():
		return null
	var path := "res://assets/hero-bubbles/%s/%s-cutout.png" % [slug, slug]
	if not ResourceLoader.exists(path):
		return get_hero_texture(color)
	return load(path) as Texture2D
