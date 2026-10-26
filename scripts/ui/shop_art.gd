class_name ShopArt
extends RefCounted

static var cache: Dictionary = {}

static func item(id: String) -> Texture2D:
	return _texture("res://assets/ui/items/%s.svg" % id, UiIcons.item(id))

## Portrait for a base turret, or for one of its evolved forms when `form_id` is given.
static func turret(id: String, form_id: String = "") -> Texture2D:
	var key := turret_portrait_key(id, form_id)
	return _texture("res://assets/ui/turrets/%s.png" % key, UiIcons.turret(id))

## Portraits are named by form id (`assets/ui/turrets/<form_id>.png`); no form falls back to the base id.
static func turret_portrait_key(id: String, form_id: String = "") -> String:
	return form_id if not form_id.is_empty() else id

static func _texture(path: String, fallback: Texture2D) -> Texture2D:
	if not cache.has(path):
		cache[path] = load(path) if ResourceLoader.exists(path) else fallback
	return cache[path]
