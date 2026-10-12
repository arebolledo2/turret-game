class_name LowHealthWarning
extends Control

## Edge-only danger cue; separate labels keep simultaneous warnings unambiguous.
var world: ArenaWorld
var hero_strength := 0.0
var core_strength := 0.0
var pulse_time := 0.0
var rim: ColorRect
var hero_label: Label
var core_label: Label

static func severity(health: float, maximum: float) -> float:
	if maximum <= 0.0 or health <= 0.0: return 0.0
	return clampf((.35 - health / maximum) / .20, 0.0, 1.0)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	rim = ColorRect.new()
	rim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform float hero = 0.0;
uniform float core = 0.0;
uniform float breath = 1.0;
void fragment() {
	vec2 p = abs(UV - vec2(0.5)) * 2.0;
	float edge = pow(max(p.x, p.y), 6.0);
	float h = hero * mix(1.0, 1.0 - smoothstep(0.3, 0.7, UV.x), step(0.01, core));
	float c = core * mix(1.0, smoothstep(0.3, 0.7, UV.x), step(0.01, hero));
	vec3 tint = (vec3(0.48, 0.015, 0.045) * h + vec3(0.48, 0.22, 0.015) * c) / max(h + c, 0.001);
	COLOR = vec4(tint, edge * max(h, c) * breath * 0.65);
}"""
	var material_instance := ShaderMaterial.new()
	material_instance.shader = shader
	rim.material = material_instance
	add_child(rim)
	hero_label = _warning_label("LOW HULL", Color("ff6980"), -230, -15)
	core_label = _warning_label("CORE IN DANGER", Color("ffc466"), 15, 260)
	visible = false

func _warning_label(text: String, tint: Color, left: float, right: float) -> Label:
	var label := Label.new()
	label.text = text
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	label.offset_left = left
	label.offset_right = right
	label.offset_top = -78
	label.offset_bottom = -38
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", tint)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, .9))
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func _process(delta: float) -> void:
	visible = is_instance_valid(world) and world.is_combat() and not world.paused
	if not visible:
		hero_strength = 0.0
		core_strength = 0.0
		return
	if world.playfield:
		rim.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		rim.position = world.playfield.rect.position
		rim.size = world.playfield.rect.size
	var hero_target := severity(world.player.health, world.player.max_health)
	var core_target := severity(world.core.health, world.core.max_health) if is_instance_valid(world.core) else 0.0
	hero_strength = move_toward(hero_strength, hero_target, delta * 2.0)
	core_strength = move_toward(core_strength, core_target, delta * 2.0)
	hero_label.visible = hero_target > 0.0
	core_label.visible = core_target > 0.0
	var reduced := FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION)
	if not reduced: pulse_time += delta
	var material_instance := rim.material as ShaderMaterial
	material_instance.set_shader_parameter("hero", hero_strength)
	material_instance.set_shader_parameter("core", core_strength)
	material_instance.set_shader_parameter("breath", 1.0 if reduced else .88 + .12 * sin(pulse_time * 2.4))
