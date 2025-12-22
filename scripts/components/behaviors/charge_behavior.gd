class_name ChargeBehavior
extends EnemyBehavior

## Charge behavior - enemy wanders until player is close, shows alert, then charges in straight line
## Uses a state machine with four states: IDLE, ALERT, CHARGING, COOLDOWN

## Charge state machine
enum ChargeState { IDLE, ALERT, CHARGING, COOLDOWN }
var charge_state: ChargeState = ChargeState.IDLE
var charge_timer: float = 0.0
var charge_target_pos: Vector2 = Vector2.ZERO
var charge_direction: Vector2 = Vector2.ZERO
var charge_alert_indicator: Node2D = null

## Wander behavior for when not charging (reuse wander logic)
var wander_behavior: WanderBehavior = null

## Get default parameters for charge behavior
static func get_default_params() -> Dictionary:
	var defaults = WanderBehavior.get_default_params()
	defaults.merge({
		"charge_detect_radius": 200.0,
		"charge_alert_duration": 0.9,
		"charge_speed_multiplier": 3.0,
		"charge_duration": 1.5,
		"charge_cooldown": 2.5,
	})
	return defaults

## Initialize charge behavior
func _init(enemy_ref: CharacterBody2D, behavior_params: Dictionary = {}) -> void:
	super._init(enemy_ref, behavior_params)
	# Create wander behavior for IDLE and COOLDOWN states
	wander_behavior = WanderBehavior.new(enemy_ref, behavior_params)

## Called when behavior is activated
func enter() -> void:
	charge_state = ChargeState.IDLE
	charge_timer = 0.0
	if wander_behavior:
		wander_behavior.enter()

## Called when behavior is deactivated
func exit() -> void:
	_cleanup_alert_indicator()
	if wander_behavior:
		wander_behavior.exit()

## Execute charge behavior
func execute(delta: float) -> Vector2:
	var detect_radius: float = params.get("charge_detect_radius", get_default_params()["charge_detect_radius"])

	charge_timer -= delta

	match charge_state:
		ChargeState.IDLE:
			var player = enemy.get_tree().get_first_node_in_group("player")
			if player and is_instance_valid(player):
				var dist := enemy.global_position.distance_to(player.global_position)
				if dist <= detect_radius:
					_enter_alert_state()
			return wander_behavior.execute(delta)

		ChargeState.ALERT:
			if charge_timer <= 0:
				_enter_charging_state()
			# Stand still during alert (return zero movement)
			return Vector2.ZERO

		ChargeState.CHARGING:
			if charge_timer <= 0:
				_enter_cooldown_state()
			return charge_direction

		ChargeState.COOLDOWN:
			if charge_timer <= 0:
				charge_state = ChargeState.IDLE
			return wander_behavior.execute(delta)

	return Vector2.ZERO

## Enter alert state - show visual indicator above head
func _enter_alert_state() -> void:
	charge_state = ChargeState.ALERT
	charge_timer = params.get("charge_alert_duration", get_default_params()["charge_alert_duration"])
	_spawn_charge_alert_indicator()

## Enter charging state - lock direction toward player position
func _enter_charging_state() -> void:
	charge_state = ChargeState.CHARGING
	charge_timer = params.get("charge_duration", get_default_params()["charge_duration"])

	var player = enemy.get_tree().get_first_node_in_group("player")
	if player and is_instance_valid(player):
		charge_target_pos = player.global_position
		charge_direction = enemy.global_position.direction_to(charge_target_pos)
	else:
		# If player disappeared, charge in random direction
		charge_direction = Vector2.RIGHT.rotated(randf() * TAU)

	_cleanup_alert_indicator()

## Enter cooldown state before returning to idle
func _enter_cooldown_state() -> void:
	charge_state = ChargeState.COOLDOWN
	charge_timer = params.get("charge_cooldown", get_default_params()["charge_cooldown"])

## Create visual alert indicator above enemy head
func _spawn_charge_alert_indicator() -> void:
	var alert_scene := preload("res://scenes/spawn_alert.tscn")
	charge_alert_indicator = alert_scene.instantiate()
	charge_alert_indicator.position = Vector2(0, -40)

	# Yellow/orange color for charge alert
	if charge_alert_indicator.has_node("OuterCircle"):
		charge_alert_indicator.get_node("OuterCircle").color = Color(1.0, 0.8, 0.0)
	if charge_alert_indicator.has_node("InnerCircle"):
		charge_alert_indicator.get_node("InnerCircle").color = Color(1.0, 0.9, 0.3)

	enemy.add_child(charge_alert_indicator)

## Clean up alert indicator
func _cleanup_alert_indicator() -> void:
	if charge_alert_indicator:
		charge_alert_indicator.queue_free()
		charge_alert_indicator = null

## Check if currently in charging state (used by enemy for speed boost)
func is_charging() -> bool:
	return charge_state == ChargeState.CHARGING

## Get speed multiplier for charging state (used by enemy)
func get_speed_multiplier() -> float:
	if is_charging():
		return params.get("charge_speed_multiplier", get_default_params()["charge_speed_multiplier"])
	return 1.0
