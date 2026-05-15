# BoonDB — autoload singleton. Single source of truth for every boon in the
# game: id, label, rarity, effect_key. StageClear reads this for the offer
# pool; MatchScene/Cannon/Hero/Lane/RunState read effect_key to apply effects.
#
# Rarity tiers (also controls draw weights and card tint):
#   Common (60), Rare (25), Epic (12), Legendary (3)
#
# Legacy IDs (red_bias…ricochet_plus) are kept verbatim so existing telemetry
# stays comparable across builds — they just gained a rarity field.

extends Node

enum Rarity { COMMON, RARE, EPIC, LEGENDARY }

const RARITY_WEIGHTS := {
	Rarity.COMMON:    60,
	Rarity.RARE:      25,
	Rarity.EPIC:      12,
	Rarity.LEGENDARY:  3,
}

const RARITY_TINT := {
	Rarity.COMMON:    Color(0.62, 0.66, 0.72),   # grey-blue
	Rarity.RARE:      Color(0.30, 0.55, 0.95),   # blue
	Rarity.EPIC:      Color(0.70, 0.35, 0.95),   # purple
	Rarity.LEGENDARY: Color(0.98, 0.78, 0.20),   # gold
}

const RARITY_LABEL := {
	Rarity.COMMON:    "COMMON",
	Rarity.RARE:      "RARE",
	Rarity.EPIC:      "EPIC",
	Rarity.LEGENDARY: "LEGENDARY",
}

# id → { label, rarity, effect_key }
# label uses \n for card-friendly line breaks.
#
# 2026-05-15 cleanup: removed 10 boons whose effects either had stub `pass`
# handlers or set state nothing else reads (ricochet_plus, double_loader,
# extra_special, hall_of_heroes, type_caster, elemental_surge, coin_magnet,
# shop_discount, reroll_token, treasure_wave). v1 has no economy, no shop,
# no hero-slot cap, no special-proc system — so those boons couldn't land.
const BOONS := {
	# ---------- Color bias + class damage ----------
	"red_bias":       { "label": "+30%\nRED\nbubbles",      "rarity": Rarity.COMMON, "effect_key": "cannon_color_bias" },
	"blue_bias":      { "label": "+30%\nBLUE\nbubbles",     "rarity": Rarity.COMMON, "effect_key": "cannon_color_bias" },
	"yellow_bias":    { "label": "+30%\nYELLOW\nbubbles",   "rarity": Rarity.COMMON, "effect_key": "cannon_color_bias" },
	"red_dmg":        { "label": "+25%\nRED\nhero dmg",     "rarity": Rarity.RARE,   "effect_key": "lane_color_dmg" },
	"blue_dmg":       { "label": "+25%\nBLUE\nhero dmg",    "rarity": Rarity.RARE,   "effect_key": "lane_color_dmg" },
	"yellow_dmg":     { "label": "+25%\nYELLOW\nhero dmg",  "rarity": Rarity.RARE,   "effect_key": "lane_color_dmg" },

	# ---------- Cannon ----------
	"faster_fire":    { "label": "Faster\ncannon\nfire",                "rarity": Rarity.COMMON,    "effect_key": "cannon_fire_rate" },
	"rapid_fire":     { "label": "RAPID\nFIRE\n-25% reload",            "rarity": Rarity.COMMON,    "effect_key": "cannon_rapid_fire" },
	"heavy_shot":     { "label": "HEAVY\nSHOT\n+10% hero dmg",          "rarity": Rarity.COMMON,    "effect_key": "global_dmg_bonus" },
	"wide_barrel":    { "label": "WIDE\nBARREL\n+20% hit zone",         "rarity": Rarity.RARE,      "effect_key": "cannon_wide_barrel" },
	"chain_pop":      { "label": "CHAIN\nPOP\npop+1 neighbor",          "rarity": Rarity.RARE,      "effect_key": "cluster_chain_pop" },
	"twin_cannons":   { "label": "TWIN\nCANNONS\n2 bubbles/shot",       "rarity": Rarity.EPIC,      "effect_key": "cannon_twin" },
	"color_lock":     { "label": "COLOR\nLOCK\nbest-match only",        "rarity": Rarity.EPIC,      "effect_key": "cannon_color_lock" },
	"overcharge":     { "label": "OVERCHARGE\nevery 5th shot\nis a big one", "rarity": Rarity.EPIC, "effect_key": "cannon_overcharge" },
	"infinity_mag":   { "label": "INFINITY\nMAG\nrapid auto-fire",      "rarity": Rarity.LEGENDARY, "effect_key": "cannon_infinity_mag" },

	# ---------- Hero spawn / composition ----------
	"recruitment_drive": { "label": "RECRUITMENT\nDRIVE\n+3 heroes next stage", "rarity": Rarity.COMMON,    "effect_key": "spawn_3_heroes_next_stage" },
	"fresh_blood":       { "label": "FRESH\nBLOOD\n+1 hero now",                "rarity": Rarity.COMMON,    "effect_key": "spawn_1_hero_now" },
	"lucky_draw":        { "label": "LUCKY\nDRAW\nnext hero is silver+",        "rarity": Rarity.RARE,      "effect_key": "next_hero_silver_plus" },
	"reinforcements":    { "label": "REINFORCEMENTS\n+1 hero\nevery 30s",       "rarity": Rarity.EPIC,      "effect_key": "periodic_hero_spawn" },
	"twin_souls":        { "label": "TWIN\nSOULS\nhero drops in pairs",         "rarity": Rarity.EPIC,      "effect_key": "double_hero_drops" },
	"legendary_pact":    { "label": "LEGENDARY\nPACT\nfirst hero is GOLD",      "rarity": Rarity.LEGENDARY, "effect_key": "first_hero_gold" },

	# ---------- Hero combat ----------
	"sharp_steel":    { "label": "SHARP\nSTEEL\n+15% hero dmg",         "rarity": Rarity.COMMON, "effect_key": "global_dmg_bonus_15" },
	"iron_skin":      { "label": "IRON\nSKIN\n+20% hero HP",            "rarity": Rarity.COMMON, "effect_key": "global_hp_bonus_20" },
	"quick_feet":     { "label": "QUICK\nFEET\n+15% atk speed",         "rarity": Rarity.RARE,   "effect_key": "global_atk_speed_15" },
	"berserker_rage": { "label": "BERSERKER\nRAGE\n2x dmg <30% HP",     "rarity": Rarity.EPIC,   "effect_key": "berserker_rage" },
	"vampiric_strike":{ "label": "VAMPIRIC\nSTRIKE\nheal 10% dmg",      "rarity": Rarity.EPIC,   "effect_key": "vampiric_strike" },
	"hero_synergy":   { "label": "HERO\nSYNERGY\ndupes +20% each",      "rarity": Rarity.EPIC,   "effect_key": "hero_synergy" },

	# ---------- Meta / utility ----------
	"time_stop":      { "label": "TIME\nSTOP\npause wave 10s",          "rarity": Rarity.LEGENDARY, "effect_key": "time_stop_10s" },
}


# ============================================================
# Lookup helpers
# ============================================================
func all_ids() -> Array:
	return BOONS.keys()

func has(boon_id: String) -> bool:
	return BOONS.has(boon_id)

func get_entry(boon_id: String) -> Dictionary:
	return BOONS.get(boon_id, {})

func get_label(boon_id: String) -> String:
	return BOONS.get(boon_id, {}).get("label", boon_id)

func get_rarity(boon_id: String) -> int:
	return BOONS.get(boon_id, {}).get("rarity", Rarity.COMMON)

func get_rarity_label(boon_id: String) -> String:
	return RARITY_LABEL.get(get_rarity(boon_id), "?")

func get_tint(boon_id: String) -> Color:
	return RARITY_TINT.get(get_rarity(boon_id), Color.WHITE)

func get_effect_key(boon_id: String) -> String:
	return BOONS.get(boon_id, {}).get("effect_key", "")


# ============================================================
# Weighted draw — returns N distinct boon ids, sampled by tier weight.
# ============================================================
func draw_n_weighted(n: int, exclude: Array = []) -> Array[String]:
	var pool: Array[String] = []
	for id in BOONS.keys():
		if id in exclude: continue
		pool.append(id)
	var out: Array[String] = []
	for _i in range(n):
		if pool.is_empty(): break
		var picked: String = _weighted_pick(pool)
		out.append(picked)
		pool.erase(picked)
	return out

func _weighted_pick(pool: Array[String]) -> String:
	var weights: Array[float] = []
	var total: float = 0.0
	for id in pool:
		var w: float = float(RARITY_WEIGHTS.get(get_rarity(id), 1))
		weights.append(w)
		total += w
	var roll: float = randf() * total
	var acc: float = 0.0
	for i in range(pool.size()):
		acc += weights[i]
		if roll <= acc:
			return pool[i]
	return pool[pool.size() - 1]
