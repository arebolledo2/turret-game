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
	# Safety check - ensure components are loaded (skip error if in unit tests without scene tree)
	if not has_node("Components/TurretCombat") or not has_node("Components/TurretVisuals"):
		# Only error if we are supposed to have these (i.e. not in a bare unit test)
		if get_tree() and get_tree().current_scene:
			DebugService.error(DebugService.VALIDATION, "Turret components not found! Ensure Components node structure exists in scene.")
		return

	# Re-assign if null (handles cases where @onready missed them or script was added dynamically)
	if not combat: combat = $Components/TurretCombat
	if not visuals: visuals = $Components/TurretVisuals

	# Initialize combat component
	combat.initialize(self, turret_type, stats)

	# Initialize visuals component
	visuals.initialize(self, turret_type, stats)


func update_stats() -> void:
	"""Update turret stats from registry and apply modifiers."""
	var old_fire_rate = current_fire_rate

	var damage_mult = DifficultyService.get_difficulty_config()["turret_damage_mult"]
	stats = TurretStatsService.get_turret_stats(turret_type, damage_mult)

	# Apply proximity-based modifiers from items
	_apply_proximity_modifiers()

	current_damage = stats.get("damage", 15.0)
	current_range = stats.get("range", 250.0)
	current_fire_rate = stats.get("fire_rate", 2.0)
	current_rotation_speed = stats.get("rotation_speed", 180.0)

	# Show visual feedback if fire rate increased significantly
	if old_fire_rate > 0 and current_fire_rate > old_fire_rate * 1.05:
		_show_stat_boost_effect()

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
	SpecialEffectService.apply_instance_effects(self, stats)

func _show_stat_boost_effect() -> void:
	"""Brief visual effect indicating stat boost."""
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.15)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15)

func _physics_process(_delta: float) -> void:
	"""Main turret update loop."""
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
	set(value):
		if combat:
			combat.target = value

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
