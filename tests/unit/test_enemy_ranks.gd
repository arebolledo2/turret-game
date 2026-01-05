extends "res://addons/gut/test.gd"

var EnemyScene = load("res://scenes/enemy.tscn")
var _enemy: Node2D

func before_each():
	_enemy = EnemyScene.instantiate()
	add_child(_enemy)

func after_each():
	_enemy.free()

func test_normal_rank_initialization():
	_enemy.initialize(1, "basic", GameEnums.EnemyRank.NORMAL)
	
	var base_stats = EnemyRegistry.get_base_stats("basic")
	assert_eq(_enemy.enemy_rank, GameEnums.EnemyRank.NORMAL)
	assert_almost_eq(_enemy.max_health, base_stats["health"] * DifficultyService.get_difficulty_config()["enemy_health_mult"], 0.1)
	assert_almost_eq(_enemy.base_scale, base_stats["scale"], 0.1)

func test_lieutenant_rank_initialization():
	_enemy.initialize(1, "basic", GameEnums.EnemyRank.LIEUTENANT)
	
	var base_stats = EnemyRegistry.get_base_stats("basic")
	var hp_mult = DifficultyService.get_difficulty_config()["enemy_health_mult"]
	var expected_hp = base_stats["health"] * hp_mult * GameConstants.ENEMY_RANK_LT_HP_MULT
	
	assert_eq(_enemy.enemy_rank, GameEnums.EnemyRank.LIEUTENANT)
	assert_almost_eq(_enemy.max_health, expected_hp, 0.1)
	assert_almost_eq(_enemy.base_scale, base_stats["scale"] * GameConstants.ENEMY_RANK_LT_SCALE_MULT, 0.1)

func test_captain_rank_initialization():
	_enemy.initialize(1, "basic", GameEnums.EnemyRank.CAPTAIN)
	
	var base_stats = EnemyRegistry.get_base_stats("basic")
	var hp_mult = DifficultyService.get_difficulty_config()["enemy_health_mult"]
	var expected_hp = base_stats["health"] * hp_mult * GameConstants.ENEMY_RANK_CAPT_HP_MULT
	
	assert_eq(_enemy.enemy_rank, GameEnums.EnemyRank.CAPTAIN)
	assert_almost_eq(_enemy.max_health, expected_hp, 0.1)
	assert_almost_eq(_enemy.base_scale, base_stats["scale"] * GameConstants.ENEMY_RANK_CAPT_SCALE_MULT, 0.1)

func test_rank_scrap_value_unchanged():
	# With new scrap system, scrap_value stays at 1 for all ranks
	# (LT/CPT scatter multiple pickups via drop counts instead)
	_enemy.initialize(1, "basic", GameEnums.EnemyRank.NORMAL)
	assert_eq(_enemy.scrap_value, 1, "Normal enemy scrap_value should be 1")

	var lt_enemy = EnemyScene.instantiate()
	add_child(lt_enemy)
	lt_enemy.initialize(1, "basic", GameEnums.EnemyRank.LIEUTENANT)
	assert_eq(lt_enemy.scrap_value, 1, "Lieutenant scrap_value should stay at 1 (drops multiple pickups)")
	lt_enemy.free()

	var capt_enemy = EnemyScene.instantiate()
	add_child(capt_enemy)
	capt_enemy.initialize(1, "basic", GameEnums.EnemyRank.CAPTAIN)
	assert_eq(capt_enemy.scrap_value, 1, "Captain scrap_value should stay at 1 (drops multiple pickups)")
	capt_enemy.free()

func test_captain_guaranteed_legendary():
	# Ensure wave is high enough for legendary items
	GameStateService.current_wave = 10
	_enemy.initialize(10, "basic", GameEnums.EnemyRank.CAPTAIN)
	
	# Clear found items
	LootService.clear_found_items()
	
	# Killing the enemy should trigger _handle_rank_loot
	# Note: item_pickup calls LootService.add_found_item on ready? 
	# Let's check item_pickup.gd
	
	_enemy.die()
	
	# Wait a frame for deferred calls? No, item_pickup is added to scene tree.
	# But LootService doesn't track item IDs until they are "collected"?
	# Wait, LootService.add_found_item is called when a pickup is initialized in some games, 
	# but here it might be when picked up.
	
	# Actually, let's just check if an item_pickup node exists in the scene
	var pickups = get_tree().get_nodes_in_group("item_pickups")
	assert_gt(pickups.size(), 0, "Should have spawned an item pickup")
	
	var found_legendary = false
	for pickup in pickups:
		var item_id = pickup.item_id
		var rarity = ItemRegistry.get_rarity(item_id)
		if rarity == GameEnums.ItemRarity.LEGENDARY:
			found_legendary = true
			break
	
	assert_true(found_legendary, "Captain should drop a legendary item")
	
	# Cleanup pickups
	for pickup in pickups:
		pickup.free()

func test_lieutenant_loot_roll():
	# Lieutenants have a 30% chance. 
	GameStateService.current_wave = 5
	_enemy.initialize(5, "basic", GameEnums.EnemyRank.LIEUTENANT)
	
	# Clear existing pickups
	var old_pickups = get_tree().get_nodes_in_group("item_pickups")
	for p in old_pickups: p.free()
	
	# We'll run a few times or just check if it CAN drop
	var dropped = false
	for i in range(20):
		var lt = EnemyScene.instantiate()
		add_child(lt)
		lt.initialize(5, "basic", GameEnums.EnemyRank.LIEUTENANT)
		lt.die()
		
		var pickups = get_tree().get_nodes_in_group("item_pickups")
		if pickups.size() > 0:
			dropped = true
			for p in pickups: p.free()
			break
	
	assert_true(dropped, "Lieutenant should have dropped an item at least once in 20 tries (30% chance)")
