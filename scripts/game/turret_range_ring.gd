class_name TurretRangeRing
extends RefCounted

## Resolved attack range on the ground, shown by the global toggle or when approaching a deployed turret.
var turret: TurretActor
var ring: MeshInstance3D
var metres: float = 0.0

func _init(owner: TurretActor) -> void:
	turret = owner

func update() -> void:
	var world := turret.world
	if not world.show_ranges() or not FeatureFlagService.is_enabled(FeatureFlagService.RANGE_OVERLAY):
		if ring:
			ring.visible = false
		return
	var wanted := turret.effective_range(turret._current_view(0.0))
	if wanted <= 0.0:
		return
	if not ring:
		ring = GroundDial.create(turret, wanted, Color(.4, .95, .9, .65))
	if not is_equal_approx(wanted, metres):
		metres = wanted
		GroundDial.resize(ring, wanted)
	ring.global_position = Vector3(turret.global_position.x, .04, turret.global_position.z)
	ring.visible = true
