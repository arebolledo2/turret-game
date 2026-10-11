class_name ShopArt
extends RefCounted

static var cache: Dictionary = {}

static func item(id: String) -> Texture2D:
	return _texture("res://assets/ui/items/%s.svg" % id, UiIcons.item(id))

static func turret(id: String, branch: String = "", stage: int = 0) -> Texture2D:
	var key := turret_portrait_key(id, branch, stage)
	return _texture("res://assets/ui/turrets/%s.png" % key, UiIcons.turret(id))

static func turret_portrait_key(id: String, branch: String = "", stage: int = 0) -> String:
	return "%s_%d" % [branch, stage] if stage > 0 and not branch.is_empty() else id

static func _texture(path: String, fallback: Texture2D) -> Texture2D:
	if not cache.has(path):
		cache[path] = load(path) if ResourceLoader.exists(path) else fallback
	return cache[path]
