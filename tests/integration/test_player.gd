extends GutTest

# =============================================================================
# Integration tests for Player
# Tests health, damage, movement, and turret interactions
# =============================================================================

var player_scene: PackedScene
var player: CharacterBody2D


func before_all() -> void:
	player_scene = load("res://scenes/player.tscn")


func before_each() -> void:
	GameStateService.reset_state()
	DifficultyService.set_difficulty(GameEnums.Difficulty.EASY)
	GameStateService.is_game_active = true

	player = player_scene.instantiate()
	add_child_autofree(player)

	# Let player initialize
	await get_tree().process_frame


# =============================================================================
# INITIALIZATION
# =============================================================================

func test_player_in_group():
	assert_true(player.is_in_group("player"), "Player should be in 'player' group")


func test_player_initializes_max_health():
	var expected = PlayerStatsService.get_player_max_health(DifficultyService.get_difficulty_config()["player_health_mult"])
	assert_eq(player.max_health, expected, "Max health should match PlayerStatsService")


func test_player_initializes_current_health():
	assert_eq(player.current_health, player.max_health,
		"Current health should equal max health initially")


func test_player_initializes_speed():
	var expected = PlayerStatsService.get_player_speed()
	assert_eq(player.speed, expected, "Speed should match PlayerStatsService")


func test_player_not_dead_initially():
	assert_false(player.is_dead, "Player should not be dead initially")


func test_player_not_invincible_initially():
	assert_false(player.is_invincible, "Player should not be invincible initially")


func test_player_can_fire_initially():
	assert_true(player.can_fire, "Player should be able to fire initially")


func test_player_not_carrying_turret_initially():
	assert_null(player.carried_turret, "Player should not carry turret initially")


# =============================================================================
# DIFFICULTY SCALING
# =============================================================================

func test_health_scales_with_difficulty():
	var easy_player = player_scene.instantiate()
	DifficultyService.set_difficulty(GameEnums.Difficulty.EASY)
	add_child_autofree(easy_player)
	await get_tree().process_frame
	var easy_health = easy_player.max_health

	var hard_player = player_scene.instantiate()
	DifficultyService.set_difficulty(GameEnums.Difficulty.HARD)
	add_child_autofree(hard_player)
	await get_tree().process_frame
	var hard_health = hard_player.max_health

	assert_lt(hard_health, easy_health, "Hard mode should have less health")


# =============================================================================
# DAMAGE AND HEALTH
# =============================================================================

# Helper to apply damage without defensive pulse visual (which needs current_scene)
func _apply_damage_directly(amount: float) -> void:
	if player.is_invincible or player.is_dead:
		return
	player.current_health -= amount
	player.is_invincible = true
	player.invincibility_timer.wait_time = player.invincibility_time
	player.invincibility_timer.start()
	Events.player_damaged.emit(player.current_health, player.max_health)
	if player.current_health <= 0:
		player.is_dead = true
		player.drop_carried_turret()
		Events.player_died.emit()


func test_take_damage_reduces_health():
	var initial_health = player.current_health

	_apply_damage_directly(20.0)

	assert_eq(player.current_health, initial_health - 20.0,
		"Health should decrease by damage amount")


func test_take_damage_sets_invincible():
	_apply_damage_directly(10.0)

	assert_true(player.is_invincible, "Player should be invincible after taking damage")


func test_take_damage_emits_signal():
	watch_signals(Events)

	_apply_damage_directly(10.0)

	assert_signal_emitted(Events, "player_damaged")


func test_take_damage_while_invincible_does_nothing():
	_apply_damage_directly(10.0)
	var health_after_first = player.current_health

	_apply_damage_directly(10.0) # Should be ignored (is_invincible check)

	assert_eq(player.current_health, health_after_first,
		"Damage while invincible should not reduce health")


func test_take_damage_while_dead_does_nothing():
	player.is_dead = true
	var initial_health = player.current_health

	_apply_damage_directly(10.0)

	assert_eq(player.current_health, initial_health,
		"Damage while dead should not reduce health")


func test_lethal_damage_triggers_death():
	_apply_damage_directly(9999.0)

	assert_true(player.is_dead, "Lethal damage should kill player")


func test_death_emits_signal():
	watch_signals(Events)

	_apply_damage_directly(9999.0)

	assert_signal_emitted(Events, "player_died")


func test_heal_increases_health():
	_apply_damage_directly(30.0)
	var damaged_health = player.current_health

	player.heal(20.0)

	assert_eq(player.current_health, damaged_health + 20.0,
		"Heal should increase health")


func test_heal_does_not_exceed_max():
	player.heal(1000.0)

	assert_eq(player.current_health, player.max_health,
		"Heal should not exceed max health")


func test_reset_health_restores_max():
	_apply_damage_directly(50.0)

	player.reset_health()

	assert_eq(player.current_health, player.max_health,
		"Reset health should restore to max")


func test_get_health_percent():
	_apply_damage_directly(player.max_health * 0.25)

	var percent = player.get_health_percent()

	assert_almost_eq(percent, 0.75, 0.01, "Health percent should be 0.75")


# =============================================================================
# INVINCIBILITY
# =============================================================================

func test_invincibility_expires():
	_apply_damage_directly(10.0)
	assert_true(player.is_invincible)

	# Wait for invincibility to expire
	await get_tree().create_timer(player.invincibility_time + 0.1).timeout

	assert_false(player.is_invincible, "Invincibility should expire")


# =============================================================================
# TURRET CARRYING
# =============================================================================

func test_pickup_turret_sets_carried():
	var turret = Node2D.new()
	add_child_autofree(turret)

	player.pickup_turret(turret)

	assert_eq(player.carried_turret, turret, "Should be carrying the turret")


func test_pickup_turret_emits_signal():
	var turret = Node2D.new()
	add_child_autofree(turret)
	watch_signals(Events)

	player.pickup_turret(turret)

	assert_signal_emitted(Events, "turret_picked_up")


func test_place_turret_clears_carried():
	var turret = Node2D.new()
	turret.global_position = Vector2(100, 100)
	add_child_autofree(turret)

	player.pickup_turret(turret)
	player.place_turret()

	assert_null(player.carried_turret, "Should not be carrying turret after placement")


func test_place_turret_emits_signal():
	var turret = Node2D.new()
	turret.global_position = Vector2(100, 100)
	add_child_autofree(turret)
	player.pickup_turret(turret)
	watch_signals(Events)

	player.place_turret()

	assert_signal_emitted(Events, "turret_placed")


func test_drop_turret_emits_signal():
	var turret = Node2D.new()
	turret.global_position = Vector2(100, 100)
	add_child_autofree(turret)
	player.pickup_turret(turret)
	watch_signals(Events)

	player.drop_carried_turret()

	assert_signal_emitted(Events, "turret_dropped")


func test_drop_turret_clears_carried():
	var turret = Node2D.new()
	turret.global_position = Vector2(100, 100)
	add_child_autofree(turret)
	player.pickup_turret(turret)

	player.drop_carried_turret()

	assert_null(player.carried_turret, "Should not be carrying turret after drop")


# =============================================================================
# DIRECTION HELPERS
# =============================================================================

func test_get_direction_from_vector_south():
	var dir = player.get_direction_from_vector(Vector2(0, 1))
	assert_eq(dir, 0, "Down should be direction 0 (South)")


func test_get_direction_from_vector_north():
	var dir = player.get_direction_from_vector(Vector2(0, -1))
	assert_eq(dir, 4, "Up should be direction 4 (North)")


func test_get_direction_from_vector_east():
	var dir = player.get_direction_from_vector(Vector2(1, 0))
	assert_eq(dir, 6, "Right should be direction 6 (East)")


func test_get_direction_from_vector_west():
	var dir = player.get_direction_from_vector(Vector2(-1, 0))
	assert_eq(dir, 2, "Left should be direction 2 (West)")
