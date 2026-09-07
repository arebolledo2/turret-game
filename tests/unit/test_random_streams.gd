extends GutTest

func before_each() -> void:
	TestHelpers.reset_all_services()

func test_cosmetics_do_not_change_gameplay_sequence() -> void:
	var expected := RandomNumberGenerator.new()
	expected.seed = 12345
	for i in range(100):
		GameRandom.cosmetic.randf()
	assert_eq(GameRandom.gameplay.randi(), expected.randi())

func test_economy_accepts_independent_rng() -> void:
	var service = autofree(load("res://scripts/autoload/economy_service.gd").new())
	service.rng = RandomNumberGenerator.new()
	service.rng.seed = 42
	var expected := RandomNumberGenerator.new()
	expected.seed = 42
	var expected_reward := 2 if expected.randf() < 0.5 else 1
	assert_eq(service.add_scrap_probabilistic(1, 1.5), expected_reward)

func test_item_generation_replays_with_injected_rng() -> void:
	var first := RandomNumberGenerator.new()
	var second := RandomNumberGenerator.new()
	first.seed = 72
	second.seed = 72
	for i in range(20):
		var item := ItemRegistry.get_weighted_random_item(5, 0.0, {}, [], first)
		GameRandom.cosmetic.randf()
		assert_eq(item, ItemRegistry.get_weighted_random_item(5, 0.0, {}, [], second))
