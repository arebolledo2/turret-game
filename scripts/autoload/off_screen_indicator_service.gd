extends Node

## OffScreenIndicatorService - Tracks off-screen entities and provides grouped data for UI indicators
## Autoload singleton that monitors enemies, spawns, tech drops, and turrets
## Groups entities by directional sector (8 sectors) and type for clean UI presentation

# Configuration
const INDICATOR_INSET_MARGIN: float = 30.0 # Pixels from screen edge
const SECTOR_COUNT: int = 8 # Directional sectors (N, NE, E, SE, S, SW, W, NW)

# Color definitions
const COLOR_ENEMY: Color = Color(1.0, 0.3, 0.3)
const COLOR_SPAWN: Color = Color(1.0, 0.7, 0.2)
const COLOR_TECH_DROP: Color = Color(0.8, 0.3, 0.8)
const COLOR_TURRET: Color = Color(0.4, 0.8, 0.4)

# Tracked entity data
class TrackedEntity:
	var node: Node2D
	var type: String # "enemy_spider", "spawn_tank", "tech_drop", "turret_normal"
	var category: String # "enemy", "spawn", "tech_drop", "turret"
	var position: Vector2
	var is_valid: bool = true

	func _init(p_node: Node2D, p_type: String, p_category: String) -> void:
		node = p_node
		type = p_type
		category = p_category
		if node:
			position = node.global_position

# Entity tracking
var tracked_entities: Array[TrackedEntity] = []

# Cached references
var enemy_spawner: Node = null


func _ready() -> void:
	# Connect to entity lifecycle signals
	Events.enemy_spawned.connect(_on_enemy_spawned)
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.tech_drop_spawned.connect(_on_tech_drop_spawned)
	Events.tech_drop_destroyed.connect(_on_tech_drop_destroyed)
	Events.tech_drop_despawned.connect(_on_tech_drop_despawned)
	Events.turret_spawned.connect(_on_turret_spawned)
	Events.turret_picked_up.connect(_on_turret_picked_up)
	Events.game_started.connect(_on_game_started)


func _on_game_started() -> void:
	# Get reference to enemy spawner
	await get_tree().process_frame
	enemy_spawner = get_tree().get_first_node_in_group("enemy_spawner") if get_tree() else null


## Get viewport bounds in world coordinates
func get_viewport_bounds() -> Rect2:
	if not get_tree():
		return Rect2()

	var camera := get_tree().get_first_node_in_group("player")
	if not camera:
		return Rect2()

	camera = camera.get_viewport().get_camera_2d() if camera.has_method("get_viewport") else null
	if not camera:
		return Rect2()

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var visible_world_size: Vector2 = viewport_size / camera.zoom
	var camera_pos: Vector2 = camera.global_position

	return Rect2(
		camera_pos - visible_world_size / 2.0,
		visible_world_size
	)


## Calculate sector (0-7) from direction vector
## 0=E, 1=SE, 2=S, 3=SW, 4=W, 5=NW, 6=N, 7=NE
func get_sector(direction: Vector2) -> int:
	var angle := direction.angle()
	var degrees := rad_to_deg(angle)
	if degrees < 0:
		degrees += 360
	return int((degrees + 22.5) / 45.0) % SECTOR_COUNT


## Get grouped entities for indicator display
## Returns: Dictionary[sector][type] -> Array[TrackedEntity]
func get_indicator_groups() -> Dictionary:
	var viewport_bounds := get_viewport_bounds()
	if viewport_bounds.size.x == 0 or viewport_bounds.size.y == 0:
		return {}

	# Update entity positions and validate
	_update_tracked_entities()

	# Track spawns from enemy spawner
	_update_spawn_tracking()

	var groups: Dictionary = {} # sector -> type -> Array[TrackedEntity]
	var screen_center := viewport_bounds.get_center()

	for entity in tracked_entities:
		if not entity.is_valid:
			continue

		# Skip if on-screen
		if viewport_bounds.has_point(entity.position):
			continue

		# Calculate sector
		var direction := (entity.position - screen_center).normalized()
		var sector := get_sector(direction)

		# Initialize nested dictionaries
		if not groups.has(sector):
			groups[sector] = {}
		if not groups[sector].has(entity.type):
			groups[sector][entity.type] = []

		# Add entity to group
		groups[sector][entity.type].append(entity)

	return groups


## Calculate screen position for an indicator at the edge of the viewport
func calculate_indicator_position(entities: Array, viewport_bounds: Rect2) -> Dictionary:
	if entities.is_empty():
		return {}

	var screen_center := viewport_bounds.get_center()

	# Average direction of all entities in group
	var avg_direction := Vector2.ZERO
	for entity in entities:
		var direction: Vector2 = (entity.position - screen_center).normalized()
		avg_direction += direction

	avg_direction = avg_direction.normalized()

	# Intersect with viewport edges
	var intersection := _intersect_rect_with_ray(screen_center, avg_direction, viewport_bounds)

	# Inset from edge
	var indicator_pos := intersection - avg_direction * INDICATOR_INSET_MARGIN

	return {
		"screen_position": indicator_pos,
		"direction": avg_direction,
		"count": entities.size(),
		"category": entities[0].category if not entities.is_empty() else ""
	}


## Calculate ray-rect intersection for edge positioning
func _intersect_rect_with_ray(origin: Vector2, direction: Vector2, rect: Rect2) -> Vector2:
	var min_t := INF
	var intersection := origin

	# Top edge
	if direction.y < 0:
		var t := (rect.position.y - origin.y) / direction.y
		var x := origin.x + direction.x * t
		if x >= rect.position.x and x <= rect.end.x and t < min_t:
			min_t = t
			intersection = Vector2(x, rect.position.y)

	# Bottom edge
	if direction.y > 0:
		var t := (rect.end.y - origin.y) / direction.y
		var x := origin.x + direction.x * t
		if x >= rect.position.x and x <= rect.end.x and t < min_t:
			min_t = t
			intersection = Vector2(x, rect.end.y)

	# Left edge
	if direction.x < 0:
		var t := (rect.position.x - origin.x) / direction.x
		var y := origin.y + direction.y * t
		if y >= rect.position.y and y <= rect.end.y and t < min_t:
			min_t = t
			intersection = Vector2(rect.position.x, y)

	# Right edge
	if direction.x > 0:
		var t := (rect.end.x - origin.x) / direction.x
		var y := origin.y + direction.y * t
		if y >= rect.position.y and y <= rect.end.y and t < min_t:
			min_t = t
			intersection = Vector2(rect.end.x, y)

	return intersection


## Update positions and validate tracked entities
func _update_tracked_entities() -> void:
	var i := 0
	while i < tracked_entities.size():
		var entity := tracked_entities[i]

		# Check if node is still valid
		if not is_instance_valid(entity.node):
			entity.is_valid = false
			tracked_entities.remove_at(i)
			continue

		# Update position
		entity.position = entity.node.global_position
		i += 1


## Track enemy spawns from spawner's queue
func _update_spawn_tracking() -> void:
	if not enemy_spawner or not enemy_spawner.has_method("get"):
		return

	# Remove old spawn tracking
	tracked_entities = tracked_entities.filter(func(e): return e.category != "spawn")

	# Access queued_spawns array
	if not "queued_spawns" in enemy_spawner:
		return

	var queued_spawns: Array = enemy_spawner.queued_spawns
	for spawn_data in queued_spawns:
		if not spawn_data is Dictionary:
			continue

		var enemy_type: String = spawn_data.get("enemy_type", "")
		var spawn_pos: Vector2 = spawn_data.get("spawn_pos", Vector2.ZERO)

		if enemy_type.is_empty():
			continue

		# Create tracked entity for spawn (no node reference, just position)
		var entity := TrackedEntity.new(null, "spawn_" + enemy_type, "spawn")
		entity.position = spawn_pos
		tracked_entities.append(entity)


## Get color for entity category
func get_category_color(category: String) -> Color:
	match category:
		"enemy":
			return COLOR_ENEMY
		"spawn":
			return COLOR_SPAWN
		"tech_drop":
			return COLOR_TECH_DROP
		"turret":
			return COLOR_TURRET
		_:
			return Color.WHITE


## Get display name for entity type
func get_entity_display_name(entity_type: String) -> String:
	# Remove category prefix if present
	var display_name := entity_type
	if display_name.begins_with("enemy_"):
		display_name = display_name.substr(6)
	elif display_name.begins_with("spawn_"):
		display_name = display_name.substr(6)
	elif display_name.begins_with("turret_"):
		display_name = display_name.substr(7)

	# Capitalize and format
	display_name = display_name.capitalize()

	return display_name


# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_enemy_spawned(enemy: Node2D) -> void:
	if not enemy:
		return

	# Determine enemy type from EnemyRegistry if possible
	var enemy_type := "unknown"
	if enemy.has_method("get") and "enemy_id" in enemy:
		enemy_type = enemy.enemy_id

	var entity := TrackedEntity.new(enemy, "enemy_" + enemy_type, "enemy")
	tracked_entities.append(entity)


func _on_enemy_killed(enemy: Node2D, _position: Vector2) -> void:
	_remove_entity_by_node(enemy)


func _on_tech_drop_spawned(tech_drop: Node2D, _position: Vector2) -> void:
	if not tech_drop:
		return

	var entity := TrackedEntity.new(tech_drop, "tech_drop", "tech_drop")
	tracked_entities.append(entity)


func _on_tech_drop_destroyed(tech_drop: Node2D, _position: Vector2) -> void:
	_remove_entity_by_node(tech_drop)


func _on_tech_drop_despawned(tech_drop: Node2D) -> void:
	_remove_entity_by_node(tech_drop)


func _on_turret_spawned(turret: Node2D, _position: Vector2) -> void:
	if not turret:
		return

	# Determine turret type
	var turret_type := "normal"
	if turret.has_method("get") and "turret_id" in turret:
		turret_type = turret.turret_id

	var entity := TrackedEntity.new(turret, "turret_" + turret_type, "turret")
	tracked_entities.append(entity)


func _on_turret_picked_up(turret: Node2D) -> void:
	# Remove from tracking when picked up (it's now with the player)
	_remove_entity_by_node(turret)


## Remove entity from tracking by node reference
func _remove_entity_by_node(node: Node2D) -> void:
	for i in range(tracked_entities.size() - 1, -1, -1):
		if tracked_entities[i].node == node:
			tracked_entities.remove_at(i)
			return
