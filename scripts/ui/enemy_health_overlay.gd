class_name EnemyHealthOverlay
extends Control

## Screen-space health presentation: readable at every world zoom, no floating box meshes.
var world: ArenaWorld
var trails: Dictionary = {}
## Bosses and crates only; every other enemy shows no world-space health.
var tracked: Array[CombatActor] = []
var _had_tracked: bool = false
var pulse_time := 0.0
var face: Font

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	face = preload("res://assets/fonts/BarlowCondensed-SemiBold.ttf")

func _process(delta: float) -> void:
	if not is_instance_valid(world):
		return
	if world.is_combat() and not world.paused: pulse_time += delta
	var alive := {}
	tracked.clear()
	for actor in world.enemies:
		if not is_instance_valid(actor) or actor.dead or not (actor.stationary or EnemyEcology.is_boss(actor.enemy_type) or EnemyEcology.ranged_threat(actor.enemy_type)):
			continue
		tracked.append(actor)
		var id := actor.get_instance_id()
		alive[id] = true
		var fraction := clampf(actor.health / maxf(actor.max_health, .001), 0.0, 1.0)
		var previous := float(trails.get(id, fraction))
		trails[id] = fraction if FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION) else move_toward(previous, fraction, delta * 1.5)
	for id in trails.keys():
		if not alive.has(id): trails.erase(id)
	# Nothing to draw: skip the canvas rebuild (one extra redraw clears the last frame's pixels).
	if not tracked.is_empty() or _had_tracked:
		queue_redraw()
	_had_tracked = not tracked.is_empty()

func _draw() -> void:
	if not is_instance_valid(world) or not world.show_hud or not world.is_combat() or not world.camera:
		return
	var viewport_size := get_viewport_rect().size
	var chest_rects: Array[Rect2] = []
	for actor in tracked:
		if not is_instance_valid(actor) or actor.dead:
			continue
		if actor.stationary or EnemyEcology.is_boss(actor.enemy_type) or EnemyEcology.ranged_threat(actor.enemy_type):
			_draw_pointer(actor)
		var fraction := clampf(actor.health / maxf(actor.max_health, .001), 0.0, 1.0)
		var trail := float(trails.get(actor.get_instance_id(), fraction))
		if EnemyEcology.is_boss(actor.enemy_type):
			var width := minf(650.0, viewport_size.x * .55)
			var at := Vector2((viewport_size.x - width) * .5, viewport_size.y - 174)
			var panel := Rect2(at, Vector2(width, 95))
			draw_style_box(_panel(), panel)
			var name_text: String = EnemyEcology.TYPES[actor.enemy_type].name
			draw_string(face, at + Vector2(14, 30), name_text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, width - 28, 26, Color("f1e1c6"))
			_bar(Rect2(at + Vector2(14, 43), Vector2(width - 28, 16)), fraction, trail, Color("f17d69"))
			var reward := "LEGENDARY" if actor.enemy_type == "grand_marionettist" else ("EPIC / LEGENDARY" if actor.enemy_type == "prism_conductor" else "EPIC")
			draw_string(face, at + Vector2(14, 82), "%d / %d HP" % [ceili(actor.health), ceili(actor.max_health)], HORIZONTAL_ALIGNMENT_LEFT, width * .48, 18, Color("e8d6c0"))
			draw_string(face, at + Vector2(width * .48, 82), reward + " REWARD", HORIZONTAL_ALIGNMENT_RIGHT, width * .52 - 14, 18, Color("c8a1ef"))
			var ticks: Array = [.5] if (actor.enemy_type == "brass_ram" or actor.enemy_type in EnemyEcology.EXPANSION_BOSSES) else ([.6] if actor.enemy_type == "prism_conductor" else [.3, .65])
			for threshold: float in ticks:
				var x := at.x + 14 + (width - 28) * threshold
				draw_line(Vector2(x, at.y + 43), Vector2(x, at.y + 59), Color("f5e8ca"), 2)
		elif actor.stationary and (fraction < 1.0 or actor.position.distance_to(world.player.position) < 5.0 or world.player.weapon_target == actor):
			var at := _screen_position(actor.position + Vector3(0, 1.45 * actor.body_scale, 0))
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

func _screen_position(at: Vector3) -> Vector2:
	return world.playfield.to_screen(at) if world.playfield else world.camera.unproject_position(at)

func pointer_data(actor: CombatActor) -> Dictionary:
	var bounds := world.playfield.rect if world.playfield else get_viewport_rect()
	var screen := _screen_position(actor.position)
	var behind := world.camera.is_position_behind(actor.position)
	if not behind and bounds.has_point(screen): return {}
	var centre := bounds.get_center()
	var direction := (screen - centre).normalized() * (-1.0 if behind else 1.0)
	if direction.is_zero_approx(): direction = Vector2.UP
	var half := bounds.size * .5 - Vector2(80, 70)
	var distance := minf(half.x / maxf(absf(direction.x), .001), half.y / maxf(absf(direction.y), .001))
	return {"at": centre + direction * distance, "direction": direction}

func _draw_pointer(actor: CombatActor) -> void:
	var data := pointer_data(actor)
	if data.is_empty(): return
	var at: Vector2 = data.at
	var direction: Vector2 = data.direction
	var side := direction.orthogonal()
	var boss := EnemyEcology.is_boss(actor.enemy_type)
	var tint := Color("ff887a") if boss else Color("ffd078") if actor.stationary else Color("ffb36b")
	var pulse := 0.0 if FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION) else (sin(pulse_time * 5.0) + 1.0) * .5
	at -= direction * pulse * 7.0
	draw_circle(at, 30 + pulse * 7, Color(tint, .12 + pulse * .12))
	draw_arc(at, 29 + pulse * 7, 0, TAU, 40, Color(tint, .4), 2, true)
	var label := "BOSS" if boss else "CRATE" if actor.stationary else "RANGED"
	draw_circle(at, 22, Color(.025, .05, .07, .9))
	draw_arc(at, 23, 0, TAU, 32, tint, 2, true)
	draw_colored_polygon(PackedVector2Array([at + direction * 15, at - direction * 9 + side * 10, at - direction * 9 - side * 10]), tint)
	var text_at := at - direction * 43 - Vector2(35, -6)
	draw_string(face, text_at + Vector2(1, 1), label, HORIZONTAL_ALIGNMENT_CENTER, 70, 20, Color.BLACK)
	draw_string(face, text_at, label, HORIZONTAL_ALIGNMENT_CENTER, 70, 20, tint)
