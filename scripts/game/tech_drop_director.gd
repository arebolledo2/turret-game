class_name TechDropDirector
extends RefCounted

## Tech drops: a stationary, destructible crate that appears away from the defended area during a wave.
## Destroying it pays a scrap burst and may grant a free item; whatever is left at wave end is lost.
## A drop is a stationary `TechDropActor` in `world.enemies`, so turrets and the hero target it like any enemy.
var world: ArenaWorld
var roll_clock: float = 0.0
var pulse: float = 0.0
## Warning markers waiting to become drops: {at: Vector3, left: float, marker: MeshInstance3D}.
var queued: Array[Dictionary] = []
var spawned: int = 0
var destroyed: int = 0

const WARNING_COLOR := Color("f4b942")

func reset() -> void:
	for entry in queued:
		var marker: MeshInstance3D = entry["marker"]
		if is_instance_valid(marker):
			marker.queue_free()
	queued.clear()
	roll_clock = 0.0

func active_count() -> int:
	var count := queued.size()
	for enemy in world.enemies:
		if is_instance_valid(enemy) and enemy.stationary and not enemy.dead:
			count += 1
	return count

func tick(delta: float) -> void:
	if not FeatureFlagService.is_enabled(FeatureFlagService.TECH_DROPS) or not world.is_combat():
		return
	pulse += delta * 8.0
	for index in range(queued.size() - 1, -1, -1):
		var entry := queued[index]
		entry["left"] = float(entry["left"]) - delta
		var marker: MeshInstance3D = entry["marker"]
		if is_instance_valid(marker):
			GroundDial.update(marker, 1.0 - float(entry["left"]) / GameConstants.TECH_DROP_WARNING_TIME)
			var brightness := 1.0 if FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION) else 1.0 + .12 * sin(pulse)
			(marker.material_override as ShaderMaterial).set_shader_parameter("brightness", brightness)
		if float(entry["left"]) <= 0.0:
			if is_instance_valid(marker):
				marker.queue_free()
			spawn(entry["at"])
			queued.remove_at(index)
	roll_clock += delta
	if roll_clock < GameConstants.TECH_DROP_ROLL_INTERVAL:
		return
	roll_clock -= GameConstants.TECH_DROP_ROLL_INTERVAL
	if world.waves.time_left < GameConstants.TECH_DROP_MIN_TIME_LEFT or active_count() >= GameConstants.TECH_DROP_MAX_ACTIVE:
		return
	if GameRandom.gameplay.randf() >= GameConstants.TECH_DROP_SPAWN_CHANCE:
		return
	var at := find_position()
	if at != Vector3.INF:
		queue_drop(at)

## A spot that forces a decision: well clear of the core (or the hero) and of every turret.
func find_position() -> Vector3:
	var half := WorldGeometry.HALF_ARENA - Vector2.ONE * GameConstants.TECH_DROP_EDGE_MARGIN
	for attempt in 30:
		var at := Vector3(GameRandom.gameplay.randf_range(-half.x, half.x), 0, GameRandom.gameplay.randf_range(-half.y, half.y))
		if world.core:
			if WorldGeometry.planar(at - world.core.position).length() < GameConstants.TECH_DROP_MIN_CORE_DISTANCE:
				continue
		elif is_instance_valid(world.player) and WorldGeometry.planar(at - world.player.position).length() < GameConstants.TECH_DROP_MIN_TURRET_DISTANCE:
			continue
		if world.terrain and (world.terrain.blocks_build(at) or world.terrain.mud_factor_at(at) < 1.0):
			continue
		var clear := true
		for turret in world.turrets:
			if WorldGeometry.planar(turret.position - at).length() < GameConstants.TECH_DROP_MIN_TURRET_DISTANCE:
				clear = false
				break
		if clear:
			return at
	return Vector3.INF

func queue_drop(at: Vector3) -> void:
	var marker := GroundDial.create(world.actor_root, 1.0, WARNING_COLOR)
	marker.position = Vector3(at.x, .05, at.z)
	queued.append({"at": at, "left": GameConstants.TECH_DROP_WARNING_TIME, "marker": marker})

func spawn(at: Vector3) -> CombatActor:
	var wave := maxi(GameStateService.current_wave, 1)
	var tank := EnemyStats.for_wave("tank", wave, world.difficulty_config)
	var drop := TechDropActor.new()
	drop.world = world
	drop.max_health = tank.health * GameConstants.TECH_DROP_HEALTH_FRACTION
	drop.health = drop.max_health
	drop.speed = 0.0
	drop.contact_damage = 0.0
	drop.mass = 1000000.0
	drop.scrap_value = 0
	drop.body_scale = GameConstants.TECH_DROP_BODY_SCALE
	drop.position = at
	world.actor_root.add_child(drop)
	drop.reset_physics_interpolation()
	world.enemies.append(drop)
	spawned += 1
	return drop

## Pays out a destroyed drop: a scrap burst and, by chance, a free item from the shop's own weighted pool.
func reward(drop: CombatActor) -> void:
	destroyed += 1
	for index in GameConstants.TECH_DROP_SCRAP_PICKUPS:
		var pickup := ScrapPickup.new()
		pickup.world = world
		pickup.amount = GameConstants.TECH_DROP_SCRAP_EACH
		var angle := GameRandom.gameplay.randf() * TAU
		var distance := GameRandom.gameplay.randf() * GameConstants.TECH_DROP_SCATTER_RADIUS
		pickup.position = drop.position + Vector3(cos(angle), 0, sin(angle)) * distance
		world.pickup_root.add_child(pickup)
		pickup.reset_physics_interpolation()
	world.combat.explosion.emit(WorldGeometry.planar(drop.position), 1.4)
	var item_id := ""
	if GameRandom.gameplay.randf() < GameConstants.TECH_DROP_ITEM_CHANCE:
		item_id = world.shop.roll_item_reward()
	if item_id.is_empty():
		world.message = "Tech drop destroyed · scrap recovered"
	else:
		world.shop.apply_item(item_id)
		world.message = "Tech drop salvaged: %s" % str(ItemRegistry.get_item_dict(item_id)["name"])
	world.audio.play_cue("purchase", world.player.position)
