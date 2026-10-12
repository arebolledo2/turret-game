class_name PlayfieldView
extends CanvasLayer

## Reserve only a slim status header; the minimap and hints overlay the full-height playfield.
const TOP := 76.0
const BOTTOM := 0.0
var world: ArenaWorld
var viewport: SubViewport
var picture: TextureRect
var rect := Rect2()

func _ready() -> void:
	layer = -1
	var background := ColorRect.new()
	background.color = Color("06151d")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	viewport = SubViewport.new()
	viewport.world_3d = world.get_world_3d()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = get_viewport().msaa_3d
	add_child(viewport)
	world.camera.reparent(viewport)
	world.camera.current = true
	picture = TextureRect.new()
	picture.texture = viewport.get_texture()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(picture)
	get_viewport().size_changed.connect(refresh)
	refresh()

func refresh() -> void:
	var size := get_viewport().get_visible_rect().size
	rect = Rect2(0, TOP, size.x, maxf(1, size.y - TOP - BOTTOM))
	viewport.size = Vector2i(rect.size)
	picture.position = rect.position
	picture.size = rect.size
	world.camera_rig.refresh_aspect()

func to_screen(point: Vector3) -> Vector2:
	return rect.position + world.camera.unproject_position(point)
