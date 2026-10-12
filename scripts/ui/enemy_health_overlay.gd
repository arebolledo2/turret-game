class_name EnemyHealthOverlay
extends Control

## Screen-space health presentation: readable at every world zoom, no floating box meshes.
var world: ArenaWorld
var trails: Dictionary = {}
var face: Font

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	face = preload("res://assets/fonts/BarlowCondensed-SemiBold.ttf")

func _process(delta: float) -> void:
	if not is_instance_valid(world):
		return
	var alive := {}
	for actor in world.enemies:
		if not is_instance_valid(actor) or actor.dead or not (actor.stationary or EnemyEcology.is_boss(actor.enemy_type)):
			continue
		var id := actor.get_instance_id()
		alive[id] = true
		var fraction := clampf(actor.health / maxf(actor.max_health, .001), 0.0, 1.0)
		var previous := float(trails.get(id, fraction))
		trails[id] = fraction if FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION) else move_toward(previous, fraction, delta * 1.5)
	for id in trails.keys():
		if not alive.has(id): trails.erase(id)
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(world) or not world.show_hud or not world.is_combat() or not world.camera:
		return
	var viewport_size := get_viewport_rect().size
	var chest_rects: Array[Rect2] = []
	for actor in world.enemies:
		if not is_instance_valid(actor) or actor.dead:
			continue
		var fraction := clampf(actor.health / maxf(actor.max_health, .001), 0.0, 1.0)
		var trail := float(trails.get(actor.get_instance_id(), fraction))
		if EnemyEcology.is_boss(actor.enemy_type):
			var width := minf(650.0, viewport_size.x * .55)
			var at := Vector2((viewport_size.x - width) * .5, 150)
			var panel := Rect2(at, Vector2(width, 95))
			draw_style_box(_panel(), panel)
			var name_text: String = EnemyEcology.TYPES[actor.enemy_type].name
			draw_string(face, at + Vector2(14, 30), name_text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, width - 28, 26, Color("f1e1c6"))
			_bar(Rect2(at + Vector2(14, 43), Vector2(width - 28, 16)), fraction, trail, Color("f17d69"))
			var reward := "LEGENDARY" if actor.enemy_type == "grand_marionettist" else ("EPIC / LEGENDARY" if actor.enemy_type == "prism_conductor" else "EPIC")
			draw_string(face, at + Vector2(14, 82), "%d / %d HP" % [ceili(actor.health), ceili(actor.max_health)], HORIZONTAL_ALIGNMENT_LEFT, width * .48, 18, Color("e8d6c0"))
			draw_string(face, at + Vector2(width * .48, 82), reward + " REWARD", HORIZONTAL_ALIGNMENT_RIGHT, width * .52 - 14, 18, Color("c8a1ef"))
			var ticks: Array = [.5] if actor.enemy_type == "brass_ram" else ([.6] if actor.enemy_type == "prism_conductor" else [.3, .65])
			for threshold: float in ticks:
				var x := at.x + 14 + (width - 28) * threshold
				draw_line(Vector2(x, at.y + 43), Vector2(x, at.y + 59), Color("f5e8ca"), 2)
			var screen := world.camera.unproject_position(actor.position)
			if world.camera.is_position_behind(actor.position) or not get_viewport_rect().has_point(screen):
				var direction := (screen - viewport_size * .5).normalized()
				var center := at + Vector2(width + 20, 45)
				draw_line(center - direction * 8, center + direction * 8, Color("ffb970"), 3)
		elif actor.stationary and (fraction < 1.0 or actor.position.distance_to(world.player.position) < 5.0 or world.player.weapon_target == actor):
			var at := world.camera.unproject_position(actor.position + Vector3(0, 1.45 * actor.body_scale, 0))
			if world.camera.is_position_behind(actor.position) or not get_viewport_rect().has_point(at): continue
			at = Vector2(clampf(at.x - 70, 8, viewport_size.x - 148), clampf(at.y - 20, 195, viewport_size.y - 45))
			var panel := Rect2(at, Vector2(140, 42))
			for existing in chest_rects:
				if panel.intersects(existing): panel.position.y -= 45
			chest_rects.append(panel)
			draw_style_box(_panel(), panel)
			draw_string(face, panel.position + Vector2(7, 17), "CACHE", HORIZONTAL_ALIGNMENT_LEFT, 80, 14, Color("efd5a0"))
			draw_string(face, panel.position + Vector2(85, 17), "%d%%" % ceili(fraction * 100), HORIZONTAL_ALIGNMENT_RIGHT, 46, 14, Color("efd5a0"))
			_bar(Rect2(panel.position + Vector2(7, 25), Vector2(126, 8)), fraction, trail, Color("efb955"))

func _bar(rect: Rect2, fraction: float, trail: float, tint: Color) -> void:
	draw_rect(rect, Color("24313c"))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * trail, rect.size.y)), Color("eed6b8"))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * fraction, rect.size.y)), tint)
	draw_rect(rect, Color("77624e"), false, 1)

func _panel() -> StyleBoxFlat:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("10212a")
	panel.border_color = Color("937852")
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(5)
	return panel
