extends GutTest

func before_each() -> void:
	TestHelpers.reset_all_services()

func test_numbers_are_positioned_in_world_space_and_can_be_disabled() -> void:
	var world := Node2D.new()
	add_child_autofree(world)
	world.position = Vector2(500, 500)
	var presenter := DamageNumberPresenter.new()
	presenter.world_parent = world
	add_child_autofree(presenter)
	var number := presenter.spawn(Vector2(100, 100))
	assert_almost_eq(number.global_position.y, 80.0, 0.01)
	assert_between(number.global_position.x, 90.0, 110.0)
	presenter.enabled = func() -> bool: return false
	assert_null(presenter.spawn(Vector2.ZERO))

func test_menu_manager_owns_overlay_visibility() -> void:
	var overlay := Control.new()
	add_child_autofree(overlay)
	var menus := HUDMenuManager.new()
	add_child_autofree(menus)
	menus.gameplay_overlays.append(overlay)
	menus.pause()
	assert_false(overlay.visible)
	menus.resume()
	assert_true(overlay.visible)
	assert_false(get_tree().paused)
