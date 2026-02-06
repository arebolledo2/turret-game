class_name TestHelpers
extends RefCounted

## Test Helpers for Turret Game
## Provides mock factories and test utilities for isolated unit testing

# =============================================================================
# MOCK ENEMY FACTORY
# =============================================================================

## Create a minimal mock enemy for testing projectile damage
static func create_mock_enemy(health: float = 100.0) -> Node2D:
	var enemy = Node2D.new()
	enemy.set_meta("current_health", health)
	enemy.set_meta("max_health", health)
	enemy.add_to_group("enemies")

	# Add script with test methods
	var script = GDScript.new()
	script.source_code = """
extends Node2D

var current_health: float = 100.0
var max_health: float = 100.0
var damage_taken: float = 0.0
var last_crit: bool = false
var status_effects: Array = []
var knockback_applied: Vector2 = Vector2.ZERO

func take_damage(amount: float, is_crit: bool = false) -> void:
	damage_taken += amount
	last_crit = is_crit
	current_health -= amount

func get_health_percent() -> float:
	if max_health <= 0:
		return 1.0
	return current_health / max_health

func apply_status_effect(dtype: int, dot_dmg: float, duration: float, tick_rate: float) -> void:
	status_effects.append({
		"damage_type": dtype,
		"dot_damage": dot_dmg,
		"duration": duration,
		"tick_rate": tick_rate
	})

func apply_knockback(force: float, direction: Vector2) -> void:
	knockback_applied = direction * force
"""
	script.reload()
	enemy.set_script(script)
	enemy.current_health = health
	enemy.max_health = health
	return enemy


## Create a mock enemy at low health (for Executioner's Mark testing)
static func create_low_health_enemy(current: float = 20.0, max_hp: float = 100.0) -> Node2D:
	var enemy = create_mock_enemy(max_hp)
	enemy.current_health = current
	return enemy


# =============================================================================
# MOCK PLAYER FACTORY
# =============================================================================

## Create a minimal mock player for testing
static func create_mock_player(health: float = 100.0) -> Node2D:
	var player = Node2D.new()
	player.add_to_group("player")

	var script = GDScript.new()
	script.source_code = """
extends Node2D

var current_health: float = 100.0
var max_health: float = 100.0
var damage_taken: float = 0.0

func take_damage(amount: float) -> void:
	damage_taken += amount
	current_health -= amount
"""
	script.reload()
	player.set_script(script)
	player.current_health = health
	player.max_health = health
	return player


# =============================================================================
# MOCK TURRET FACTORY
# =============================================================================

## Create a minimal mock turret for testing
static func create_mock_turret(turret_type: String = "normal") -> Node2D:
	var turret = Node2D.new()
	turret.set_meta("turret_type", turret_type)
	turret.add_to_group("turrets")
	return turret


# =============================================================================
# MOCK HURTBOX FACTORY
# =============================================================================

## Create a mock enemy hurtbox (Area2D in enemy_hurtbox group)
static func create_mock_enemy_hurtbox(enemy: Node2D) -> Area2D:
	var hurtbox = Area2D.new()
	hurtbox.add_to_group("enemy_hurtbox")
	enemy.add_child(hurtbox)
	return hurtbox


## Create a mock player hurtbox
static func create_mock_player_hurtbox(player: Node2D) -> Area2D:
	var hurtbox = Area2D.new()
	hurtbox.add_to_group("player_hurtbox")
	player.add_child(hurtbox)
	return hurtbox


# =============================================================================
# SERVICE STATE HELPERS
# =============================================================================

## Reset all service states for clean testing
## Call this in before_each() to ensure test isolation
static func reset_all_services() -> void:
	# Core game state
	GameStateService.reset_state()
	EconomyService.reset_state()
	DifficultyService.reset_state()
	GameModeService.reset_state()
	SettingsService.reset_state()

	# Player & combat
	PlayerStatsService.reset_state()
	TurretStatsService.reset_state()
	ModifierService.clear_modifiers()
	BuffSystem.active_buffs.clear()

	# Economy & progression
	ItemTrackingService.reset_state()
	TechTreeService.reset_state()
	LootService.reset_state()

	# Presentation
	OffScreenIndicatorService.tracked_entities.clear()


# =============================================================================
# ASSERTION HELPERS
# =============================================================================

## Assert that a value is approximately equal (for float comparisons)
static func assert_approx_eq(actual: float, expected: float, epsilon: float = 0.001) -> bool:
	return abs(actual - expected) < epsilon


## Assert that damage was dealt to a mock enemy
static func get_damage_taken(enemy: Node2D) -> float:
	if enemy.has_method("get") and "damage_taken" in enemy:
		return enemy.damage_taken
	return 0.0
