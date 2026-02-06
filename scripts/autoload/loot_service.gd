extends Node

## Loot Service
## Manages items found during waves from tech drop destruction
## Items are reviewed at wave end before shop opens

# Items found during the current wave
var found_items: Array[String] = []


func reset_state() -> void:
	"""Reset loot state for new game."""
	found_items.clear()


func add_found_item(item_id: String) -> void:
	"""Add an item to the found items list."""
	found_items.append(item_id)


func get_found_items() -> Array[String]:
	"""Get copy of found items array."""
	return found_items.duplicate()


func clear_found_items() -> void:
	"""Clear found items after review is complete."""
	found_items.clear()


func has_pending_loot() -> bool:
	"""Check if there are items waiting to be reviewed."""
	return not found_items.is_empty()


func roll_for_item_drop(wave: int) -> String:
	"""Roll for an item drop based on luck. Returns item_id or empty string."""
	if randf() > GameConstants.TECH_DROP_ITEM_DROP_CHANCE:
		return ""
	
	# Use same weighted random system as shop
	var item_id := ItemRegistry.get_weighted_random_item(
		wave,
		PlayerStatsService.get_player_luck(),
		ItemTrackingService.item_counts,
		[] # No exclusions for loot drops
	)
	
	return item_id
