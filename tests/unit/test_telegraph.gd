extends GutTest

var parent: Node3D

func before_each() -> void:
	parent = autofree(Node3D.new())
	add_child(parent)

func _param(node: MeshInstance3D, name: String) -> Variant:
	return (node.material_override as ShaderMaterial).get_shader_parameter(name)

func test_telegraphs_share_one_mesh_and_start_hidden() -> void:
	var first := Telegraph.create(parent, Telegraph.Shape.LINE, Telegraph.CHARGE)
	var second := Telegraph.create(parent, Telegraph.Shape.CIRCLE, Telegraph.BLAST)
	assert_same(first.mesh, second.mesh)
	assert_false(first.visible)
	assert_true(first.top_level)

func test_line_covers_the_footprint_from_origin_along_heading() -> void:
	var node := Telegraph.create(parent, Telegraph.Shape.LINE, Telegraph.SHOT)
	Telegraph.place_line(node, Vector3(1, 0, 1), Vector3.RIGHT, 4.0, .6)
	assert_true(node.visible)
	assert_almost_eq(node.global_position.x, 3.0, .001)
	assert_almost_eq(node.global_position.z, 1.0, .001)
	assert_eq(_param(node, "extent"), Vector2(.6, 4.0))

func test_thin_lines_are_widened_to_a_readable_gauge() -> void:
	var node := Telegraph.create(parent, Telegraph.Shape.LINE, Telegraph.SHOT)
	Telegraph.place_line(node, Vector3.ZERO, Vector3.FORWARD, 3.0, .025)
	assert_eq(_param(node, "extent"), Vector2(Telegraph.MIN_LINE_WIDTH, 3.0))

func test_circle_and_rear_sector_placement() -> void:
	var circle := Telegraph.create(parent, Telegraph.Shape.CIRCLE, Telegraph.BLAST)
	Telegraph.place_circle(circle, Vector3(2, 0, -1), 1.5)
	assert_eq(circle.scale, Vector3(3, 1, 3))
	var front := Telegraph.create(parent, Telegraph.Shape.SECTOR, Telegraph.SWEEP)
	var rear := Telegraph.create(parent, Telegraph.Shape.SECTOR, Telegraph.SWEEP)
	Telegraph.place_sector(front, Vector3.ZERO, Vector3.FORWARD, 3.0, .5)
	Telegraph.place_sector(rear, Vector3.ZERO, Vector3.FORWARD, 3.0, .5, true)
	assert_almost_eq(absf(angle_difference(front.global_rotation.y, rear.global_rotation.y)), PI, .001)
	assert_eq(_param(front, "half_angle"), .5)

func test_progress_is_clamped_to_the_gauge_range() -> void:
	var node := Telegraph.create(parent, Telegraph.Shape.LINE, Telegraph.CHARGE)
	Telegraph.set_progress(node, 1.7)
	assert_eq(_param(node, "progress"), 1.0)
	Telegraph.set_progress(node, -.2)
	assert_eq(_param(node, "progress"), 0.0)
