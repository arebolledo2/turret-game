extends Control

## Tunnel Door Progress UI Component
## Displays breach progress for TUNNELING modes

@onready var progress_bar: ProgressBar = $MarginContainer/VBoxContainer/HBoxContainer/ProgressBar
@onready var progress_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/ProgressLabel
@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var alert_indicator: Label = $MarginContainer/VBoxContainer/AlertIndicator

var is_visible_mode: bool = false
var is_alert_active: bool = false
var alert_time: float = 0.0

func _ready() -> void:
	# Start hidden
	visible = false
	alert_indicator.visible = false
	
	# Connect to events
	Events.tunnel_door_spawned.connect(_on_door_spawned)
	Events.tunnel_door_progress_changed.connect(_on_progress_changed)
	Events.tunnel_door_breached.connect(_on_door_breached)
	Events.wave_started.connect(_on_wave_started)
	
	# Check if we should be visible at startup
	if GameModeService.should_spawn_tunnel_door():
		is_visible_mode = true

func _process(delta: float) -> void:
	if not is_visible_mode or not visible:
		return
	
	# Check for alert mode (TUNNELING_ALERT only)
	if GameModeService.is_alert_mode_active():
		_update_alert_mode(delta)

func _on_door_spawned(_door: Node2D, _position: Vector2) -> void:
	"""Show the progress bar when door spawns."""
	visible = true
	is_visible_mode = true

func _on_wave_started(_wave: int) -> void:
	"""Reset alert timer when wave starts."""
	alert_time = 0.0
	is_alert_active = false
	alert_indicator.visible = false

func _on_progress_changed(current_hp: float, max_hp: float) -> void:
	"""Update the progress display (inverse: HP down = progress up)."""
	if not is_visible_mode:
		return
	
	var progress = 1.0 - (current_hp / max_hp) if max_hp > 0 else 0.0
	
	# Update progress bar (0-100%)
	progress_bar.max_value = 100.0
	progress_bar.value = progress * 100.0
	
	# Update label
	progress_label.text = "%d%%" % int(progress * 100.0)
	
	# Color feedback
	if progress >= 0.75:
		progress_bar.modulate = Color(0.2, 1.0, 0.3) # Green - almost done
	elif progress >= 0.5:
		progress_bar.modulate = Color(0.8, 0.8, 0.2) # Yellow - halfway
	else:
		progress_bar.modulate = Color(1.0, 0.5, 0.2) # Orange - just started

func _update_alert_mode(delta: float) -> void:
	"""Handle alert mode UI updates for TUNNELING_ALERT."""
	if not FeatureFlagService.is_enabled(FeatureFlagService.TUNNEL_ALERT_ESCALATION):
		is_alert_active = false
		alert_indicator.visible = false
		return

	alert_time += delta
	var spawn_multiplier := GameModeService.get_spawn_rate_multiplier(alert_time)
	if spawn_multiplier > 1.0 and not is_alert_active:
		is_alert_active = true
		alert_indicator.visible = true
		alert_indicator.text = "ALERT x%.1f" % spawn_multiplier
	# Flash the alert indicator
	if is_alert_active:
		var flash = sin(Time.get_ticks_msec() / 200.0) * 0.5 + 0.5
		alert_indicator.modulate = Color(1.0, 0.3, 0.3, flash)
		alert_indicator.text = "ALERT x%.1f" % spawn_multiplier

func _on_door_breached() -> void:
	"""Hide the progress bar when door is breached."""
	visible = false
	is_visible_mode = false
	is_alert_active = false
	alert_indicator.visible = false

func reset() -> void:
	"""Reset the component for a new game."""
	visible = false
	is_visible_mode = false
	is_alert_active = false
	alert_time = 0.0
	progress_bar.value = 0
	alert_indicator.visible = false
