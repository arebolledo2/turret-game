class_name TurretRegistry
extends RefCounted

## Registry of all turret types and helper functions

## How a turret attacks in the 3D arena; `TurretActor` dispatches on this instead of the type id.
const FIRE_PROJECTILE: String = "projectile" # aimed shot at one target
const FIRE_PULSE: String = "pulse" # area pulse around the turret
const FIRE_CHAIN: String = "chain" # lightning that jumps between enemies
const FIRE_FLAME: String = "flame" # aimed cone with burn over time
const FIRE_SWEEP: String = "sweep" # spinning melee bat

const DEFAULT_MODEL: String = "res://assets/models/game/ion_turret.glb"

# Color tints for turret types
const COLORS: Dictionary = {
	"bow": Color("e7d89b"), "flamethrower": Color("ff974a"), "bowling": Color("9281c9"),
	"normal": Color("66CC66"),
	"sniper": Color("4466AA"),
	"fire": Color("FF6633"),
	"plasma": Color("AA44DD"),
	"shock": Color("DDDD44"),
	"tesla": Color("44DDDD"),
	"melee": Color("999999"),
	"mine": Color("DD8844"),
}

# Base prices for turret types
const BASE_PRICES: Dictionary = {
	"bow": 16, "flamethrower": 18, "bowling": 18,
	"normal": 8,
	"sniper": 18,
	"fire": 13,
	"plasma": 16,
	"shock": 14,
	"tesla": 17,
	"melee": 12,
	"mine": 15,
}

## Player-facing build families. Items target these (modifier filter `family`) so a tag reads the same on the card and on the turret.
const FAMILIES: Dictionary = {
	"ion": ["normal"],
	"plasma": ["plasma"],
	"electric": ["shock", "tesla"],
	"melee": ["melee"],
}

const TYPES: Dictionary = {
	"bow": {
		"name": "Bow Turret", "short_name": "Bow", "fire_mode": FIRE_PROJECTILE,
		"description": "Fires fast arrows that pierce through two enemies.",
		"attack_styles": [GameEnums.AttackStyle.PROJECTILE],
		"damage_types": [GameEnums.DamageType.PHYSICAL],
		"base_stats": {"damage": 18.0, "fire_rate": .9, "range": 340.0, "projectile_speed": 850.0, "pierce": 1},
	},
	"flamethrower": {
		"name": "Flamethrower", "short_name": "Flame", "fire_mode": FIRE_FLAME,
		"description": "Bathes a forward cone in fire. Enemies keep burning after leaving the flame.",
		"attack_styles": [GameEnums.AttackStyle.AOE],
		"damage_types": [GameEnums.DamageType.FIRE],
		"base_stats": {"damage": 2.5, "fire_rate": 4.0, "range": 200.0, "burn_ratio": 1.6, "burn_duration": 2.0, "cone_degrees": 36.0},
	},
	"bowling": {
		"name": "Bowling Launcher", "short_name": "Bowling", "fire_mode": FIRE_PROJECTILE,
		"description": "Rolls heavy bowling balls through enemies, knocking them back.",
		"attack_styles": [GameEnums.AttackStyle.PROJECTILE, GameEnums.AttackStyle.MELEE],
		"damage_types": [GameEnums.DamageType.PHYSICAL],
		"base_stats": {"damage": 20.0, "fire_rate": .6, "range": 320.0, "projectile_speed": 270.0, "pierce": 5, "knockback_force": 250.0},
	},
	"normal": {
		"name": "Normal Turret",
		"icon": "🗼",
		"short_name": "Ion",
		"model": "res://assets/models/game/ion_turret.glb",
		"fire_mode": FIRE_PROJECTILE,
		"description": "Standard auto-targeting turret. Reliable and consistent.",
		"attack_styles": [GameEnums.AttackStyle.PROJECTILE],
		"damage_types": [GameEnums.DamageType.PHYSICAL],
		"base_stats": {
			"damage": 13.0,
			"fire_rate": 1.2,
			"range": 240.0,
			"rotation_speed": 0.0,
			"projectile_speed": 700.0,
			"pierce": 0,
		}
	},
	"sniper": {
		"name": "Sniper Turret",
		"icon": "🎯",
		"description": "Long-range instant-hit turret. High damage, slow fire rate.",
		"attack_styles": [GameEnums.AttackStyle.INSTANT],
		"damage_types": [GameEnums.DamageType.PHYSICAL],
		"base_stats": {
			"damage": 18.0,
			"fire_rate": 0.5,
			"range": 750.0,
			"rotation_speed": 0.0,
			"targeting": "farthest",
		}
	},
	"fire": {
		"name": "Fire Turret",
		"icon": "🔥",
		"description": "Incendiary turret that ignites enemies.",
		"attack_styles": [GameEnums.AttackStyle.PROJECTILE],
		"damage_types": [GameEnums.DamageType.FIRE],
		"base_stats": {
			"damage": 5.0,
			"fire_rate": 2.0,
			"range": 210.0,
			"rotation_speed": 0.0,
			"projectile_speed": 600.0,
			"pierce": 99,
			"dot_damage": 2.0,
			"dot_duration": 3.0,
			"dot_tick_rate": 1.0,
		}
	},
	"plasma": {
		"name": "Plasma Turret",
		"icon": "💠",
		"model": "res://assets/models/game/plasma_turret.glb",
		"fire_mode": FIRE_PROJECTILE,
		"cluster_target": true,
		"description": "Fires explosive plasma orbs that damage an area.",
		"attack_styles": [GameEnums.AttackStyle.PROJECTILE, GameEnums.AttackStyle.AOE],
		"damage_types": [GameEnums.DamageType.PLASMA],
		"base_stats": {
			"damage": 10.0,
			"fire_rate": 1.0,
			"range": 255.0,
			"rotation_speed": 0.0,
			"projectile_speed": 550.0,
			"pierce": 0,
			"aoe_radius": 100.0,
			"knockback_force": 120.0,
			"targeting": "cluster",
		}
	},
	"shock": {
		"name": "Shock Turret",
		"icon": "⚡",
		"model": "res://assets/models/game/shock_turret.glb",
		"fire_mode": FIRE_PULSE,
		"description": "Pulses electric damage around itself.",
		"attack_styles": [GameEnums.AttackStyle.INSTANT, GameEnums.AttackStyle.AOE],
		"damage_types": [GameEnums.DamageType.ELECTRIC],
		"base_stats": {
			"damage": 4.0,
			"fire_rate": 1.2,
			"range": 240.0,
			"rotation_speed": 0.0,
			"slow_intensity": 0.25,
			"slow_duration": 0.5,
		}
	},
	"tesla": {
		"name": "Tesla Turret",
		"icon": "⛓️",
		"model": "res://assets/models/game/ion_turret.glb",
		"fire_mode": FIRE_CHAIN,
		"description": "Fires chain lightning that jumps between enemies.",
		"attack_styles": [GameEnums.AttackStyle.INSTANT, GameEnums.AttackStyle.CHAIN],
		"damage_types": [GameEnums.DamageType.ELECTRIC],
		"base_stats": {
			"damage": 10.0,
			"fire_rate": 1.2,
			"range": 225.0,
			"rotation_speed": 0.0,
			"chain_count": 3,
			"chain_range": 225.0,
			"chain_decay": 0.7,
		}
	},
	"melee": {
		"name": "Melee Turret",
		"icon": "⚔️",
		"fire_mode": FIRE_SWEEP,
		"description": "Spinning bat that damages and knocks back enemies on contact.",
		"attack_styles": [GameEnums.AttackStyle.MELEE],
		"damage_types": [GameEnums.DamageType.PHYSICAL],
		"base_stats": {
			"damage": 8.0,
			"fire_rate": 0.0,
			"range": 120.0,
			"rotation_speed": 0.0,
			"rotation_rate": 360.0,
			"knockback_force": 80.0,
			"rehit_delay": 0.5,
		}
	},
	"mine": {
		"name": "Mine Turret",
		"icon": "💣",
		"description": "Deploys proximity mines that explode when enemies approach.",
		"attack_styles": [GameEnums.AttackStyle.DEPLOYABLE],
		"damage_types": [GameEnums.DamageType.PHYSICAL],
		"base_stats": {
			"damage": 15.0,
			"fire_rate": 0.33,
			"range": 225.0,
			"rotation_speed": 0.0,
			"explosive_radius": 70.0,
			"proximity_radius": 40.0,
			"max_mines": 5,
			"knockback_force": 150.0,
		}
	},
}


## Get the definition for a turret type
static func get_type(type_id: String) -> Dictionary:
	return TYPES.get(type_id, TYPES["normal"])


## Family id ("ion", "plasma", "electric", "melee") a turret type belongs to, or "" if it has none.
static func get_family(type_id: String) -> String:
	for family: String in FAMILIES:
		if type_id in FAMILIES[family]:
			return family
	return ""


## Attack behaviour of a turret type (one of the FIRE_* constants).
static func get_fire_mode(type_id: String) -> String:
	return get_type(type_id).get("fire_mode", FIRE_PROJECTILE)


## Model scene for a turret type. Types without their own fall back to the ion turret; the melee bat is built in code.
static func get_model_path(type_id: String) -> String:
	return get_type(type_id).get("model", DEFAULT_MODEL)


## True when the turret aims at the densest cluster of enemies instead of the nearest.
static func targets_clusters(type_id: String) -> bool:
	return get_type(type_id).get("cluster_target", false)


## Damage type its shots carry (first of the type's damage types).
static func get_damage_type(type_id: String) -> GameEnums.DamageType:
	return get_type(type_id).get("damage_types", [GameEnums.DamageType.PHYSICAL])[0]


## Short player-facing name for shop and summary text.
static func get_short_name(type_id: String) -> String:
	return get_type(type_id).get("short_name", type_id.capitalize())


## Get all type IDs
static func get_all_type_ids() -> Array:
	return TYPES.keys()


## Get base stats for a turret type
static func get_base_stats(type_id: String) -> Dictionary:
	if not TYPES.has(type_id):
		return TYPES["normal"]["base_stats"].duplicate(true)
	return TYPES[type_id]["base_stats"].duplicate(true)


## Get turret color tint
static func get_color(type_id: String) -> Color:
	var asset_config := AssetConfigService.get_turret_config(type_id)
	if asset_config and asset_config.visual:
		var configured_color: Color = asset_config.visual.modulate
		if not configured_color.is_equal_approx(Color.WHITE):
			return configured_color
	return COLORS.get(type_id, Color.WHITE)


## Get the primary configured sprite path for a turret type
static func get_sprite_path(type_id: String) -> String:
	var asset_config := AssetConfigService.get_turret_config(type_id)
	if asset_config and asset_config.visual:
		if asset_config.visual.texture_paths.has("default"):
			return str(asset_config.visual.texture_paths.get("default", ""))
		if asset_config.visual.texture_paths.has("right"):
			return str(asset_config.visual.texture_paths.get("right", ""))
	return ""


## Get turret base price
static func get_base_price(type_id: String) -> int:
	return BASE_PRICES.get(type_id, 50)


## Check if turret has a specific attack style
static func has_attack_style(type_id: String, style: GameEnums.AttackStyle) -> bool:
	if not TYPES.has(type_id):
		return false
	return style in TYPES[type_id].get("attack_styles", [])


## Check if turret has a specific damage type
static func has_damage_type(type_id: String, dtype: GameEnums.DamageType) -> bool:
	if not TYPES.has(type_id):
		return false
	return dtype in TYPES[type_id].get("damage_types", [])


## Get targeting strategy for a turret type
static func get_targeting(type_id: String) -> String:
	if not TYPES.has(type_id):
		return "closest"
	return TYPES[type_id].get("targeting", "closest")

## Item eligibility is independent of turret identity and elemental damage.
static func get_attack_families(type_id: String) -> Array[String]:
	var result: Array[String] = []
	var styles: Array = get_type(type_id).get("attack_styles", [])
	for pair: Array in [[GameEnums.AttackStyle.PROJECTILE, "projectile"], [GameEnums.AttackStyle.AOE, "aoe"],
			[GameEnums.AttackStyle.INSTANT, "instant"], [GameEnums.AttackStyle.MELEE, "kinetic"]]:
		if pair[0] in styles:
			result.append(pair[1])
	return result

static func has_capability(type_id: String, capability: String) -> bool:
	var families := get_attack_families(type_id)
	var stats := get_base_stats(type_id)
	match capability:
		"direct_projectile": return "projectile" in families and not "aoe" in families
		"chain": return has_attack_style(type_id, GameEnums.AttackStyle.CHAIN)
		"slow": return float(stats.get("slow_intensity", 0.0)) > 0.0
		"knockback": return float(stats.get("knockback_force", 0.0)) > 0.0
	return false
