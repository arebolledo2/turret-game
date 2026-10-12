extends GutTest

## The 3D sound voices live in the root viewport, which is silent unless some camera is active in it.
## With the HUD the real camera renders from a sub-viewport, so the playfield adds an invisible anchor.

func test_hud_arena_keeps_an_active_camera_in_the_root_viewport() -> void:
	TestHelpers.reset_all_services()
	var world := ArenaWorld.new()
	add_child_autofree(world)
	assert_not_null(world.playfield, "the HUD playfield is present")
	var active := world.get_viewport().get_camera_3d()
	assert_not_null(active, "root viewport needs an active camera for 3D sound")
	assert_ne(active, world.camera, "the rendering camera lives in the playfield sub-viewport")
	assert_eq(active.cull_mask, 0, "the anchor renders nothing")
