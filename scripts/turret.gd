extends Node2D

@export var turret_type: String = "normal"

# Stats cache
var stats: Dictionary = {}
var current_damage: float = 0.0
var current_range: float = 0.0
var current_fire_rate: float = 0.0
var current_rotation_speed: float = 0.0

# Components
@onready var combat: TurretCombat = $Components/TurretCombat
@onready var visuals: TurretVisuals = $Components/TurretVisuals

func _ready() -> void:
	add_to_group("turrets")

	# Initialize stats
	update_stats()

	# Initialize components (must be done in _ready when @onready vars are available)
	_initialize_components()

func _initialize_components() -> void:
	"""Initialize all components with their dependencies."""
	# Safety check - ensure components are loaded
	if not combat or not visuals:
		push_error("Turret components not found! Ensure Components node structure exists in scene.")
		return

	# Initialize combat component
	combat.initialize(self, turret_type, stats)

	# Initialize visuals component
	visuals.initialize(self, turret_type, stats)


func update_stats() -> void:
	"""Update turret stats from registry and apply modifiers."""
	stats = Globals.get_turret_stats(turret_type)

	# Apply proximity-based modifiers from items
	_apply_proximity_modifiers()

	current_damage = stats.get("damage", 15.0)
	current_range = stats.get("range", 250.0)
	current_fire_rate = stats.get("fire_rate", 2.0)
	current_rotation_speed = stats.get("rotation_speed", 180.0)

	# Ensure slow parameters are in stats if they exist in base stats
	var base_stats = TurretRegistry.get_base_stats(turret_type)
	if base_stats.has("slow_intensity") and not stats.has("slow_intensity"):
		stats["slow_intensity"] = base_stats["slow_intensity"]
	if base_stats.has("slow_duration") and not stats.has("slow_duration"):
		stats["slow_duration"] = base_stats["slow_duration"]

	# Update components with new stats
	if combat:
		combat.update_stats(stats)
	if visuals:
		visuals.update_stats(stats)

func _apply_proximity_modifiers() -> void:
	var turret_manager = Globals.turret_manager
	if not turret_manager:
		return

	# Signal Amplifier: +15% range if clustered, -10% fire rate if isolated
	if ItemRegistry.has_special_effect("signal_amplifier") and Globals.item_counts.get("signal_amplifier", 0) > 0:
		var nearby = turret_manager.get_turrets_within_radius(global_position, 200.0)
		if nearby.size() > 0:
			# Clustered: +15% range
			stats["range"] = stats.get("range", 0.0) * 1.15
		else:
			# Isolated: -10% fire rate
			stats["fire_rate"] = stats.get("fire_rate", 1.0) * 0.90

	# Isolation Protocol: +40% damage if isolated, -15% damage if clustered
	if ItemRegistry.has_special_effect("isolation_protocol") and Globals.item_counts.get("isolation_protocol", 0) > 0:
		var stacks = Globals.item_counts.get("isolation_protocol", 0)
		var nearby = turret_manager.get_turrets_within_radius(global_position, 250.0)
		if nearby.size() == 0:
			# Isolated: +40% damage per stack
			var damage_mult = 1.0 + (0.40 * stacks)
			stats["damage"] = stats.get("damage", 0.0) * damage_mult
		else:
			# Clustered: -15% damage per stack
			var damage_mult = 1.0 - (0.15 * stacks)
			stats["damage"] = stats.get("damage", 0.0) * damage_mult

	# Feedback Loop: +6% fire rate per nearby turret (max +30%)
	if ItemRegistry.has_special_effect("feedback_loop") and Globals.item_counts.get("feedback_loop", 0) > 0:
		var nearby = turret_manager.get_turrets_within_radius(global_position, 180.0)
		var fire_rate_bonus = min(nearby.size() * 0.06, 0.30)
		stats["fire_rate"] = stats.get("fire_rate", 1.0) * (1.0 + fire_rate_bonus)

	# Apply temporary buffs from Chain Reaction
	if BuffSystem:
		var fire_rate_buff = BuffSystem.get_buff_multiplier(self, "fire_rate")
		stats["fire_rate"] = stats.get("fire_rate", 1.0) * fire_rate_buff

func _physics_process(_delta: float) -> void:
	"""Main turret update loop."""
	# Y-based depth sorting (offset by 1000 to handle negative Y values)
	z_index = int(global_position.y) + 1000

	if combat:
		combat.process()

# =============================================================================
# DELEGATED METHODS - Facades for components (test compatibility)
# =============================================================================

func find_target() -> void:
	"""Find target (facade for tests)."""
	if combat:
		combat.find_target()

func find_tracking_target() -> Node2D:
	"""Find tracking target (facade for tests)."""
	if combat:
		return combat.find_tracking_target()
	return null

func fire() -> void:
	"""Fire at target (facade for tests)."""
	if combat:
		combat.fire()

func _fire_projectile() -> void:
	"""Fire projectile (facade for tests)."""
	if combat:
		combat._fire_projectile()

func _fire_instant() -> void:
	"""Fire instant (facade for tests)."""
	if combat:
		combat._fire_instant()

func _fire_aoe_pulse() -> void:
	"""Fire AOE pulse (facade for tests)."""
	if combat:
		combat._fire_aoe_pulse()

func _fire_chain() -> void:
	"""Fire chain lightning (facade for tests)."""
	if combat:
		combat._fire_chain()

func flash_muzzle() -> void:
	"""Flash the sprite when firing (called by combat component)."""
	if visuals:
		visuals.flash_muzzle()

func show_pickup_indicator() -> void:
	"""Show visual indicator that turret is in pickup range."""
	if visuals:
		visuals.show_pickup_indicator()

func hide_pickup_indicator() -> void:
	"""Hide visual indicator that turret is in pickup range."""
	if visuals:
		visuals.hide_pickup_indicator()

func show_range() -> void:
	"""Show range indicator."""
	if visuals:
		visuals.show_range()

func hide_range() -> void:
	"""Hide range indicator."""
	if visuals:
		visuals.hide_range()

# Property facades for external access
var target: Node2D:
	get:
		return combat.target if combat else null

var can_fire: bool:
	get:
		return combat.can_fire if combat else true
	set(value):
		if combat:
			combat.can_fire = value

var fire_timer: Timer:
	get:
		return combat.fire_timer if combat else null

var is_in_pickup_range: bool:
	get:
		return visuals.is_in_pickup_range if visuals else false
	set(value):
		if visuals:
			visuals.is_in_pickup_range = value
