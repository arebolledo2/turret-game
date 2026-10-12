class_name TurretEntrench
extends RefCounted

## Entrench for one turret: seconds deployed at its current spot grant damage and fire rate stacks.
## Shop items retune the rules through modifier stats; they are resolved lazily and dropped whenever modifiers change.
var turret: TurretActor
var stay_time: float = 0.0
var stacks: int = 0
var notice: float = 0.0
var ring: MeshInstance3D
var _config: Dictionary = {}

func _init(owner: TurretActor) -> void:
	turret = owner

func invalidate() -> void:
	_config = {}

func settings() -> Dictionary:
	if _config.is_empty():
		_config = {
			"seconds": maxf(.5, ModifierService.apply_modifiers_to_stat(GameConstants.ENTRENCH_STACK_SECONDS, "entrench_stack_seconds")),
			"max": maxi(0, roundi(ModifierService.apply_modifiers_to_stat(float(GameConstants.ENTRENCH_MAX_STACKS), "entrench_max_stacks"))),
			"bonus": maxf(0.0, ModifierService.apply_modifiers_to_stat(1.0, "entrench_bonus")),
		}
	return _config

func max_stacks() -> int:
	return int(settings()["max"])

func stack_seconds() -> float:
	return float(settings()["seconds"]) / (1.0 + turret.terrain.entrench_bonus)

## Fractional damage / fire rate granted by the current stacks (before shop modifiers, which apply to the base stat).
func damage_bonus() -> float:
	return GameConstants.ENTRENCH_DAMAGE_PER_STACK * float(stacks) * float(settings()["bonus"])

func fire_rate_bonus() -> float:
	return GameConstants.ENTRENCH_FIRE_RATE_PER_STACK * float(stacks) * float(settings()["bonus"])

## Stacks earned by the time spent so far; zero while the feature is off.
func earned_stacks() -> int:
	if not FeatureFlagService.is_enabled(FeatureFlagService.ENTRENCH):
		return 0
	return mini(int(stay_time / stack_seconds()), max_stacks())

func reset() -> void:
	stay_time = 0.0
	turret.terrain.refresh()
	stacks = 0
	turret.cached_stats = {}
	update_ring()

## Fraction (0..1) toward the next stack; 1 when maxed.
func progress() -> float:
	if stacks >= max_stacks():
		return 1.0
	var seconds := stack_seconds()
	return fmod(stay_time, seconds) / seconds

func tick(delta: float) -> void:
	notice = maxf(0.0, notice - delta)
	if FeatureFlagService.is_enabled(FeatureFlagService.ENTRENCH):
		stay_time += delta
	elif stay_time > 0.0:
		stay_time = 0.0
	var earned := earned_stacks()
	if earned != stacks:
		if earned > stacks:
			notice = .65
		stacks = earned
		turret.cached_stats = {}
	update_ring()

func update_ring() -> void:
	if not ring:
		ring = GroundDial.create(turret, .72, Color("e9b969"), true)
		ring.position.y = .03
	var mode := SettingsService.ground_markers
	var world := turret.world
	var inspecting := is_instance_valid(world) and is_instance_valid(world.player) and turret.position.distance_to(world.player.position) < TurretPlacement.PICKUP_RANGE
	var contextual := inspecting or notice > 0.0
	ring.visible = stacks > 0 and not turret.carried and (mode == SettingsService.GroundMarkers.ALL or (mode == SettingsService.GroundMarkers.CONTEXTUAL and contextual))
	var fill := (float(stacks) + (progress() if stacks < max_stacks() else 0.0)) / float(maxi(max_stacks(), 1))
	GroundDial.update(ring, fill, false, max_stacks())
