extends GutTest

var world: ArenaWorld

func before_each() -> void:
	TestHelpers.reset_all_services()
	world = ArenaWorld.new()
	world.run_config = RunConfig.slice()
	world.auto_start = false
	world.show_hud = false
	add_child_autofree(world)
	world.start_run()
	world.set_physics_process(false)
	world.player.set_physics_process(false)

func _offer(kind: String, id: String) -> ShopOffer:
	return ShopOffer.new(kind, id, 1)

func _same(a: float, b: float) -> bool:
	return absf(a - b) < .0001

func test_build_data_lists_the_starting_turret_and_player_stats() -> void:
	var data := ShopViewData.build_data(world)
	assert_gt(data["turrets"].size(), 0)
	var first: Dictionary = data["turrets"][0]
	assert_gt(first["damage"], 0.0)
	assert_gt(first["range"], 0.0)
	assert_eq(data["max_hull"], world.player.max_health)
	assert_gt(data["dps"], 0.0)
	assert_true(data["items"].is_empty())

func test_turret_preview_adds_one_and_raises_dps() -> void:
	var now := ShopViewData.build_data(world)
	var after := ShopViewData.preview(world, _offer("turret", "plasma"))
	var plasma: Array = after["turrets"].filter(func(t: Dictionary) -> bool: return t["id"] == "plasma")
	assert_eq(plasma.size(), 1)
	assert_eq(plasma[0]["count"], int(TurretStatsService.turret_counts.get("plasma", 0)) + 1)
	assert_gt(after["dps"], now["dps"])

func test_item_preview_matches_what_buying_the_item_really_does() -> void:
	var checked := 0
	for item_id: String in ArenaShop.ITEMS:
		if ItemRegistry.get_item_dict(item_id).has("special_effect") or ItemRegistry.get_modifiers(item_id).is_empty():
			continue
		var predicted := ShopViewData.preview(world, _offer("item", item_id))
		world.shop.apply_item(item_id)
		var actual := ShopViewData.build_data(world)
		assert_true(_same(predicted["max_hull"], actual["max_hull"]), "%s max hull" % item_id)
		assert_true(_same(predicted["hull"], actual["hull"]), "%s hull" % item_id)
		assert_true(_same(predicted["speed"], actual["speed"]), "%s speed" % item_id)
		assert_true(_same(predicted["pickup"], actual["pickup"]), "%s pickup" % item_id)
		assert_true(_same(predicted["dps"], actual["dps"]), "%s dps" % item_id)
		for index in actual["turrets"].size():
			var want: Dictionary = actual["turrets"][index]
			var got: Dictionary = predicted["turrets"][index]
			for key in ["damage", "fire_rate", "range"]:
				assert_true(_same(got[key], want[key]), "%s %s of %s" % [item_id, key, want["id"]])
		assert_eq(predicted["items"].size(), actual["items"].size(), "%s item list" % item_id)
		checked += 1
	assert_gt(checked, 10, "most of the pool is modifier-based")

func test_preview_leaves_live_state_untouched() -> void:
	var modifiers_before := ModifierService.active_modifiers.size()
	var counts_before := ItemTrackingService.item_counts.duplicate()
	var turrets_before := TurretStatsService.turret_counts.duplicate()
	ShopViewData.preview(world, _offer("item", "reinforced_hull"))
	ShopViewData.preview(world, _offer("turret", "shock"))
	assert_eq(ModifierService.active_modifiers.size(), modifiers_before)
	assert_eq(ItemTrackingService.item_counts, counts_before)
	assert_eq(TurretStatsService.turret_counts, turrets_before)

func test_shock_chips_include_the_slow() -> void:
	var chips := ShopViewData.offer_chips(_offer("turret", "shock"))
	var slow := chips.filter(func(c: Dictionary) -> bool: return c["stat"] == "slow")
	assert_eq(slow.size(), 1)
	assert_eq(slow[0]["text"], "25%")

func test_item_chips_carry_sign_and_good_or_bad_tone() -> void:
	var chips := ShopViewData.offer_chips(_offer("item", "reinforced_hull"))
	var hull := chips.filter(func(c: Dictionary) -> bool: return c["stat"] == "hull")
	assert_eq(hull[0]["text"], "+4")
	assert_eq(hull[0]["tone"], 1)
	var any_bad := false
	for item_id: String in ArenaShop.ITEMS:
		for chip in ShopViewData.offer_chips(_offer("item", item_id)):
			any_bad = any_bad or chip["tone"] < 0
	assert_true(any_bad, "trade-off items show a bad chip")

func test_every_item_has_chips_or_a_description_and_known_icons() -> void:
	for item_id: String in ArenaShop.ITEMS:
		var offer := _offer("item", item_id)
		var chips := ShopViewData.offer_chips(offer)
		assert_true(not chips.is_empty() or not ArenaShop.offer_description(offer).is_empty(), "%s has something to show" % item_id)
		for chip in chips:
			assert_true(UiIcons.has_icon(chip["icon"]), "%s chip icon %s" % [item_id, chip["icon"]])

func test_every_modifier_stat_has_a_ui_mapping() -> void:
	for item_id: String in ArenaShop.ITEMS:
		for modifier: Dictionary in ItemRegistry.get_modifiers(item_id):
			assert_true(ShopViewData.STAT_UI.has(modifier["stat"]), "%s uses unmapped stat %s" % [item_id, modifier["stat"]])
