class_name DecoyForm
extends TurretForm

## Decoy / Bumper Post / Pile Driver / Maelstrom: the turret that cannot be hurt and is everyone's favourite target. One class
## serves the unevolved Decoy and its three forms. It extends the Shock's `FIRE_PULSE` path (`TurretActor` calls `fire_pulse`
## when the cooldown is up and an enemy is within the pulse reach) and adds the two things that make it an aggro turret:
##   Taunt (S1): while fighting it publishes a `TauntPost` to `world.taunts`, and enemies inside the radius walk at it rather
##     than at the hero (see `EnemyActor.chase_position`). Bosses never answer. `ranged_taunt` (Maelstrom) also draws Kites,
##     Lobbers and Tenders. The radius is the stat `taunt_range`, grown by the area multiplier like the pulse.
##   Pulse: a light kinetic pulse that hits every enemy within reach once and shoves it back. Pile Driver makes every
##     `slam_every`th pulse a slam: `slam_damage` times the damage, `slam_radius` times the reach, and a short stagger.
##   Hooks (Maelstrom): enemies inside the taunt radius are hooked (a generic `hooked` timed status owned by this turret), up to
##     `hooks` of them at once. A hooked enemy circles the Decoy on a ring, ignores the hero and takes a light tick
##     (`hook_share` of the pulse damage every `MAELSTROM_TICK_SECONDS`). Hooks last until the enemy dies, and are all let go
##     when combat stops, when the Decoy is picked up or removed, and when the run resets. Another Decoy's hooks are untouched.
## The cost is bounded: the enemy scan runs four times a second over the world list, and the hooked list never exceeds the cap.
const PULSE_WAVE_SPEED: float = 9.0

var post: TauntPost
## Pulses released since this form was created (a slam counts as one); tests and tools read it.
var pulses_released: int = 0
var slams_released: int = 0
## Enemies this Decoy holds a hook on (never more than `hook_cap()`).
var hooked: Array[EnemyActor] = []
var _scan_left: float = 0.0
var _tick_left: float = 0.0

func hook_cap() -> int:
	return int(param("hooks", 0))

func slam_every() -> int:
	return int(param("slam_every", 0))

## The next pulse is a slam (Pile Driver's fourth).
func next_is_slam() -> bool:
	var every := slam_every()
	return every > 0 and (pulses_released + 1) % every == 0

func estimate_dps(stats: TurretStats) -> float:
	var every := slam_every()
	if every > 0:
		var cycle := float(every - 1) + float(param("slam_damage", 1.0))
		return stats.damage * stats.fire_rate * cycle / float(every)
	return super(stats)

# --- Pulse ---

func fire_pulse(stats: TurretStats, range_metres: float, _target: CombatActor) -> void:
	var slam := next_is_slam()
	var radius := range_metres * (float(param("slam_radius", 1.0)) if slam else 1.0)
	var shot := actor._new_shot(stats)
	shot.splash_radius = radius
	if slam:
		shot.damage *= float(param("slam_damage", 1.0))
		shot.stagger_duration = maxf(shot.stagger_duration, float(param("slam_stagger", 0.0)))
		slams_released += 1
	pulses_released += 1
	var world := actor.world
	var combat := world.combat
	for enemy in world.enemies:
		if is_instance_valid(enemy) and not enemy.dead and enemy.overlaps_attack_range(actor.position, radius):
			combat.apply_hit(enemy, combat.hit_from_shot(enemy, actor.position, Vector3(0, 0, -1), shot))
	world.effects.show_wave(actor.position, radius, radius / .3 if not slam else radius / .45, CombatEffects3D.DECOY_TINT)
	world.effects.show_burst(actor.position + Vector3(0, .15, 0), "scrap")
	world.audio.play_cue("plasma" if slam else "impact", actor.position)
	actor._reset_cooldown(stats)

# --- Per tick ---

func tick(delta: float) -> void:
	var stats := actor._current_view(0.0)
	_publish(stats)
	if hook_cap() <= 0:
		return
	if actor.carried:
		_release_hooks()
		return
	_scan_left -= delta
	_tick_left -= delta
	if _scan_left <= 0.0:
		_scan_left = TurretEvolution.MAELSTROM_SCAN_SECONDS
		_scan_for_hooks(stats)
	if _tick_left <= 0.0:
		_tick_left = TurretEvolution.MAELSTROM_TICK_SECONDS
		_tick_hooks(stats)

## Keeps this Decoy's taunt in the world list, with the radius the current stats give it.
func _publish(stats: TurretStats) -> void:
	if not post:
		post = TauntPost.new(actor)
		post.hook_ring = TurretEvolution.MAELSTROM_RING
	if actor.world.taunts.post_of(actor.turret_id) != post:
		actor.world.taunts.publish(post)
	_apply_stats(stats)

func _apply_stats(stats: TurretStats) -> void:
	post.radius = stats.taunt_metres
	post.ranged = bool(param("ranged_taunt", false))

# --- Hooks ---

func _scan_for_hooks(stats: TurretStats) -> void:
	_purge()
	var cap := hook_cap()
	if hooked.size() >= cap:
		return
	var radius := stats.taunt_metres
	var candidates: Array[EnemyActor] = []
	for enemy in actor.world.enemies:
		var hookable := enemy as EnemyActor
		if not hookable or not is_instance_valid(hookable) or hookable.dead or hookable.ignores_hero:
			continue
		if EnemyEcology.taunt_kind(hookable.enemy_type) == EnemyEcology.Taunt.NONE:
			continue
		if hookable.statuses.remaining_for_owner(TauntField.HOOKED, actor.turret_id) > 0.0:
			continue
		if WorldGeometry.planar(hookable.position - actor.position).length_squared() <= radius * radius:
			candidates.append(hookable)
	candidates.sort_custom(func(a: EnemyActor, b: EnemyActor) -> bool:
		return WorldGeometry.planar(a.position - actor.position).length_squared() < WorldGeometry.planar(b.position - actor.position).length_squared())
	for hookable in candidates:
		if hooked.size() >= cap:
			break
		hookable.hook(actor.turret_id)
		hooked.append(hookable)

## A light tick on every hooked enemy. Not kinetic and not a pulse, so shove and slow items do not fire on it.
func _tick_hooks(stats: TurretStats) -> void:
	_purge()
	var amount := stats.damage * float(param("hook_share", 0.0))
	if amount <= 0.0:
		return
	var combat := actor.world.combat
	for enemy in hooked.duplicate():
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		var hit := CombatHit3D.new(amount, actor.position, Vector3.ZERO, TurretRegistry.get_damage_type(actor.turret_type))
		hit.is_dot = true
		hit.source_id = actor.turret_id
		hit.attack_families.assign(["aoe"])
		combat.apply_hit(enemy, hit)
	_purge()

## Forgets enemies that died, were freed or lost this Decoy's hook.
func _purge() -> void:
	for index in range(hooked.size() - 1, -1, -1):
		var enemy := hooked[index]
		if not is_instance_valid(enemy) or enemy.dead or enemy.statuses.remaining_for_owner(TauntField.HOOKED, actor.turret_id) <= 0.0:
			hooked.remove_at(index)

## Lets go of every enemy this Decoy holds, and only those (another Decoy's hook on the same enemy stays).
func _release_hooks() -> void:
	for enemy in hooked:
		if is_instance_valid(enemy):
			enemy.statuses.clear_timed(TauntField.HOOKED, actor.turret_id)
	hooked.clear()

# --- Lifecycle ---

## Combat stopped (wave end, pause, defeat): no taunt, no hooks. Runs every idle frame, so it returns at once when clean.
func clear() -> void:
	if not post and hooked.is_empty():
		return
	_release_hooks()
	if post:
		if is_instance_valid(actor.world):
			actor.world.taunts.withdraw(actor.turret_id)
		post = null
	_scan_left = 0.0
	_tick_left = 0.0

## The turret left the arena or took another form: the same clean-up.
func removed() -> void:
	clear()
