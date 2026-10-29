class_name OverwatchForm
extends TurretForm

## Sniper / Overwatch: each shot marks the toughest enemies in range (see `TurretEvolution.OVERWATCH_MARK_COUNT`). A Marked
## enemy takes extra damage from every turret (`StatusEffects3D.MARKED_BONUS`). When a marked enemy dies, its mark jumps
## to the next toughest unmarked enemy in range and keeps the time it had left, so chain kills cannot stretch the window.
## The timer lives on the enemy's statuses (it clears on death, wave end and pause there), keyed by this turret's id, so
## another Overwatch's mark on the same enemy is never cleared by this one; this form only tracks which enemies it marked. Entries are [enemy, seconds remaining as last seen].
var marks: Array = []

## Marked enemies that are still alive.
func marked_enemies() -> Array[CombatActor]:
	var result: Array[CombatActor] = []
	for entry: Array in marks:
		if is_instance_valid(entry[0]) and not entry[0].dead:
			result.append(entry[0])
	return result

## Marks the toughest enemies now, before the shot, so the shot itself lands on a Marked target.
func before_instant(_stats: TurretStats, range_metres: float) -> void:
	var desired := TurretTargeting.toughest_many(actor.position, range_metres, actor.world.enemies, TurretEvolution.OVERWATCH_MARK_COUNT)
	var kept: Array = []
	for entry: Array in marks:
		if not is_instance_valid(entry[0]):
			continue
		if desired.has(entry[0]):
			kept.append(entry)
		else:
			entry[0].statuses.unmark(actor.turret_id)
	marks = kept
	for enemy in desired:
		enemy.statuses.mark(TurretEvolution.OVERWATCH_MARK_SECONDS, actor.turret_id)
		var existing := marks.filter(func(entry: Array) -> bool: return entry[0] == enemy)
		if existing.is_empty():
			marks.append([enemy, TurretEvolution.OVERWATCH_MARK_SECONDS])
		else:
			existing[0][1] = TurretEvolution.OVERWATCH_MARK_SECONDS

func tick(_delta: float) -> void:
	if marks.is_empty():
		return
	var alive: Array = []
	var jumping: Array[float] = []
	for entry: Array in marks:
		var enemy: Variant = entry[0]
		if not is_instance_valid(enemy) or enemy.dead:
			if float(entry[1]) > 0.0:
				jumping.append(float(entry[1]))
		elif enemy.statuses.marked_remaining_for(actor.turret_id) > 0.0:
			entry[1] = enemy.statuses.marked_remaining_for(actor.turret_id)
			alive.append(entry)
	marks = alive
	if jumping.is_empty():
		return
	var range_metres := actor.effective_range(actor._current_view(0.0))
	for remaining in jumping:
		var next := TurretTargeting.toughest_many(actor.position, range_metres, actor.world.enemies, 1, marked_enemies())
		if next.is_empty():
			break
		next[0].statuses.mark(remaining, actor.turret_id)
		marks.append([next[0], remaining])

## Combat stopped (wave end, pause, defeat): drop every mark this turret placed.
func clear() -> void:
	for entry: Array in marks:
		if is_instance_valid(entry[0]):
			entry[0].statuses.unmark(actor.turret_id)
	marks.clear()
