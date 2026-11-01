class_name ArenaVignette
extends CanvasLayer

## Edge darkening over the 3D view. Draw order: `PlayfieldView` (the 3D picture) is layer -1, this is 0 and `GameHud` keeps the
## default layer 1, so the vignette dims the arena and never the HUD. (Layer -1 would tie with the picture and lose or win by tree
## order.) It is a full-screen `Control` that ignores the mouse, so it can never swallow a click.
const DRAW_LAYER: int = 0
const SHADER: Shader = preload("res://assets/shaders/vignette.gdshader")

var overlay: ColorRect
var material: ShaderMaterial

func _init() -> void:
	name = "Vignette"
	layer = DRAW_LAYER
	material = ShaderMaterial.new()
	material.shader = SHADER
	overlay = ColorRect.new()
	overlay.name = "Overlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.focus_mode = Control.FOCUS_NONE
	overlay.material = material
	add_child(overlay)
