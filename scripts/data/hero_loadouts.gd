class_name HeroLoadouts
extends RefCounted

## Definitions are copied into RunConfig; future heroes can choose another sidearm and starter.
static func pip() -> Dictionary:
	return {"id": "pip", "starting_turret": "normal", "families": ["projectile"],
		"capabilities": ["direct_projectile"], "damage_type": GameEnums.DamageType.PHYSICAL,
		"weapon": {"damage": GameConstants.PLAYER_TURRET_DAMAGE,
		"fire_rate": GameConstants.PLAYER_FIRE_RATE, "range": GameConstants.PLAYER_TURRET_RANGE,
		"projectile_speed": GameConstants.PLAYER_TURRET_PROJECTILE_SPEED}}
