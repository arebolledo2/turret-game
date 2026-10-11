extends GutTest

var world: ArenaWorld

func before_each() -> void:
	TestHelpers.reset_all_services()
	world = ArenaWorld.new()
	add_child_autofree(world)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)
	world.finish_wave()
	EconomyService.total_scrap = 1000

func test_locked_offer_and_price_survive_rerolls_and_next_wave() -> void:
	var held := EconomyService.current_shop_offers[1]
	var other := EconomyService.current_shop_offers[2]
	var price := held.price
	assert_true(world.shop.toggle_lock(1))
	assert_eq(EconomyService.total_scrap, 1000, "Locking is free")
	assert_true(world.shop.reroll())
	assert_same(EconomyService.current_shop_offers[1], held)
	assert_ne(EconomyService.current_shop_offers[2], other)
	assert_true(world.begin_next_wave())
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)
	world.finish_wave()
	assert_same(EconomyService.current_shop_offers[1], held)
	assert_eq(held.price, price)
	assert_true(held.locked)
	for i in EconomyService.current_shop_offers.size():
		if i != 1:
			assert_ne(EconomyService.current_shop_offers[i].asset_id, held.asset_id)

func test_all_locked_reroll_is_noop_and_unlock_reprices() -> void:
	for i in EconomyService.current_shop_offers.size():
		world.shop.toggle_lock(i)
	assert_false(world.shop.can_reroll())
	assert_false(world.shop.reroll())
	assert_eq(EconomyService.total_scrap, 1000)
	assert_eq(EconomyService.shop_reroll_count, 0)
	GameStateService.current_wave = 8
	var held := EconomyService.current_shop_offers[1]
	assert_true(world.shop.toggle_lock(1))
	assert_false(held.locked)
	assert_eq(held.price, world.shop.item_price(held.asset_id))
	assert_true(world.shop.can_reroll())

func test_purchase_does_not_reprice_locked_stock_and_restart_clears_locks() -> void:
	var held := EconomyService.current_shop_offers[0]
	var price := held.price
	world.shop.toggle_lock(0)
	GameStateService.current_wave = 8
	assert_true(world.shop.purchase(1))
	assert_eq(held.price, price)
	assert_true(world.shop.purchase(0))
	assert_true(held.sold)
	assert_false(held.locked)
	assert_false(world.shop.toggle_lock(0))
	world.shop.toggle_lock(2)
	world.start_run()
	assert_true(EconomyService.current_shop_offers.is_empty())

func test_controller_x_locks_focused_offer_without_purchasing() -> void:
	var shop: ShopScreen = world.hud.shop_screen
	shop.refresh()
	shop.offer_buttons[1].grab_focus()
	var offer := EconomyService.current_shop_offers[1]
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_X
	event.pressed = true
	Input.parse_input_event(event)
	await wait_process_frames(1)
	assert_true(offer.locked)
	assert_false(offer.sold)
	assert_eq(EconomyService.total_scrap, 1000)
	(shop.offer_buttons[1] as OfferCard).lock_button.pressed.emit()
	assert_false(offer.locked, "Mouse lock button also toggles")
