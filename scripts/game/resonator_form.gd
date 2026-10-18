class_name ResonatorForm
extends TurretForm

## Shock / Resonator: each pulse queues echoes; the final form alternates inner and outer rings and Exposes enemies caught by both.
## Queued echoes are [time_left, damage_scale, radius_scale].
var echoes: Array = []
var outer_next: bool = false
var clock: float = 0.0
## Enemy instance id -> [inner ring time, outer ring time].
var marks: Dictionary = {}

func clear() -> void:
	echoes.clear()

func fire_pulse(stats: TurretStats, range_metres: float, _target: CombatActor) -> void:
	fire(stats, range_metres)

func fire(stats: TurretStats, range_metres: float) -> void:
	var stage := actor.progression.evolution_stage
	var damage_scale := 1.0
	var radius_scale := 1.0
	if stage >= 3:
		var outer := outer_next
		outer_next = not outer
		damage_scale = 1.0 if outer else TurretEvolution.ENGINE_INNER_DAMAGE
		radius_scale = TurretEvolution.ENGINE_OUTER_RADIUS if outer else TurretEvolution.ENGINE_INNER_RADIUS
		_mark(range_metres * radius_scale, outer)
	_pulse(stats, range_metres * radius_scale, damage_scale)
	for delay: float in TurretEvolution.RESONATOR_ECHO_DELAYS[stage - 1]:
		echoes.append([delay, damage_scale * TurretEvolution.RESONATOR_ECHO_DAMAGE, radius_scale])
	actor._reset_cooldown(stats)

func _pulse(stats: TurretStats, radius: float, damage_scale: float) -> void:
	var pulse := actor._new_shot(stats)
	pulse.damage *= damage_scale
	pulse.splash_radius = radius
	actor.world.combat.impact(null, actor.position, Vector3.ZERO, pulse, actor.world.enemies)

## Records which ring struck each enemy; one struck by both kinds inside the window becomes Exposed.
func _mark(radius: float, outer: bool) -> void:
	for id: int in marks.keys():
		var pair: Array = marks[id]
		if clock - maxf(pair[0], pair[1]) > TurretEvolution.ENGINE_EXPOSE_WINDOW:
			marks.erase(id)
	var slot := 1 if outer else 0
	for enemy: CombatActor in actor.world.enemies:
		if not is_instance_valid(enemy) or enemy.dead or not enemy.overlaps_attack_range(actor.position, radius):
			continue
		var pair: Array = marks.get(enemy.get_instance_id(), [-INF, -INF])
		pair[slot] = clock
		marks[enemy.get_instance_id()] = pair
		if clock - pair[1 - slot] <= TurretEvolution.ENGINE_EXPOSE_WINDOW:
			enemy.statuses.expose(TurretEvolution.ENGINE_EXPOSE_DURATION)

func tick(delta: float) -> void:
	clock += delta
	if echoes.is_empty():
		return
	var stats := actor._current_view(0.0)
	var due: Array = []
	for echo: Array in echoes:
		echo[0] -= delta
		if echo[0] <= 0.0:
			due.append(echo)
	for echo: Array in due:
		echoes.erase(echo)
		_pulse(stats, actor.effective_range(stats) * echo[2], echo[1])
