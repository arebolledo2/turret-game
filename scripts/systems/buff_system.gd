extends Node

## Manages temporary buffs on turrets (e.g., for Chain Reaction item)

class Buff:
	var stat: String
	var value: float
	var operation: String  # "add" or "multiply"
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
var active_buffs: Dictionary = {}

func _ready() -> void:
	# Listen for Chain Reaction triggers
	Events.turret_fired.connect(_on_turret_fired)

func _on_turret_fired(turret: Node2D) -> void:
	# Chain Reaction: When a turret fires, turrets within 150px +8% fire rate for 2s (stacks 5x)
	if not ItemRegistry.has_special_effect("chain_reaction"):
		return
	if Globals.item_counts.get("chain_reaction", 0) == 0:
		return

	var turret_manager = Globals.turret_manager
	if not turret_manager:
		return

	# Get turrets within 150px of the firing turret
	var nearby = turret_manager.get_turrets_within_radius(turret.global_position, 150.0)

	# Apply buff to nearby turrets
	for nearby_turret in nearby:
		if is_instance_valid(nearby_turret):
			var buff = Buff.new("fire_rate", 1.08, "multiply", 2.0, 5)
			apply_buff(nearby_turret, buff)

func apply_buff(turret: Node2D, buff: Buff) -> void:
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

## Get total multiplier from active buffs for a turret's stat
func get_buff_multiplier(turret: Node2D, stat: String) -> float:
	var turret_id = turret.get_instance_id()
	if not active_buffs.has(turret_id):
		return 1.0

	var total_mult := 1.0
	for buff in active_buffs[turret_id]:
		if buff.stat == stat and buff.operation == "multiply":
			# Stack multiplier: (1.08)^stack_count for Chain Reaction
			var stack_mult = pow(buff.value, buff.stack_count)
			total_mult *= stack_mult

	return total_mult

## Get total additive value from active buffs for a turret's stat
func get_buff_add_value(turret: Node2D, stat: String) -> float:
	var turret_id = turret.get_instance_id()
	if not active_buffs.has(turret_id):
		return 0.0

	var total_add := 0.0
	for buff in active_buffs[turret_id]:
		if buff.stat == stat and buff.operation == "add":
			total_add += buff.value * buff.stack_count

	return total_add
