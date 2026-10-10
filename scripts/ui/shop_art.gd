class_name ShopArt
extends RefCounted

static var cache: Dictionary = {}

static func item(id: String) -> Texture2D:
	return _texture("res://assets/ui/items/%s.svg" % id, UiIcons.item(id))

static func turret(id: String) -> Texture2D:
	return _texture("res://assets/ui/turrets/%s.png" % id, UiIcons.turret(id))

static func _texture(path: String, fallback: Texture2D) -> Texture2D:
	if not cache.has(path):
		cache[path] = load(path) if ResourceLoader.exists(path) else fallback
	return cache[path]
