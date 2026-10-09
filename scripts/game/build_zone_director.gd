class_name BuildZoneDirector
extends RefCounted

## Build zones: glowing patches that appear during a wave. Standing in one builds a turret or an item (shown on the
## zone). Progress holds briefly after the hero steps out, then drains. Scrap left on the field at wave end is still
## banked, and also sets the next wave's zone allowance and quality (see `note_leftover` / `begin_wave`).
## Zones are plain `BuildZoneActor` nodes under `world.actor_root`, so run restarts clear them with everything else.
var world: ArenaWorld
var zones: Array[BuildZoneActor] = []
var roll_clock: float = 0.0
## Scrap left uncollected at the end of the last wave, waiting to be applied by the next `begin_wave`.
var leftover_scrap: int = 0
## This wave's allowance, derived from the previous wave's leftover scrap.
var bonus_slots: int = 0
var wave_tier: int = 0
var spawned: int = 0
var completed: int = 0

func reset() -> void:
	for zone in zones:
		if is_instance_valid(zone):
			zone.queue_free()
	zones.clear()
	roll_clock = 0.0

## Full reset for a new run: also forgets any leftover scrap carried between waves.
func reset_run() -> void:
	reset()
	leftover_scrap = 0
	bonus_slots = 0
	wave_tier = 0
	spawned = 0
	completed = 0

## Called by `ArenaWorld.clear_field` with the scrap value still lying on the field as the wave ends.
func note_leftover(scrap: int) -> void:
	leftover_scrap = maxi(0, scrap)

## Turns the last wave's leftover scrap into this wave's extra zone slots and quality tier.
func begin_wave() -> void:
	bonus_slots = mini(floori(float(leftover_scrap) / GameConstants.BUILD_ZONE_SCRAP_PER_BONUS), GameConstants.BUILD_ZONE_MAX_BONUS)
	wave_tier = mini(floori(float(leftover_scrap) / GameConstants.BUILD_ZONE_SCRAP_PER_TIER), GameConstants.BUILD_ZONE_MAX_TIER)
	leftover_scrap = 0

func max_active() -> int:
	return GameConstants.BUILD_ZONE_BASE_ACTIVE + bonus_slots

func spawn_chance() -> float:
	return minf(1.0, GameConstants.BUILD_ZONE_SPAWN_CHANCE + .15 * bonus_slots)

func build_time(tier: int) -> float:
	return GameConstants.BUILD_ZONE_BUILD_TIME * maxf(.25, 1.0 - GameConstants.BUILD_ZONE_TIER_SPEEDUP * tier)

func tick(delta: float) -> void:
	if not FeatureFlagService.is_enabled(FeatureFlagService.BUILD_ZONES) or not world.is_combat():
		return
	for index in range(zones.size() - 1, -1, -1):
		var zone := zones[index]
		if not is_instance_valid(zone):
			zones.remove_at(index)
			continue
		if _tick_zone(zone, delta):
			zones.remove_at(index)
	roll_clock += delta
	if roll_clock < GameConstants.BUILD_ZONE_ROLL_INTERVAL:
		return
	roll_clock -= GameConstants.BUILD_ZONE_ROLL_INTERVAL
	if world.waves.time_left < GameConstants.BUILD_ZONE_MIN_TIME_LEFT or zones.size() >= max_active():
		return
	if GameRandom.gameplay.randf() >= spawn_chance():
		return
	var at := find_position()
	if at != Vector3.INF:
		var result := roll_result(wave_tier)
		spawn_zone(at, result["kind"], result["asset_id"], wave_tier)

## Advances one zone; returns true when the zone is gone (finished or faded) and should leave the list.
func _tick_zone(zone: BuildZoneActor, delta: float) -> bool:
	if not zone.is_active():
		zone.warning_left -= delta
		zone.refresh()
		return false
	zone.life_left -= delta
	if zone.life_left <= 0.0:
		zone.queue_free()
		return true
	zone.occupied = is_instance_valid(world.player) and WorldGeometry.planar(world.player.position - zone.position).length() < GameConstants.BUILD_ZONE_RADIUS
	if zone.occupied:
		zone.away_time = 0.0
		zone.progress = minf(1.0, zone.progress + delta / build_time(zone.tier))
		if zone.progress >= 1.0 and complete(zone):
			return true
	else:
		zone.away_time += delta
		if zone.away_time > GameConstants.BUILD_ZONE_GRACE_TIME:
			zone.progress = maxf(0.0, zone.progress - GameConstants.BUILD_ZONE_DECAY_RATE * delta)
	zone.refresh()
	return false

## A spot well away from turrets, the core and other zones, so reaching it is a decision.
func find_position() -> Vector3:
	var half := WorldGeometry.HALF_ARENA - Vector2.ONE * GameConstants.BUILD_ZONE_EDGE_MARGIN
	for attempt in 30:
		var at := Vector3(GameRandom.gameplay.randf_range(-half.x, half.x), 0, GameRandom.gameplay.randf_range(-half.y, half.y))
		if world.core and WorldGeometry.planar(at - world.core.position).length() < GameConstants.BUILD_ZONE_MIN_CORE_DISTANCE:
			continue
		if world.terrain and world.terrain.blocks_build(at):
			continue
		var clear := true
		for turret in world.turrets:
			if WorldGeometry.planar(turret.position - at).length() < GameConstants.BUILD_ZONE_MIN_TURRET_DISTANCE:
				clear = false
				break
		for zone in zones:
			if is_instance_valid(zone) and WorldGeometry.planar(zone.position - at).length() < GameConstants.BUILD_ZONE_MIN_ZONE_DISTANCE:
				clear = false
				break
		if clear:
			return at
	return Vector3.INF

## What a zone of this quality tier will build: {kind, asset_id}. Higher tiers skew to pricier turrets and rarer items.
func roll_result(tier: int) -> Dictionary:
	var rng := GameRandom.gameplay
	if rng.randf() < GameConstants.BUILD_ZONE_ITEM_CHANCE:
		var item_id := _roll_item(tier)
		if not item_id.is_empty():
			return {"kind": "item", "asset_id": item_id}
	var turret_ids := ShopCatalog.available_ids("turret")
	if turret_ids.is_empty():
		return {"kind": "turret", "asset_id": "normal"}
	turret_ids.sort_custom(func(a: String, b: String) -> bool: return TurretRegistry.get_base_price(a) < TurretRegistry.get_base_price(b))
	var skewed := pow(rng.randf(), 1.0 / (1.0 + .6 * tier))
	return {"kind": "turret", "asset_id": turret_ids[mini(int(skewed * turret_ids.size()), turret_ids.size() - 1)]}

func _roll_item(tier: int) -> String:
	return ItemRegistry.get_weighted_random_item(GameStateService.current_wave,
		PlayerStatsService.get_player_luck() + GameConstants.BUILD_ZONE_TIER_LUCK * tier,
		ItemTrackingService.item_counts, world.shop.unavailable_item_ids(), GameRandom.gameplay)

func spawn_zone(at: Vector3, kind: String, asset_id: String, tier: int) -> BuildZoneActor:
	var zone := BuildZoneActor.new()
	zone.position = Vector3(at.x, 0, at.z)
	zone.warning_left = GameConstants.BUILD_ZONE_WARNING_TIME
	zone.life_left = GameConstants.BUILD_ZONE_LIFETIME
	world.actor_root.add_child(zone)
	zone.setup(kind, asset_id, tier)
	zones.append(zone)
	spawned += 1
	return zone

## Builds what the zone promised. Returns false (zone stays, nearly full) when a turret has nowhere to go.
func complete(zone: BuildZoneActor) -> bool:
	var built := ""
	if zone.kind == "turret":
		var at := zone.position
		if not world.valid_placement(at):
			at = world.find_placement()
		if at == Vector3.INF:
			world.message = "No room to build here."
			zone.progress = .95
			return false
		world.add_turret(at, zone.asset_id)
		built = ArenaShop.offer_name(ShopOffer.new("turret", zone.asset_id, 0))
	else:
		var item_id := zone.asset_id
		if ItemRegistry.is_at_max_stacks(item_id, ItemTrackingService.item_counts):
			item_id = _roll_item(zone.tier)
		if item_id.is_empty():
			world.message = "Build zone fizzled · nothing left to build"
			zone.queue_free()
			return true
		world.shop.apply_item(item_id)
		built = ArenaShop.offer_name(ShopOffer.new("item", item_id, 0))
	completed += 1
	world.message = "Built: " + built
	world.combat.explosion.emit(WorldGeometry.planar(zone.position), 1.0)
	world.audio.play_cue("purchase", world.player.position)
	zone.queue_free()
	return true
