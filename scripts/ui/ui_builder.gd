class_name UiBuilder
extends RefCounted

## Shared construction helpers for code-built screens (HUD, preparation, shop, menus, dev panel).

## A label added to `parent`. `wrap` word-wraps it; `fill` also lets it take the row's spare width.
static func label(parent: Node, text: String, size: int, color: Color = UiPalette.INK, wrap: bool = false, fill: bool = false) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	if wrap or fill:
		result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if fill:
		result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(result)
	return result

## A label with a dark outline, readable over the 3D scene.
static func outlined_label(parent: Node, text: String, size: int, color: Color = UiPalette.INK) -> Label:
	var result := label(parent, text, size, color)
	result.add_theme_color_override("font_outline_color", Color(0, 0, 0, .9))
	result.add_theme_constant_override("outline_size", 4)
	return result
