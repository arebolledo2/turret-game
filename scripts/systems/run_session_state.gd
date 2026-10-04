class_name RunSessionState
extends RefCounted

## Mutable state owned by one game run. Services bind to it at the composition root.
## Standalone service instances start with private state for unit tests.
var current_wave: int = 0
var total_kills: int = 0
var lifetime_scrap: int = 0
var time_survived: float = 0.0
var is_game_active: bool = false
var turrets_spawned: int = 0
var total_scrap: int = GameConstants.STARTING_SCRAP
var shop_reroll_count: int = 0
var current_shop_offers: Array[ShopOffer] = []
var turrets_purchased: int = 0
var player_luck: float = GameConstants.PLAYER_BASE_LUCK
var turret_counts: Dictionary = {}
var collected_items: Array[String] = []
var item_counts: Dictionary = {}
var total_research_points: int = 0
var unlocked_tech_ids: Array[String] = []
var tech_unlock_counts: Dictionary = {}
var modifiers: ModifierSystem = ModifierSystem.new()
var phase: int = 0
