extends Node

## Reproducible shop art/layout review, without changing player saves.
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.test-results"))
	var world := ArenaWorld.new()
	world.run_config = RunConfig.slice()
	world.run_config.mode = RunConfig.MODE_CORE
	add_child(world)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	for type_id: String in ["normal", "normal", "normal", "shock", "melee"]:
		world.add_turret(Vector3.ZERO, type_id)
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)
	GameStateService.current_wave = 4
	world.finish_wave()
	EconomyService.total_scrap = 118
	EconomyService.current_shop_offers.assign([
		ShopOffer.new("turret", "normal", 43), ShopOffer.new("item", "polished_barrels", 18),
		ShopOffer.new("item", "blast_charges", 18), ShopOffer.new("item", "capacitor_bank", 18)])
	if "--rare" in OS.get_cmdline_user_args():
		EconomyService.current_shop_offers.assign([ShopOffer.new("item", "hardpoint", 18), ShopOffer.new("item", "reactor_overload", 40), ShopOffer.new("item", "mono_type_mastery", 40), ShopOffer.new("item", "elemental_conduit", 60)])
		for id: String in ["polished_barrels", "reinforced_hull", "quick_loader", "scrap_magnet", "rapid_coolant", "dense_rounds", "blast_charges", "capacitor_bank"]:
			world.shop.apply_item(id)
	world.hud._process(0)
	world.hud.shop_screen.offer_buttons[1].grab_focus()
	if "--turrets-ready" in OS.get_cmdline_user_args():
		world.turrets[0].progression.award(1500)
	if "--turrets" in OS.get_cmdline_user_args() or "--turrets-ready" in OS.get_cmdline_user_args():
		world.hud.shop_screen.switch_tab(1)
	if "--evolution" in OS.get_cmdline_user_args():
		world.session.state.turret_progression_enabled = true
		world.turrets[0].progression.award(1500)
		world.hud.shop_screen.switch_tab(1)
		world.hud.shop_screen.turret_inspector.evolution_preview.show_form(world.turrets[0], "machine_gun")
	if "--reminder" in OS.get_cmdline_user_args():
		world.session.state.turret_progression_enabled = true
		world.turrets[0].progression.award(1500)
		world.hud.shop_screen._request_deploy()
	for i in range(30):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var output := "res://.test-results/shop-%dx%d%s.png" % [get_viewport().size.x, get_viewport().size.y, "-rare" if "--rare" in OS.get_cmdline_user_args() else ""]
	get_viewport().get_texture().get_image().save_png(output)
	print("SHOP_CAPTURE ", ProjectSettings.globalize_path(output))
	get_tree().quit()
