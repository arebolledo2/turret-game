class_name CombatActor
extends CharacterBody3D

var world: ArenaWorld
var is_enemy: bool = false
var enemy_type: String = "basic"
var mass: float = 1.0
var scrap_value: int = 1
var knockback_velocity: Vector3 = Vector3.ZERO
var brain: EnemyBrain
var charge: ChargeController3D
var warning: MeshInstance3D
var marker: MeshInstance3D
var weapon_muzzle: Node3D
var statuses := StatusEffects3D.new()
var slow_marker: MeshInstance3D
## Ground ring shown while Marked (built on first use).
var mark_marker: MeshInstance3D
## Ground ring shown while Staggered (built on first use).
var stagger_marker: MeshInstance3D
var health: float = 25.0
var max_health: float = 25.0
var speed: float = 2.5
var contact_damage: float = 8.0
var body_scale: float = 1.0
var explosion_radius: float = 0.0
var explosion_damage: float = 0.0
var dead: bool = false
var invulnerability: float = 0.0
var visual: Node3D
var hurtbox: Area3D
var legs: Array[Node3D] = []
var gait: float = 0.0
var flash_time: float = 0.0
var hit_flash: HitFlash
## Core mode: true while this enemy is chasing the hero instead of the core (hysteresis between the aggro ranges).
var chasing_hero: bool = false
## Core mode: this enemy never switches to the hero.
var ignores_hero: bool = false
var core_clock: float = 0.0
## Tech drops: never moves, never attacks. Built from a crate model instead of a spider.
var stationary: bool = false
## Difficulty rules: tougher, faster, gold-tinted. A seeker (`ignores_hero`) gets a red marker.
var elite: bool = false

const FLASH_DURATION: float = .18
const ENEMY_FLASH_COLOR := Color(1.0, .92, .8)
const PLAYER_FLASH_COLOR := Color(1.0, .28, .22)
var weapon_clock: float = 0.0
var _footprint: float = -1.0
var weapon_target: CombatActor
var clockwork_motion: ClockworkMotion
var ecology_motion: EcologyMotion

## The Decoy taunt (S1) that is pulling this actor right now, or null. Only enemies answer taunts (see `EnemyActor`).
func taunt_post() -> TauntPost:
	return null

## Planar footprint of the same capsule used by projectile collisions.
func hurtbox_radius() -> float:
	if _footprint < 0.0:
		_footprint = float(EnemyEcology.FOOTPRINTS.get(enemy_type, .36))
	return _footprint * body_scale

func overlaps_attack_range(origin: Vector3, reach: float) -> bool:
	var radius := maxf(0.0, reach) + hurtbox_radius()
	return WorldGeometry.planar(position - origin).length_squared() <= radius * radius + .000001

func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	_configure_body()
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	_build_visuals()
	SettingsService.ground_markers_changed.connect(_refresh_ground_marker)
	_refresh_ground_marker()

## Collision layers and body shape; `HeroActor` and `EnemyActor` set these up differently.
func _configure_body() -> void:
	pass

## Model, markers and (for enemies) hurtbox under `visual`.
func _build_visuals() -> void:
	pass

func _refresh_ground_marker() -> void:
	if marker:
		var mode := SettingsService.ground_markers
		marker.visible = mode == SettingsService.GroundMarkers.ALL or (mode == SettingsService.GroundMarkers.CONTEXTUAL and is_enemy and (elite or ignores_hero or charge != null))

## Called after damage lands and health has changed; overridden by actors that show health in the world.
func _on_health_changed() -> void:
	pass

func clear_transients() -> void:
	statuses.clear()
	if slow_marker:
		slow_marker.visible = false
	if mark_marker:
		mark_marker.visible = false
	if stagger_marker:
		stagger_marker.visible = false
	knockback_velocity = Vector3.ZERO
	velocity = Vector3.ZERO
	flash_time = 0.0
	if hit_flash:
		hit_flash.clear()
	visual.visible = true
	if warning:
		warning.visible = false
	if charge:
		charge.interrupt()

func _physics_process(delta: float) -> void:
	if dead or not is_instance_valid(world) or not world.is_combat():
		return
	invulnerability = maxf(0.0, invulnerability - delta)
	flash_time = maxf(0.0, flash_time - delta)
	var reduced_motion := FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION)
	if hit_flash:
		hit_flash.update(flash_time / FLASH_DURATION, reduced_motion)
	if not _tick_statuses(delta):
		return
	if stationary:
		return
	var direction := _steer(delta)
	var previous_position := position
	_move(delta)
	_after_move(previous_position)
	_animate(delta, direction, reduced_motion)
	_act(delta, previous_position)

## Advances damage-over-time effects; false when the actor died doing so.
func _tick_statuses(_delta: float) -> bool:
	return true

## Sets velocity for this tick and returns the heading.
func _steer(_delta: float) -> Vector3:
	return Vector3.ZERO

## Applies velocity to the position, clamped to the arena.
func _move(_delta: float) -> void:
	pass

## Runs after the move, before animation.
func _after_move(_previous_position: Vector3) -> void:
	pass

## The tick's action: touch damage for enemies, the auto-fire weapon for the hero.
func _act(_delta: float, _previous_position: Vector3) -> void:
	pass

## Turns toward the heading and bobs/poses the legs. Purely cosmetic.
func _animate(delta: float, direction: Vector3, reduced_motion: bool) -> void:
	if direction.length_squared() > 0.001:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-direction.x, -direction.z), minf(delta * 14.0, 1.0))
	if ecology_motion:
		visual.position.y = 0.0
		ecology_motion.tick(delta, velocity.length_squared() > .01, brain.state in [EnemyBrain.State.WARNING, EnemyBrain.State.ATTACK], reduced_motion, velocity.length() if enemy_type == "hopper" else -1.0)
		if brain.expansion: brain.expansion.pose()
		return
	if clockwork_motion:
		visual.position.y = 0.0
		clockwork_motion.tick(delta, velocity.length(), reduced_motion, not is_enemy and is_instance_valid(world.carried_turret))
		return
	gait += velocity.length() * delta * 10.0 * (GameConstants.REDUCED_MOTION_SPEED if reduced_motion else 1.0)
	visual.position.y = sin(gait * 2.0) * 0.025
	# Leg posing is cosmetic: pose each enemy every other physics tick, staggered by instance.
	var pose_legs := not is_enemy or (Engine.get_physics_frames() + get_instance_id()) % 2 == 0
	for index in range(legs.size() if pose_legs else 0):
		var leg: Node3D = legs[index]
		if leg:
			var phase := gait + float(index % 2) * PI
			leg.rotation = Vector3(leg.rotation.x, sin(phase) * 0.24, cos(phase) * 0.12)

func take_damage(amount: float) -> void:
	world.combat.apply_hit(self, CombatHit3D.new(amount, position))

func receive_hit(hit: CombatHit3D) -> float:
	if dead or invulnerability > 0.0 or hit.damage <= 0.0 or not world.is_combat():
		return 0.0
	if _is_immune():
		return 0.0
	var amount := _scale_damage(hit)
	var applied := minf(health, amount)
	health = maxf(0.0, health - amount)
	_on_health_changed()
	if brain:
		brain.disturbed()
	_after_hit(hit)
	flash_time = FLASH_DURATION
	if not hit_flash:
		hit_flash = HitFlash.new(visual, _flash_color())
	if health <= 0.0:
		dead = true
		statuses.clear()
		if slow_marker:
			slow_marker.visible = false
		if mark_marker:
			mark_marker.visible = false
		if stagger_marker:
			stagger_marker.visible = false
		if hurtbox:
			hurtbox.set_deferred("collision_layer", 0)
		if hit_flash:
			hit_flash.clear()
		visible = false
		if warning:
			warning.visible = false
	return applied

func _is_immune() -> bool:
	return false

## Incoming damage after resistances; may also start invulnerability frames.
func _scale_damage(hit: CombatHit3D) -> float:
	return hit.damage

## Status effects and knockback applied after health has changed.
func _after_hit(_hit: CombatHit3D) -> void:
	pass

func _flash_color() -> Color:
	return ENEMY_FLASH_COLOR if is_enemy else PLAYER_FLASH_COLOR
