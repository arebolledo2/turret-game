class_name UiIcons
extends RefCounted

## Rasterises the SVG fragments in UiIconData once per name and hands out white textures; tint with
## `modulate` or a Button's icon colour overrides.
const GRID: float = 24.0
const RASTER_SIZE: int = 128
const WRAPPER: String = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='#fff' stroke-width='1.8' stroke-linecap='round' stroke-linejoin='round'>%s</svg>"

static var cache: Dictionary = {}

static func reset_cache() -> void:
	cache.clear()

static func has_icon(icon_name: String) -> bool:
	return UiIconData.PATHS.has(icon_name)

## Texture for a named icon; unknown names draw the "missing" box so a typo is visible, not silent.
static func get_icon(icon_name: String) -> Texture2D:
	var key := icon_name if has_icon(icon_name) else "missing"
	if cache.has(key):
		return cache[key]
	var image := Image.new()
	var error := image.load_svg_from_string(WRAPPER % UiIconData.PATHS[key], float(RASTER_SIZE) / GRID)
	if error != OK:
		push_warning("UiIcons: could not rasterise '%s'" % key)
	var texture := ImageTexture.create_from_image(image)
	cache[key] = texture
	return texture

## Full-colour attack family badge (UiIconData.FAMILIES); never tinted, so the shape and fill carry the family.
static func family_badge(family: String) -> Texture2D:
	var key := "family_" + family
	if cache.has(key):
		return cache[key]
	if not UiIconData.FAMILIES.has(family):
		return get_icon("missing")
	var row: Array = UiIconData.FAMILIES[family]
	var svg := "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke-linecap='round' stroke-linejoin='round'>" \
		+ "<g fill='%s' stroke='%s' stroke-width='1.5'>%s</g>" % [row[3], row[4], row[1]] \
		+ "<g transform='%s' stroke='#fff' stroke-width='2.8'>%s</g></svg>" % [row[5], row[2]]
	var image := Image.new()
	if image.load_svg_from_string(svg, float(RASTER_SIZE) / GRID) != OK:
		push_warning("UiIcons: could not rasterise family badge '%s'" % family)
	var texture := ImageTexture.create_from_image(image)
	cache[key] = texture
	return texture

static func family_name(family: String) -> String:
	return str(UiIconData.FAMILIES[family][0]) if UiIconData.FAMILIES.has(family) else family.capitalize()

## Families in display order.
static func sort_families(families: Array) -> Array[String]:
	var result: Array[String] = []
	for family in UiIconData.FAMILY_ORDER:
		if family in families:
			result.append(family)
	return result

static func turret(type_id: String) -> Texture2D:
	var key := "turret_" + type_id
	return get_icon(key if has_icon(key) else "turret")

static func item(item_id: String) -> Texture2D:
	var key := "item_" + item_id
	return get_icon(key if has_icon(key) else "module")
