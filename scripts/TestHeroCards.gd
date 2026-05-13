# TestHeroCards — populates the bubble row at runtime from BubbleRoster.
# Heroes + enemies use their own card scenes with @export slugs; bubbles
# are simple TextureRects whose textures we set here from the autoload.

extends Control

func _ready() -> void:
	var colors := [
		GameConfig.BubbleColor.RED,
		GameConfig.BubbleColor.BLUE,
		GameConfig.BubbleColor.YELLOW,
		3, # GREEN (v2)
		4, # PURPLE (v2)
	]
	var slots: Array = $BubbleRow.get_children()
	for i in min(colors.size(), slots.size()):
		var tex: Texture2D = BubbleRoster.get_cutout(colors[i])
		if tex and slots[i] is TextureRect:
			(slots[i] as TextureRect).texture = tex
