class_name Minimap
extends Control

## Whole-arena radar drawn straight from world state (no second render). Screen-up is world -Z, matching the camera.
const MAP_SIZE: Vector2 = Vector2(256, 144) # the arena is 16:9, so one pixel is about 0.225 m
const REDRAW_INTERVAL: float = 0.05
const ENEMY_COLORS: Dictionary = {
	"basic": Color("ff6b8a"), "fast": Color("7fe3ff"), "tank": Color("e08a4a"),
	"exploder": Color("ff5a2a"), "charger": Color("ffc23d"), "tech_drop": Color("f4b942"),
}

var world: ArenaWorld
var suppressed: bool = false # set by the HUD while a full-screen panel is open
var enabled: bool = true # the M key toggles this
var redraw_clock: float = 0.0

static func world_to_map(position: Vector3, map_size: Vector2 = MAP_SIZE) -> Vector2:
	var half := WorldGeometry.HALF_ARENA
	return Vector2(clampf(position.x / (half.x * 2.0) + 0.5, 0.0, 1.0) * map_size.x,
		clampf(position.z / (half.y * 2.0) + 0.5, 0.0, 1.0) * map_size.y)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = MAP_SIZE
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -MAP_SIZE.x - 28.0
	offset_top = -MAP_SIZE.y - 28.0
	offset_right = -28.0
	offset_bottom = -28.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_M:
		enabled = not enabled

func _process(delta: float) -> void:
	var should_show := enabled and not suppressed and is_instance_valid(world) and is_instance_valid(world.player)
	visible = should_show
	redraw_clock += delta
	if should_show and redraw_clock >= REDRAW_INTERVAL:
		redraw_clock = 0.0
		queue_redraw()

func _draw() -> void:
	if not is_instance_valid(world) or not is_instance_valid(world.player):
		return
	var area := Rect2(Vector2.ZERO, MAP_SIZE)
	draw_rect(area, Color(UiPalette.PANEL, .85))
	for step in range(1, 4):
		var fraction := float(step) / 4.0
		draw_line(Vector2(MAP_SIZE.x * fraction, 0), Vector2(MAP_SIZE.x * fraction, MAP_SIZE.y), Color(UiPalette.LINE, .55))
		draw_line(Vector2(0, MAP_SIZE.y * fraction), Vector2(MAP_SIZE.x, MAP_SIZE.y * fraction), Color(UiPalette.LINE, .55))
	if world.terrain:
		var scale_x := MAP_SIZE.x / (WorldGeometry.HALF_ARENA.x * 2.0)
		for zone in world.terrain.zones:
			var tint := world.terrain.tint(zone)
			tint.a = .42
			var zone_at := world_to_map(Vector3(zone.centre.x, 0, zone.centre.y))
			if zone.is_circle:
				draw_circle(zone_at, zone.radius * scale_x, tint)
			else:
				draw_rect(Rect2(zone_at - zone.half_extents * scale_x, zone.half_extents * scale_x * 2.0), tint)
	if world.convoy_route:
		_draw_route(world.convoy_route)
	for pickup in world.pickup_root.get_children():
		if pickup is Node3D:
			draw_rect(Rect2(world_to_map((pickup as Node3D).position) - Vector2.ONE, Vector2(2, 2)), UiPalette.SCRAP)
	if world.core and not world.core.dead:
		var core_at := world_to_map(world.core.position)
		draw_rect(Rect2(core_at - Vector2(5, 5), Vector2(10, 10)), UiPalette.TEAL_HI, false, 2.0)
		draw_rect(Rect2(core_at - Vector2(2, 2), Vector2(4, 4)), UiPalette.TEAL_HI)
	for turret in world.turrets:
		if is_instance_valid(turret):
			var turret_at := world_to_map(turret.position)
			var color := UiPalette.INK if turret.carried else UiPalette.TEAL_HI
			draw_rect(Rect2(turret_at - Vector2(3, 3), Vector2(6, 6)), color)
	for enemy in world.enemies:
		if is_instance_valid(enemy) and not enemy.dead:
			var enemy_at := world_to_map(enemy.position)
			if enemy.stationary:
				draw_rect(Rect2(enemy_at - Vector2(4, 4), Vector2(8, 8)), ENEMY_COLORS["tech_drop"])
			else:
				draw_circle(enemy_at, 3.0 if enemy.elite else 2.0, ENEMY_COLORS.get(enemy.enemy_type, ENEMY_COLORS["basic"]))
	_draw_camera_view()
	_draw_player()
	draw_rect(area, UiPalette.LINE, false, 1.0)

## Convoy route: a line through the doors (driven legs dim), numbered dots, and a larger amber dot at the end.
func _draw_route(route: ConvoyRoute) -> void:
	var progress := world.convoy_mover.target_index if world.convoy_mover and world.convoy_mover.route == route else 1
	for index in range(1, route.doors.size()):
		var from := world_to_map(route.doors[index - 1])
		var to := world_to_map(route.doors[index])
		var final := index == route.doors.size() - 1
		var colour := Color(UiPalette.LINE, .8) if index < progress else (UiPalette.SCRAP if final else UiPalette.TEAL_HI)
		draw_line(from, to, colour, 1.5)
		draw_circle(to, 4.0 if final else 2.5, colour)

func _draw_camera_view() -> void:
	if not world.camera_rig:
		return
	var half := world.camera_rig.visible_half_extents(world.camera_rig.zoom)
	var corner_a := world_to_map(world.camera_rig.focus - Vector3(half.x, 0, half.y))
	var corner_b := world_to_map(world.camera_rig.focus + Vector3(half.x, 0, half.y))
	draw_rect(Rect2(corner_a, corner_b - corner_a), Color(1, 1, 1, .75), false, 1.0)

func _draw_player() -> void:
	var at := world_to_map(world.player.position)
	var forward := -world.player.visual.global_basis.z
	var heading := Vector2(forward.x, forward.z).normalized() if forward.length_squared() > .0001 else Vector2.UP
	var side := heading.orthogonal()
	draw_colored_polygon(PackedVector2Array([at + heading * 6.0, at - heading * 4.0 + side * 4.0, at - heading * 4.0 - side * 4.0]), UiPalette.TEAL_HI.lerp(Color.WHITE, .4))
