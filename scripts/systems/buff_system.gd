extends Node

## Manages temporary buffs on turrets (e.g., for Chain Reaction item)
## Uses Path of Exile-style modifier operations:
##   - "add": Flat value added to base
##   - "increase": Percentage modifier (stacks additively)
##   - "more": Multiplicative modifier (each stacks independently)

class Buff:
	var stat: String
	var value: float
	var operation: String  # "add", "increase", or "more"
	var duration: float
	var time_remaining: float
	var stack_count: int = 1
	var max_stacks: int = 1

	func _init(s: String, v: float, op: String, dur: float, max_stack: int = 1) -> void:
		stat = s
		value = v
		operation = op
		duration = dur
		time_remaining = dur
		max_stacks = max_stack

# turret_instance_id -> Array[Buff]
var state: RunSessionState = RunSessionState.new()
var active_buffs: Dictionary:
	get: return state.active_buffs
	set(value): state.active_buffs = value

func reset_state() -> void:
	active_buffs.clear()


func apply_buff(turret: Node, buff: Buff) -> void:
	var turret_id = turret.get_instance_id()
	if not active_buffs.has(turret_id):
		active_buffs[turret_id] = []

	# Check for existing buff of same type
	var existing = _find_matching_buff(turret_id, buff.stat)
	if existing:
		# Stack if not at max
		if existing.stack_count < existing.max_stacks:
			existing.stack_count += 1
		# Always refresh duration when reapplying
		existing.time_remaining = buff.duration
	else:
		active_buffs[turret_id].append(buff)

	# Trigger stat update
	if turret.has_method("update_stats"):
		turret.update_stats()

func _find_matching_buff(turret_id: int, stat: String) -> Buff:
	if not active_buffs.has(turret_id):
		return null

	for buff in active_buffs[turret_id]:
		if buff.stat == stat:
			return buff
	return null

func _process(delta: float) -> void:
	var turrets_to_update: Array[int] = []

	for turret_id in active_buffs.keys():
		var buffs = active_buffs[turret_id]
		for i in range(buffs.size() - 1, -1, -1):
			buffs[i].time_remaining -= delta
			if buffs[i].time_remaining <= 0:
				buffs.remove_at(i)
				# Mark turret for stat update
				if turret_id not in turrets_to_update:
					turrets_to_update.append(turret_id)

		# Clean up empty arrays
		if buffs.is_empty():
			active_buffs.erase(turret_id)

	# Update stats for turrets that had buffs expire
	for turret_id in turrets_to_update:
		var turret = instance_from_id(turret_id)
		if turret and is_instance_valid(turret) and turret.has_method("update_stats"):
			turret.update_stats()

## Get total flat (add) value from active buffs for a turret's stat
func get_buff_flat(turret: Node, stat: String) -> float:
	var turret_id = turret.get_instance_id()
	if not active_buffs.has(turret_id):
		return 0.0

	var total_flat := 0.0
	for buff in active_buffs[turret_id]:
		if buff.stat == stat and buff.operation == "add":
			total_flat += buff.value * buff.stack_count

	return total_flat


## Get total increase value from active buffs for a turret's stat
## Returns the sum of all increase percentages (to be used as: 1 + increase_total)
func get_buff_increase(turret: Node, stat: String) -> float:
	var turret_id = turret.get_instance_id()
	if not active_buffs.has(turret_id):
		return 0.0

	var total_increase := 0.0
	for buff in active_buffs[turret_id]:
		if buff.stat == stat and buff.operation == "increase":
			total_increase += buff.value * buff.stack_count

	return total_increase


## Get combined "more" multiplier from active buffs for a turret's stat
## Each "more" buff multiplies independently (PoE style)
func get_buff_more_multiplier(turret: Node, stat: String) -> float:
	var turret_id = turret.get_instance_id()
	if not active_buffs.has(turret_id):
		return 1.0

	var total_mult := 1.0
	for buff in active_buffs[turret_id]:
		if buff.stat == stat and buff.operation == "more":
			# Stack multiplier: (1.08)^stack_count for Chain Reaction
			var stack_mult = pow(buff.value, buff.stack_count)
			total_mult *= stack_mult

	return total_mult


## Legacy compatibility: Get total additive value (alias for get_buff_flat)
func get_buff_add_value(turret: Node, stat: String) -> float:
	return get_buff_flat(turret, stat)


## Legacy compatibility: Get total multiplier (now returns "more" multiplier)
func get_buff_multiplier(turret: Node, stat: String) -> float:
	return get_buff_more_multiplier(turret, stat)
