class_name BuildPanel
extends VBoxContainer

## "Your build" as an icon-headed turret table, four stat tiles and a module strip. Pass a `preview`
## (what the build becomes if the focused offer is bought) and changed values turn green or red.
const SLOTS: int = 12
const EPSILON: float = .0001

var shown_key: int = 0

func _init() -> void:
	add_theme_constant_override("separation", 22)

func set_data(data: Dictionary, preview: Dictionary = {}) -> void:
	var key := [data, preview].hash()
	if key == shown_key:
		return
	shown_key = key
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var after: Dictionary = preview if not preview.is_empty() else data
	_build_turrets(data, after)
	_build_stats(data, after)
	_build_modules(data, after)

func _section(title: String, count_text: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	var row := HBoxContainer.new()
	box.add_child(row)
	var caption := Label.new()
	caption.text = title.to_upper()
	caption.add_theme_font_size_override("font_size", 17)
	caption.add_theme_color_override("font_color", UiPalette.TEAL)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(caption)
	var count := Label.new()
	count.text = count_text
	count.theme_type_variation = &"Numeral"
	count.add_theme_font_size_override("font_size", 18)
	count.add_theme_color_override("font_color", UiPalette.MUTED)
	row.add_child(count)
	return box

func _icon(icon_name: String, tint: Color, size: float) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = UiIcons.get_icon(icon_name)
	rect.modulate = tint
	rect.custom_minimum_size = Vector2(size, size)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return rect

func _change_color(now: float, next: float) -> Color:
	if absf(next - now) <= EPSILON:
		return UiPalette.INK
	return UiPalette.GOOD if next > now else UiPalette.BAD

## Number plus an up/down arrow when it differs from the current build.
func _value(text: String, now: float, next: float, size: int = 26) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 3)
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"Numeral"
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", _change_color(now, next))
	row.add_child(label)
	if absf(next - now) > EPSILON:
		row.add_child(_icon("up" if next > now else "down", _change_color(now, next), 16.0))
	return row

func _build_turrets(data: Dictionary, after: Dictionary) -> void:
	var total := 0
	for turret: Dictionary in after["turrets"]:
		total += int(turret["count"])
	var box := _section("Turrets", str(total))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	grid.add_child(Control.new())
	grid.add_child(Control.new())
	for header: Array in [["damage", "dmg"], ["rate", "rate"], ["range", "range"]]:
		var icon := _icon(header[0], UiPalette.stat_color(header[1]), 26.0)
		icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(icon)
	var before: Dictionary = {}
	for turret: Dictionary in data["turrets"]:
		before[turret["id"]] = turret
	for turret: Dictionary in after["turrets"]:
		var was: Dictionary = before.get(turret["id"], {"count": 0, "damage": turret["damage"], "fire_rate": turret["fire_rate"],
			"rotation_rate": turret["rotation_rate"], "range": turret["range"]})
		var tile := PanelContainer.new()
		tile.add_theme_stylebox_override("panel", ChamferStyle.make(Color("0f2a33"), UiPalette.LINE, 8.0, 6.0, 6.0))
		tile.add_child(_icon("turret_" + str(turret["id"]) if UiIcons.has_icon("turret_" + str(turret["id"])) else "turret", UiPalette.TEAL_HI, 34.0))
		grid.add_child(tile)
		grid.add_child(_value("×%d" % turret["count"], float(was["count"]), float(turret["count"])))
		grid.add_child(_value("%.1f" % turret["damage"], float(was["damage"]), float(turret["damage"])))
		if float(turret["fire_rate"]) > 0.0:
			grid.add_child(_value("%.2f" % turret["fire_rate"], float(was["fire_rate"]), float(turret["fire_rate"])))
		else:
			grid.add_child(_value("%.0f°" % turret["rotation_rate"], float(was["rotation_rate"]), float(turret["rotation_rate"])))
		grid.add_child(_value("%.2fm" % turret["range"], float(was["range"]), float(turret["range"])))

func _build_stats(data: Dictionary, after: Dictionary) -> void:
	var box := _section("Stats", "")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	var tiles: Array = [
		["hull", "hull", "Hull", "%d/%d" % [ceili(after["hull"]), ceili(after["max_hull"])], float(data["max_hull"]), float(after["max_hull"])],
		["speed", "speed", "Move m/s", "%.2f" % after["speed"], float(data["speed"]), float(after["speed"])],
		["pickup", "pickup", "Pickup m", "%.2f" % after["pickup"], float(data["pickup"]), float(after["pickup"])],
	]
	for entry: Array in tiles:
		var tile := StatTile.new().setup(entry[0], entry[1], entry[2], entry[3])
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var direction := 0 if absf(entry[5] - entry[4]) <= EPSILON else (1 if entry[5] > entry[4] else -1)
		tile.set_value(entry[3], _change_color(entry[4], entry[5]))
		tile.set_delta(direction)
		grid.add_child(tile)

func _build_modules(data: Dictionary, after: Dictionary) -> void:
	var owned: Dictionary = {}
	for item: Dictionary in data["items"]:
		owned[item["id"]] = int(item["count"])
	var total := 0
	for item: Dictionary in after["items"]:
		total += int(item["count"])
	var box := _section("Modules", str(total))
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	var shown := 0
	for item: Dictionary in after["items"]:
		if shown >= SLOTS:
			break
		var had := int(owned.get(item["id"], 0))
		grid.add_child(_slot(str(item["id"]), int(item["count"]), had))
		shown += 1
	while shown < SLOTS:
		grid.add_child(_slot("", 0, 0))
		shown += 1

func _slot(item_id: String, count: int, had: int) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(58, 58)
	var is_new := count > 0 and had == 0
	var edge := UiPalette.TEAL_HI if is_new else (UiPalette.LINE if count > 0 else Color(UiPalette.LINE, .55))
	var fill := Color("0a1d26") if count > 0 else Color(0, 0, 0, 0)
	slot.add_theme_stylebox_override("panel", ChamferStyle.make(fill, edge, 7.0, 6.0, 6.0))
	if count > 0:
		var overlay := Control.new()
		slot.add_child(overlay)
		var icon := _icon("module", UiPalette.stat_color("slow"), 36.0)
		icon.texture = ShopArt.item(item_id)
		icon.modulate = Color.WHITE
		overlay.add_child(icon)
		icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		var label := Label.new()
		label.text = "×%d" % count
		label.theme_type_variation = &"Numeral"
		label.add_theme_font_size_override("font_size", 17)
		label.add_theme_color_override("font_color", UiPalette.GOOD if count > had and had > 0 else UiPalette.INK)
		overlay.add_child(label)
		label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	return slot
