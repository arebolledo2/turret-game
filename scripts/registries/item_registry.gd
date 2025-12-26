class_name ItemRegistry
extends RefCounted

## Modern Item Registry - Aggregates items from tier-specific modules
## Replaces the 904-line monolithic item_registry.gd
##
## Items are now organized by rarity in separate files:
## - common_items.gd (20 items)
## - uncommon_items.gd (10 items)
## - rare_items.gd (17 items)
## - epic_items.gd (9 items)
## - legendary_items.gd (4 items)

# Ensure tier modules are loaded (Godot needs to parse them to make class_name available)
const _ensure_loaded = [
	preload("res://scripts/registries/items/item_base.gd"),
	preload("res://scripts/registries/items/common_items.gd"),
	preload("res://scripts/registries/items/uncommon_items.gd"),
	preload("res://scripts/registries/items/rare_items.gd"),
	preload("res://scripts/registries/items/epic_items.gd"),
	preload("res://scripts/registries/items/legendary_items.gd"),
]

# Rarity color scheme
const RARITY_COLORS: Dictionary = {
	GameEnums.ItemRarity.COMMON: Color.WHITE,
	GameEnums.ItemRarity.UNCOMMON: Color.GREEN,
	GameEnums.ItemRarity.RARE: Color.CORNFLOWER_BLUE,
	GameEnums.ItemRarity.EPIC: Color.PURPLE,
	GameEnums.ItemRarity.LEGENDARY: Color.ORANGE,
	GameEnums.ItemRarity.UNIQUE: Color.RED,
}

const RARITY_NAMES: Dictionary = {
	GameEnums.ItemRarity.COMMON: "Common",
	GameEnums.ItemRarity.UNCOMMON: "Uncommon",
	GameEnums.ItemRarity.RARE: "Rare",
	GameEnums.ItemRarity.EPIC: "Epic",
	GameEnums.ItemRarity.LEGENDARY: "Legendary",
	GameEnums.ItemRarity.UNIQUE: "Unique",
}

const BASE_PRICES: Dictionary = {
	GameEnums.ItemRarity.COMMON: 20,
	GameEnums.ItemRarity.UNCOMMON: 35,
	GameEnums.ItemRarity.RARE: 55,
	GameEnums.ItemRarity.EPIC: 80,
	GameEnums.ItemRarity.LEGENDARY: 120,
	GameEnums.ItemRarity.UNIQUE: 175,
}

# Cached item dictionaries (lazy loaded)
static var _all_items: Dictionary = {}
static var _items_by_rarity: Dictionary = {}


## Get all items as a unified dictionary {item_id: Item}
static func get_all_items() -> Dictionary:
	if _all_items.is_empty():
		_load_all_items()
	return _all_items


## Load all items from tier modules
static func _load_all_items() -> void:
	_all_items.clear()
	_items_by_rarity.clear()

	# Load from each tier - use global class names (class_name declarations)
	# The preloads above ensure Godot has parsed these files
	_all_items.merge(CommonItems.get_all())
	_all_items.merge(UncommonItems.get_all())
	_all_items.merge(RareItems.get_all())
	_all_items.merge(EpicItems.get_all())
	_all_items.merge(LegendaryItems.get_all())


## Get Item resource by ID
static func get_item(item_id: String):
	var items := get_all_items()
	return items.get(item_id, null)


## Get item as Dictionary (for backward compatibility with old API)
static func get_item_dict(item_id: String) -> Dictionary:
	var item = get_item(item_id)
	if item:
		return item.to_dict()
	return {}


## Get all item IDs
static func get_all_item_ids() -> Array:
	return get_all_items().keys()


## Check if an item exists
static func has_item(item_id: String) -> bool:
	return get_all_items().has(item_id)


## Get item rarity
static func get_rarity(item_id: String) -> GameEnums.ItemRarity:
	var item = get_item(item_id)
	if item:
		return item.rarity
	return GameEnums.ItemRarity.COMMON


## Get rarity color
static func get_rarity_color(rarity: GameEnums.ItemRarity) -> Color:
	return RARITY_COLORS.get(rarity, Color.WHITE)


## Get rarity name
static func get_rarity_name(rarity: GameEnums.ItemRarity) -> String:
	return RARITY_NAMES.get(rarity, "Common")


## Get base price for a rarity
static func get_rarity_price(rarity: GameEnums.ItemRarity) -> int:
	return BASE_PRICES.get(rarity, 40)


## Get price for an item
static func get_item_price(item_id: String) -> int:
	var rarity := get_rarity(item_id)
	return get_rarity_price(rarity)


## Get item modifiers
static func get_modifiers(item_id: String) -> Array:
	var item = get_item(item_id)
	if item:
		return item.modifiers
	return []


## Get max stacks for an item (0 = unlimited)
static func get_max_stacks(item_id: String) -> int:
	var item = get_item(item_id)
	if item:
		return item.max_stacks
	return 0


## Check if item is at max stacks based on current counts
static func is_at_max_stacks(item_id: String, item_counts: Dictionary) -> bool:
	var max_stacks := get_max_stacks(item_id)
	if max_stacks == 0:
		return false # Unlimited stacking
	var current_count := item_counts.get(item_id, 0) as int
	return current_count >= max_stacks


## Get all item IDs that are not at max stacks
static func get_available_item_ids(item_counts: Dictionary) -> Array:
	var available: Array = []
	for item_id in get_all_item_ids():
		if not is_at_max_stacks(item_id, item_counts):
			available.append(item_id)
	return available


## Determines if an item's description should be displayed.
static func should_show_description(item_id: String) -> bool:
	var item = get_item(item_id)
	if not item:
		return false

	# Always show if it has a special effect logic
	if not item.special_effect.is_empty():
		return true

	# Always show if explicitly marked to be shown
	if item.always_show_description:
		return true

	# Check if it only has simple modifiers
	var modifiers: Array = item.modifiers

	# If no modifiers and no special effect, show description
	if modifiers.is_empty():
		return true

	# If it has more than 2 modifiers, show description
	if modifiers.size() > 2:
		return true

	# For common trade-offs with filters, check complexity
	for mod in modifiers:
		if mod.has("filter"):
			var filter: Dictionary = mod["filter"]
			if filter.size() > 1:
				return true

	return false


## Check if item has a special effect
static func has_special_effect(item_id: String) -> bool:
	var item = get_item(item_id)
	if item:
		return not item.special_effect.is_empty()
	return false


## Get special effect type
static func get_special_effect(item_id: String) -> String:
	var item = get_item(item_id)
	if item:
		return item.special_effect
	return ""


## Get all items of a specific rarity
static func get_items_by_rarity(rarity: GameEnums.ItemRarity) -> Array:
	# Use cached version if available
	if _items_by_rarity.has(rarity):
		return _items_by_rarity[rarity]

	var result: Array = []
	for item_id in get_all_item_ids():
		var item = get_item(item_id)
		if item and item.rarity == rarity:
			result.append(item_id)

	_items_by_rarity[rarity] = result
	return result


## Calculate effective rarity weights based on wave and luck
static func calculate_rarity_weights(wave: int, luck: float) -> Dictionary:
	var weights: Dictionary = {}
	var clamped_luck := clampf(luck, 0.0, GameConstants.PLAYER_MAX_LUCK)

	for rarity in GameConstants.RARITY_BASE_WEIGHTS.keys():
		var min_wave: int = GameConstants.RARITY_MIN_WAVE.get(rarity, 1)

		# Skip rarities not yet unlocked
		if wave < min_wave:
			weights[rarity] = 0.0
			continue

		var base_weight: float = GameConstants.RARITY_BASE_WEIGHTS[rarity]
		var luck_mult: float = GameConstants.LUCK_WEIGHT_MULTIPLIERS.get(rarity, 1.0)

		# Interpolate based on luck (0.0 = no effect, 1.0+ = full multiplier effect)
		var effective_luck := minf(clamped_luck, 1.0)
		var luck_factor := lerpf(1.0, luck_mult, effective_luck)

		# Extra luck bonus beyond 1.0
		if clamped_luck > 1.0:
			var extra_luck := clamped_luck - 1.0
			luck_factor *= (1.0 + extra_luck * (luck_mult - 1.0) * 0.5)

		# Wave progression bonus
		var waves_past_min := wave - min_wave
		var wave_bonus := 1.0 + GameConstants.RARITY_WAVE_BONUS_PER_WAVE * waves_past_min

		weights[rarity] = base_weight * luck_factor * wave_bonus

	return weights


## Get a weighted random item based on wave and luck
## Filters out items already in the shop (excluded_ids) and items at max stacks
static func get_weighted_random_item(wave: int, luck: float, item_counts: Dictionary, excluded_ids: Array) -> String:
	var rarity_weights := calculate_rarity_weights(wave, luck)

	# Build pool of available items per rarity
	var rarity_pools: Dictionary = {}
	var effective_weights: Dictionary = {}

	for rarity in rarity_weights.keys():
		var items := get_items_by_rarity(rarity)
		# Filter out excluded and max-stacked items
		var available: Array = []
		for item_id in items:
			if item_id not in excluded_ids and not is_at_max_stacks(item_id, item_counts):
				available.append(item_id)

		rarity_pools[rarity] = available
		effective_weights[rarity] = rarity_weights[rarity] if not available.is_empty() else 0.0

	# Calculate total weight
	var total_weight: float = 0.0
	for weight in effective_weights.values():
		total_weight += weight

	# No items available at all
	if total_weight <= 0.0:
		return ""

	# Roll for rarity
	var roll := randf() * total_weight
	var cumulative: float = 0.0
	var selected_rarity: GameEnums.ItemRarity = GameEnums.ItemRarity.COMMON

	for rarity in effective_weights.keys():
		cumulative += effective_weights[rarity]
		if roll <= cumulative:
			selected_rarity = rarity
			break

	# Pick random item from selected rarity pool
	var pool: Array = rarity_pools[selected_rarity]
	if pool.is_empty():
		return ""

	return pool[randi() % pool.size()]
