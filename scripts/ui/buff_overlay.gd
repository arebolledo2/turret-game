class_name BuffOverlay
extends CanvasLayer

## Screen-sized status chips anchored to world actors; no permanent combat clutter.
var world: ArenaWorld
var panels: Dictionary = {}

func _ready() -> void:
	layer = 8

func _process(_delta: float) -> void:
	var enabled := world.show_hud and world.is_combat() and is_instance_valid(world.camera)
	for panel: HBoxContainer in panels.values():
		panel.visible = false
	if not enabled:
		return
	var actors: Array[Node3D] = []
	if is_instance_valid(world.player):
		actors.append(world.player)
	for turret in world.turrets:
		actors.append(turret)
	var live: Array[int] = []
	for actor in actors:
		var source: int = actor.turret_id if actor is TurretActor else 0
		live.append(source)
		var near := actor == world.player or actor.position.distance_to(world.player.position) < TurretPlacement.PICKUP_RANGE
		if not (near or world.show_ranges):
			continue
		var entries := world.item_effects.visible_buffs(source)
		if entries.is_empty():
			continue
		var anchor := actor.get_global_transform_interpolated().origin + Vector3(0, 1.6, 0)
		if world.camera.is_position_behind(anchor):
			continue
		if not panels.has(source):
			var panel := HBoxContainer.new()
			panel.add_theme_constant_override("separation", 4)
			add_child(panel)
			panels[source] = panel
		var row: HBoxContainer = panels[source]
		var signature := ""
		for entry in entries:
			signature += str(entry.id) + ";"
		if str(row.get_meta("signature", "")) != signature:
			for child in row.get_children():
				row.remove_child(child)
				child.queue_free()
			for entry in entries:
				row.add_child(_chip(str(entry.id)))
			row.set_meta("signature", signature)
		for index in entries.size():
			var chip := row.get_child(index)
			if entries[index].has("tooltip"):
				chip.tooltip_text = entries[index].tooltip
			chip.get_node("Stacks").text = str(entries[index].stacks) if int(entries[index].stacks) > 1 else ""
			chip.get_node("Timer/Fill").size.x = 32.0 * clampf(float(entries[index].fraction), 0.0, 1.0)
		row.visible = true
		row.position = world.camera.unproject_position(anchor) - Vector2(float(entries.size()) * 42.0 * .5, 0)
	for source in panels.keys():
		if not live.has(source):
			panels[source].queue_free()
			panels.erase(source)

func _chip(id: String) -> Panel:
	var chip := Panel.new()
	chip.custom_minimum_size = Vector2(38, 42)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("091e29")
	style.border_color = Color("63ddc3")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	chip.add_theme_stylebox_override("panel", style)
	var item := ItemRegistry.get_item(id)
	chip.tooltip_text = item.name + "\n" + item.description if item else id.capitalize()
	var icon := TextureRect.new()
	icon.texture = load("res://assets/ui/items/%s.svg" % id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = Vector2(2, 1)
	icon.size = Vector2(34, 34)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(icon)
	var count := Label.new()
	count.name = "Stacks"
	count.position = Vector2(24, 15)
	count.add_theme_font_size_override("font_size", 16)
	count.add_theme_color_override("font_color", Color.WHITE)
	count.add_theme_color_override("font_outline_color", Color.BLACK)
	count.add_theme_constant_override("outline_size", 5)
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(count)
	var timer := ColorRect.new()
	timer.name = "Timer"
	timer.position = Vector2(3, 36)
	timer.size = Vector2(32, 3)
	timer.color = Color("1b404a")
	timer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(timer)
	var fill := ColorRect.new()
	fill.name = "Fill"
	fill.size = Vector2(32, 3)
	fill.color = Color("63ddc3")
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timer.add_child(fill)
	return chip
