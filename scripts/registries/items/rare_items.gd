class_name RareItems
extends RefCounted

## Rare tier items (Rarity: RARE, Base Price: 110)
## 14 items total

static func get_all() -> Dictionary:
	return {
		# Interesting unique effects
		"volatile_rounds": _create_volatile_rounds(),
		"incendiary_gel": _create_incendiary_gel(),
		"targeting_matrix": _create_targeting_matrix(),
		"plasma_capacitor": _create_plasma_capacitor(),
		"insulated_coating": _create_insulated_coating(),
		"thermal_amplifier": _create_thermal_amplifier(),

		# Economy
		"quality_over_quantity": _create_quality_over_quantity(),
		"bargain_hunter": _create_bargain_hunter(),
		"probability_matrix": _create_probability_matrix(),

		# Army strategy
		"army_doctrine": _create_army_doctrine(),
		"elite_forces": _create_elite_forces(),

		# Turret variety
		"standardized_parts": _create_standardized_parts(),
		"cross_training": _create_cross_training(),

		# Trade-offs
		"fortified_core": _create_fortified_core(),
		"overclocked_motors": _create_overclocked_motors(),

		# Proximity
		"isolation_protocol": _create_isolation_protocol(),
		"feedback_loop": _create_feedback_loop(),
	}


# ==========================================================================
# INTERESTING UNIQUE EFFECTS
# ==========================================================================

static func _create_volatile_rounds() -> Item:
	var item := Item.new()
	item.item_id = "volatile_rounds"
	item.name = "Volatile Rounds"
	item.icon = "🔴"
	item.description = "Turret projectiles explode on hit, but turrets fire slower"
	item.rarity = GameEnums.ItemRarity.RARE
	item.max_stacks = 1
	item.modifiers = [
		Item.create_modifier("aoe_radius", "add", 40.0, Item.filter_turret_type(["normal", "fire"])),
		Item.create_modifier("fire_rate", "multiply", 0.85, Item.filter_turret_type(["all"]))
	]
	return item


static func _create_incendiary_gel() -> Item:
	var item := Item.new()
	item.item_id = "incendiary_gel"
	item.name = "Incendiary Gel"
	item.icon = "🩸"
	item.description = "Fire effects last twice as long and tick faster"
	item.rarity = GameEnums.ItemRarity.RARE
	item.max_stacks = 1
	item.modifiers = [
		Item.create_modifier("dot_duration", "multiply", 2.0, Item.filter_turret_type(["fire"])),
		Item.create_modifier("dot_tick_rate", "multiply", 0.5, Item.filter_turret_type(["fire"]))
	]
	return item


static func _create_targeting_matrix() -> Item:
	var item := Item.new()
	item.item_id = "targeting_matrix"
	item.name = "Targeting Matrix"
	item.icon = "🎯"
	item.description = "Turrets rotate 100% faster and have 15% increased fire rate"
	item.rarity = GameEnums.ItemRarity.RARE
	item.modifiers = [
		Item.create_modifier("rotation_speed", "multiply", 2.0, Item.filter_turret_type(["all"])),
		Item.create_modifier("fire_rate", "multiply", 1.15, Item.filter_turret_type(["all"]))
	]
	return item


static func _create_plasma_capacitor() -> Item:
	var item := Item.new()
	item.item_id = "plasma_capacitor"
	item.name = "Plasma Capacitor"
	item.icon = "🟣"
	item.description = "Plasma explosions are 60% larger with stronger knockback"
	item.rarity = GameEnums.ItemRarity.RARE
	item.modifiers = [
		Item.create_modifier("aoe_radius", "multiply", 1.6, Item.filter_turret_type(["plasma"])),
		Item.create_modifier("knockback_force", "multiply", 1.5, Item.filter_turret_type(["plasma"]))
	]
	return item


static func _create_insulated_coating() -> Item:
	var item := Item.new()
	item.item_id = "insulated_coating"
	item.name = "Insulated Coating"
	item.icon = "🛡️"
	item.description = "Electric turrets +35% damage and +20% range. Fire turrets -15% fire rate"
	item.rarity = GameEnums.ItemRarity.RARE
	item.modifiers = [
		Item.create_modifier("damage", "multiply", 1.35, Item.filter_damage_type([GameEnums.DamageType.ELECTRIC])),
		Item.create_modifier("range", "multiply", 1.20, Item.filter_damage_type([GameEnums.DamageType.ELECTRIC])),
		Item.create_modifier("fire_rate", "multiply", 0.85, Item.filter_damage_type([GameEnums.DamageType.FIRE]))
	]
	return item


static func _create_thermal_amplifier() -> Item:
	var item := Item.new()
	item.item_id = "thermal_amplifier"
	item.name = "Thermal Amplifier"
	item.icon = "🔥"
	item.description = "Fire turrets +50% DoT damage and +1.0s DoT duration. All turrets -8% projectile speed"
	item.rarity = GameEnums.ItemRarity.RARE
	item.max_stacks = 2
	item.modifiers = [
		Item.create_modifier("dot_damage", "multiply", 1.50, Item.filter_damage_type([GameEnums.DamageType.FIRE])),
		Item.create_modifier("dot_duration", "add", 1.0, Item.filter_damage_type([GameEnums.DamageType.FIRE])),
		Item.create_modifier("projectile_speed", "multiply", 0.92, Item.filter_turret_type(["all"]))
	]
	return item


# ==========================================================================
# ECONOMY
# ==========================================================================

static func _create_quality_over_quantity() -> Item:
	var item := Item.new()
	item.item_id = "quality_over_quantity"
	item.name = "Quality Over Quantity"
	item.icon = "👑"
	item.description = "Waves spawn -30% fewer enemies. Gold per enemy +100%. Turret prices +15%"
	item.rarity = GameEnums.ItemRarity.RARE
	item.max_stacks = 1
	item.modifiers = [
		Item.create_modifier("enemy_count_mult", "multiply", 0.70),
		Item.create_modifier("gold_earn_mult", "multiply", 2.0),
		Item.create_modifier("shop_price_mult", "multiply", 1.15)
	]
	return item


static func _create_bargain_hunter() -> Item:
	var item := Item.new()
	item.item_id = "bargain_hunter"
	item.name = "Bargain Hunter"
	item.icon = "🏷️"
	item.description = "Reroll costs -40%. Shop offers +1 slot. All turrets -8% damage"
	item.rarity = GameEnums.ItemRarity.RARE
	item.max_stacks = 2
	item.modifiers = [
		Item.create_modifier("reroll_cost", "multiply", 0.60),
		Item.create_modifier("shop_offer_count", "add", 1),
		Item.create_modifier("damage", "multiply", 0.92, Item.filter_turret_type(["all"]))
	]
	return item


static func _create_probability_matrix() -> Item:
	var item := Item.new()
	item.item_id = "probability_matrix"
	item.name = "Probability Matrix"
	item.icon = "🎲"
	item.description = "+25 luck, but rerolls cost 50% more."
	item.rarity = GameEnums.ItemRarity.RARE
	item.modifiers = [
		Item.create_modifier("player_luck", "add", 0.25),
		Item.create_modifier("reroll_cost", "multiply", 1.5)
	]
	return item


# ==========================================================================
# ARMY STRATEGY
# ==========================================================================

static func _create_army_doctrine() -> Item:
	var item := Item.new()
	item.item_id = "army_doctrine"
	item.name = "Army Doctrine"
	item.icon = "🪖"
	item.description = "For each turret beyond the 5th, all turrets gain +3% fire rate (max +30%). -10% range"
	item.rarity = GameEnums.ItemRarity.RARE
	item.max_stacks = 1
	item.special_effect = "army_doctrine"
	item.modifiers = [
		Item.create_modifier("range", "multiply", 0.90, Item.filter_turret_type(["all"]))
	]
	return item


static func _create_elite_forces() -> Item:
	var item := Item.new()
	item.item_id = "elite_forces"
	item.name = "Elite Forces"
	item.icon = "⭐"
	item.description = "If you own ≤5 turrets: all turrets +40% damage, +25% range. Penalty increased to 40% per turret"
	item.rarity = GameEnums.ItemRarity.RARE
	item.max_stacks = 1
	item.special_effect = "elite_forces"
	item.modifiers = [
		Item.create_modifier("turret_penalty_increase", "add", 0.15)
	]
	return item


# ==========================================================================
# TURRET VARIETY
# ==========================================================================

static func _create_standardized_parts() -> Item:
	var item := Item.new()
	item.item_id = "standardized_parts"
	item.name = "Standardized Parts"
	item.icon = "🔧"
	item.description = "Owning multiple of the same turret type grants +5% fire rate per duplicate. Mixed types -12% range"
	item.rarity = GameEnums.ItemRarity.RARE
	item.max_stacks = 1
	item.special_effect = "standardized_parts"
	item.modifiers = [
		Item.create_modifier("range", "multiply", 0.88, Item.filter_turret_type(["all"]))
	]
	return item


static func _create_cross_training() -> Item:
	var item := Item.new()
	item.item_id = "cross_training"
	item.name = "Cross-Training"
	item.icon = "🎓"
	item.description = "For every 2 different turret types owned, all turrets gain +15% rotation speed. -5% damage"
	item.rarity = GameEnums.ItemRarity.RARE
	item.special_effect = "cross_training"
	item.modifiers = [
		Item.create_modifier("damage", "multiply", 0.95, Item.filter_turret_type(["all"]))
	]
	return item


# ==========================================================================
# TRADE-OFFS
# ==========================================================================

static func _create_fortified_core() -> Item:
	var item := Item.new()
	item.item_id = "fortified_core"
	item.name = "Fortified Core"
	item.icon = "💚"
	item.description = "+25 max HP, but 10% less turret damage"
	item.rarity = GameEnums.ItemRarity.RARE
	item.modifiers = [
		Item.create_modifier("player_max_health", "add", 25.0),
		Item.create_modifier("damage", "multiply", 0.90, Item.filter_turret_type(["all"]))
	]
	return item


static func _create_overclocked_motors() -> Item:
	var item := Item.new()
	item.item_id = "overclocked_motors"
	item.name = "Overclocked Motors"
	item.icon = "⚙️"
	item.description = "+20% turret rotation speed, but 5% slower fire rate"
	item.rarity = GameEnums.ItemRarity.RARE
	item.modifiers = [
		Item.create_modifier("rotation_speed", "multiply", 1.20, Item.filter_turret_type(["all"])),
		Item.create_modifier("fire_rate", "multiply", 0.95, Item.filter_turret_type(["all"]))
	]
	return item


# ==========================================================================
# PROXIMITY
# ==========================================================================

static func _create_isolation_protocol() -> Item:
	var item := Item.new()
	item.item_id = "isolation_protocol"
	item.name = "Isolation Protocol"
	item.icon = "🛡️"
	item.description = "Turrets >250px from all others +40% damage. Turrets within 250px -15% damage"
	item.rarity = GameEnums.ItemRarity.RARE
	item.max_stacks = 2
	item.special_effect = "isolation_protocol"
	item.modifiers = []
	return item


static func _create_feedback_loop() -> Item:
	var item := Item.new()
	item.item_id = "feedback_loop"
	item.name = "Feedback Loop"
	item.icon = "🔄"
	item.description = "+6% fire rate per turret within 180px (max +30% with 5 nearby). All turrets -8% range"
	item.rarity = GameEnums.ItemRarity.RARE
	item.max_stacks = 1
	item.special_effect = "feedback_loop"
	item.modifiers = [
		Item.create_modifier("range", "multiply", 0.92)
	]
	return item
