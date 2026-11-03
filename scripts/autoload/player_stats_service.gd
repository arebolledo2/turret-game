extends Node

var state: RunSessionState = RunSessionState.new()

var rng: RandomNumberGenerator = GameRandom.gameplay
var _weapon_cache: Dictionary = {}

func _ready() -> void:
	Events.modifiers_changed.connect(func() -> void: _weapon_cache.clear())


## Player Stats Service
## Manages player health, speed, luck, and stat modifiers

# Core player stats
var player_luck: int:
	get: return state.player_luck
	set(value): state.player_luck = value

func reset_state() -> void:
	_weapon_cache.clear()
	player_luck = GameConstants.PLAYER_BASE_LUCK
	state.hero_progression = HeroProgression.new()

## The hero's level and form growth; identity multipliers when progression is off.
func hero_multipliers() -> Dictionary:
	if not state.turret_progression_enabled:
		return {"health": 1.0, "damage": 1.0, "fire_rate": 1.0, "range": 1.0}
	return state.hero_progression.stat_multipliers()


## Get player speed with modifiers applied
func get_player_speed() -> float:
	return ModifierService.apply_modifiers_to_stat(GameConstants.PLAYER_SPEED, "player_speed", "player")


## Convoy mode: the core's driving speed in metres per second, floored so it can never stall
func get_core_move_speed() -> float:
	var speed := ModifierService.apply_modifiers_to_stat(GameConstants.CORE_MOVE_SPEED, "core_move_speed", "core")
	return maxf(speed, GameConstants.CORE_MIN_MOVE_SPEED)


## Get player max health with modifiers applied
func get_player_max_health(difficulty_mult: float) -> float:
	var base_health := GameConstants.PLAYER_BASE_MAX_HEALTH * difficulty_mult * float(hero_multipliers().health)
	return ModifierService.apply_modifiers_to_stat(base_health, "player_max_health", "player")


## Get player weapon damage with modifiers applied
func get_player_weapon_damage() -> float:
	return float(get_weapon_stats().damage)


## Get player luck points (uncapped, may be negative) with modifiers applied
func get_player_luck() -> int:
	return roundi(ModifierService.apply_modifiers_to_stat(float(player_luck), "player_luck", "player"))


## Luck points as the signed display integer
func get_player_luck_display() -> int:
	return get_player_luck()


## Luck points converted to the diminishing-returns factor that rolls use
func get_luck_factor() -> float:
	return ItemRegistry.luck_factor_for(float(get_player_luck()))


## Get pickup radius with modifiers applied
func get_pickup_radius() -> float:
	return ModifierService.apply_modifiers_to_stat(GameConstants.PLAYER_PICKUP_RADIUS, "pickup_radius", "player")


## Get player crit chance with modifiers applied
func get_player_crit_chance() -> float:
	return ModifierService.apply_modifiers_to_stat(GameConstants.PLAYER_BASE_CRIT_CHANCE, "player_crit_chance", "player")


## Get player crit multiplier with modifiers applied
func get_player_crit_multiplier() -> float:
	return ModifierService.apply_modifiers_to_stat(GameConstants.PLAYER_BASE_CRIT_MULTIPLIER, "player_crit_multiplier", "player")


## Roll for critical hit (returns true if crit)
func roll_player_crit() -> bool:
	return rng.randf() < get_player_crit_chance()


## Calculate crit damage
func calculate_player_crit_damage(base_damage: float) -> float:
	return base_damage * get_player_crit_multiplier()


## Get player health regen with modifiers applied (whole number)
func get_player_health_regen() -> int:
	var modified := ModifierService.apply_modifiers_to_stat(
		float(GameConstants.PLAYER_BASE_HEALTH_REGEN), "player_health_regen", "player"
	)
	return int(modified)


## Get healing interval in seconds (-1 if no healing)
func get_heal_interval() -> float:
	var regen := get_player_health_regen()
	if regen <= 0:
		return -1.0
	return GameConstants.PLAYER_BASE_HEAL_INTERVAL / float(regen)


## Get damage reduction multiplier (0.15 reduction -> 0.85 multiplier)
func get_damage_reduction() -> float:
	var reduction := ModifierService.apply_modifiers_to_stat(0.0, "damage_reduction", "player")
	return clampf(1.0 - reduction, 0.0, 1.0)


## Current hero is Pip: an Ion sidearm. The run profile owns this weapon and starting turret.
func get_weapon_stats(profile: Dictionary = {}, cached: bool = true) -> Dictionary:
	var definition := HeroLoadouts.pip() if profile.is_empty() else profile
	var progression := state.hero_progression
	var key := hash([definition, state.turret_progression_enabled, progression.level, progression.evolution_form])
	if cached and _weapon_cache.has(key):
		return _weapon_cache[key]
	var base: Dictionary = definition.weapon.duplicate(true)
	var growth := hero_multipliers()
	base.damage = ModifierService.apply_modifiers_to_stat(float(base.damage) * float(growth.damage), "player_weapon_damage", "player")
	base.fire_rate = ModifierService.apply_modifiers_to_stat(float(base.fire_rate) * float(growth.fire_rate), "player_fire_rate", "player")
	base.range = float(base.range) * float(growth.range)
	var families: Array[String] = []
	families.assign(definition.families)
	var capabilities: Array[String] = []
	capabilities.assign(definition.capabilities)
	var resolved := ModifierService.get_hero_weapon_stats(base, families, capabilities)
	if cached:
		_weapon_cache[key] = resolved
	return resolved
