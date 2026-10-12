class_name SpawnZones
extends Node3D

const BIAS := .7
const RADIUS := 3.0
const CORE_GAP := 2.0
var world: ArenaWorld
var centres: Array[Vector3] = []
var labels: Array[Label3D] = []

func generate(wave: int) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	centres.clear()
	labels.clear()
	var count := GameRandom.gameplay.randi_range(1, 2) if wave <= 5 else GameRandom.gameplay.randi_range(2, 4)
	var bounds := WorldGeometry.HALF_ARENA - Vector2.ONE * (RADIUS + 1.0)
	for index in count:
		var at := Vector3.ZERO
		var found := false
		for attempt in 64:
			at = Vector3(GameRandom.gameplay.randf_range(-bounds.x, bounds.x), 0, GameRandom.gameplay.randf_range(-bounds.y, bounds.y))
			var separated := true
			for other in centres:
				if at.distance_to(other) < RADIUS * 2.0: separated = false
			if separated and safe_from_core(at) and not world.waves.spawn_blocked(at):
				found = true
				break
		if not found:
			# Never commit the final rejected candidate. A winding route may leave fewer zones.
			continue
		centres.append(at)
		var dial := GroundDial.create(self, RADIUS, Color(.85, .49, .25, .7), false)
		dial.position = at + Vector3(0, .03, 0)
		GroundDial.update(dial, 0.0, true, 8)
		var label := Label3D.new()
		label.text = "SPAWN ZONE %d" % (index + 1)
		label.font_size = 42
		label.pixel_size = .008
		label.modulate = Color("ffd09c")
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = at + Vector3(0, .2, 0)
		add_child(label)
		labels.append(label)

func sample() -> Vector3:
	var centre := centres[GameRandom.gameplay.randi_range(0, centres.size() - 1)]
	var angle := GameRandom.gameplay.randf() * TAU
	var radius := sqrt(GameRandom.gameplay.randf()) * RADIUS
	return WorldGeometry.clamp_position(centre + Vector3(cos(angle), 0, sin(angle)) * radius, 1.0)

func _process(_delta: float) -> void:
	var prep := GameStateMachine.current_state == GameStateMachine.GameState.PREPARATION
	visible = prep or world.is_combat()
	for label in labels: label.visible = prep

func safe_from_core(at: Vector3) -> bool:
	if not is_instance_valid(world.core): return true
	if WorldGeometry.planar(at - world.core.position).length() < RADIUS + CORE_GAP + world.core.radius: return false
	if world.convoy_mode and world.convoy_route:
		var points := world.convoy_route.doors
		for i in range(1, points.size()):
			var closest := Geometry3D.get_closest_point_to_segment(at, points[i - 1], points[i])
			if at.distance_to(closest) < RADIUS + CORE_GAP + world.core.radius: return false
	return true
