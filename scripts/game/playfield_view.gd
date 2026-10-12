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
	viewport.msaa_3d = Viewport.MSAA_2X
	add_child(viewport)
	world.camera.reparent(viewport)
	world.camera.current = true
	# 3D sound voices live in the root viewport, which needs an active camera to be audible and now has none
	# (the real camera renders from this sub-viewport). This one renders nothing; the listener on the hero sets the ears.
	var audio_anchor := Camera3D.new()
	audio_anchor.name = "AudioAnchor"
	audio_anchor.cull_mask = 0
	world.add_child(audio_anchor)
	audio_anchor.make_current()
	picture = TextureRect.new()
	picture.texture = viewport.get_texture()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(picture)
	get_viewport().size_changed.connect(refresh)
	refresh()

func refresh() -> void:
	var size := get_viewport().get_visible_rect().size
	rect = Rect2(0, TOP, size.x, maxf(1, size.y - TOP - BOTTOM))
	# Canvas stretch uses logical UI pixels; render 3D at the actual window density.
	var pixel_scale := get_viewport().get_final_transform().get_scale().abs()
	viewport.size = Vector2i((rect.size * pixel_scale).round().max(Vector2.ONE))
	picture.position = rect.position
	picture.size = rect.size
	world.camera_rig.refresh_aspect()

func to_screen(point: Vector3) -> Vector2:
	return rect.position + world.camera.unproject_position(point) * rect.size / Vector2(viewport.size)

func to_viewport(screen: Vector2) -> Vector2:
	return (screen - rect.position) * Vector2(viewport.size) / rect.size
