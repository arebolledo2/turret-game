extends Node

var state: RunSessionState = RunSessionState.new()

var rng: RandomNumberGenerator = GameRandom.gameplay

## Turret Stats Service
## Manages turret counts, types, and stat calculations with modifiers

# Turret tracking
var turret_counts: Dictionary:
	get: return state.turret_counts
	set(value): state.turret_counts = value

func reset_state() -> void:
	turret_counts.clear()


## Get turret stats with all modifiers applied
## Delegates to ModifierService for consistent stat calculation
func get_turret_stats(turret_type: String, difficulty_turret_damage_mult: float) -> Dictionary:
	if not TurretRegistry.has_type(turret_type):
		return {}

	# Build a minimal difficulty config with the damage mult
	var difficulty_config := {"turret_damage_mult": difficulty_turret_damage_mult}
	return ModifierService.get_turret_stats(turret_type, difficulty_config)


## Check if turret has specific attack style
func turret_has_attack_style(turret_type: String, style: GameEnums.AttackStyle) -> bool:
	return TurretRegistry.has_attack_style(turret_type, style)


## Check if turret has specific damage type
func turret_has_damage_type(turret_type: String, dtype: GameEnums.DamageType) -> bool:
	return TurretRegistry.has_damage_type(turret_type, dtype)


## Get turret crit chance with modifiers applied
func get_turret_crit_chance() -> float:
	return ModifierService.apply_modifiers_to_stat(GameConstants.TURRET_BASE_CRIT_CHANCE, "turret_crit_chance")


## Get turret crit multiplier with modifiers applied
func get_turret_crit_multiplier() -> float:
	return ModifierService.apply_modifiers_to_stat(GameConstants.TURRET_BASE_CRIT_MULTIPLIER, "turret_crit_multiplier")


## Roll for critical hit (returns true if crit)
func roll_turret_crit() -> bool:
	return rng.randf() < get_turret_crit_chance()


## Calculate crit damage
func calculate_turret_crit_damage(base_damage: float) -> float:
	return base_damage * get_turret_crit_multiplier()


## Get total number of turrets owned
func get_total_turret_count() -> int:
	var total := 0
	for count in turret_counts.values():
		total += count
	return total


## Number of owned turrets that attack. Utility (no-attack) turrets are excluded so they cannot inflate Army Doctrine.
func get_attack_turret_count() -> int:
	var total := 0
	for type_id: String in turret_counts:
		if not TurretRegistry.is_no_attack(type_id):
			total += int(turret_counts[type_id])
	return total


## Get number of different turret types owned (e.g., 3 if you own Normal, Fire, and Sniper)
func get_turret_type_diversity() -> int:
	var count := 0
	for type_count in turret_counts.values():
		if type_count > 0:
			count += 1
	return count


## Get number of different damage types represented in owned turrets
func get_damage_type_diversity() -> int:
	var damage_types_seen: Array = []
	for turret_type in turret_counts.keys():
		if turret_counts[turret_type] > 0:
			var turret_def: Dictionary = TurretRegistry.get_type(turret_type)
			var dtypes: Array = turret_def.get("damage_types", [])
			for dtype in dtypes:
				if dtype not in damage_types_seen:
					damage_types_seen.append(dtype)
	return damage_types_seen.size()


## Maximum matching of owned turret instances to distinct attack families (at most four).
## One hybrid cannot occupy two slots; two owned hybrids can represent separate families.
func get_family_diversity() -> int:
	var reachable: Dictionary = {0: true}
	var families: Array[String] = ["projectile", "aoe", "instant", "kinetic"]
	for type_id: String in turret_counts:
		for instance in range(mini(4, int(turret_counts[type_id]))):
			var next := reachable.duplicate()
			for mask: int in reachable:
				for family in TurretRegistry.get_attack_families(type_id):
					var bit: int = 1 << families.find(family)
					if mask & bit == 0:
						next[mask | bit] = true
			reachable = next
	var best := 0
	for mask: int in reachable:
		var count := 0
		for bit in range(4):
			if mask & (1 << bit):
				count += 1
		best = maxi(best, count)
	return best

## Attack families every owned attacking turret has. No-attack turrets are ignored, so a Beacon beside a focused build
## does not break Focused Arsenal; owning only no-attack turrets shares nothing.
func shared_attack_families() -> Array[String]:
	var shared: Array[String] = ["projectile", "aoe", "instant", "kinetic"]
	var any_owned := false
	for type_id: String in turret_counts:
		if int(turret_counts[type_id]) <= 0 or TurretRegistry.is_no_attack(type_id):
			continue
		any_owned = true
		var present := TurretRegistry.get_attack_families(type_id)
		for i in range(shared.size() - 1, -1, -1):
			if not shared[i] in present:
				shared.remove_at(i)
	return shared if any_owned else []


## Get the most common turret type (returns empty string if no turrets)
func get_most_common_turret_type() -> String:
	var max_count := 0
	var most_common := ""
	for turret_type in turret_counts.keys():
		if turret_counts[turret_type] > max_count:
			max_count = turret_counts[turret_type]
			most_common = turret_type
	return most_common


## Get turret minimum distance (modified by Personal Space item)
func get_turret_min_distance(item_counts: Dictionary) -> float:
	return SpecialEffectService.get_turret_min_distance(item_counts)


## Item adjustments apply to the supplied linear purchase coefficient.
func get_turret_purchase_penalty(base: float = GameConstants.TURRET_PURCHASE_PENALTY) -> float:
	var penalty: float = base
	# Apply reductions (e.g., Compact Design, Mass Production)
	penalty = ModifierService.apply_modifiers_to_stat(penalty, "turret_penalty_reduction")
	# Apply increases (e.g., Elite Forces, Diversity Matrix)
	penalty = ModifierService.apply_modifiers_to_stat(penalty, "turret_penalty_increase")
	return maxf(0.0, penalty)
