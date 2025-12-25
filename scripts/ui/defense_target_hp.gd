extends Control

## Defense Target HP Bar UI Component
## Displays the HP of the defense target in TECH_DEFENSE mode

@onready var hp_bar: ProgressBar = $MarginContainer/VBoxContainer/HBoxContainer/HPBar
@onready var hp_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/HPLabel
@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel

var is_visible_mode: bool = false

func _ready() -> void:
	# Start hidden
	visible = false
	
	# Connect to events
	Events.defense_target_spawned.connect(_on_target_spawned)
	Events.defense_target_hp_changed.connect(_on_hp_changed)
	Events.defense_target_destroyed.connect(_on_target_destroyed)
	
	# Check if we should be visible at startup
	if GameModeService.should_spawn_defense_target():
		is_visible_mode = true

func _on_target_spawned(_target: Node2D, _position: Vector2) -> void:
	"""Show the HP bar when target spawns."""
	visible = true
	is_visible_mode = true

func _on_hp_changed(current_hp: float, max_hp: float) -> void:
	"""Update the HP bar display."""
	if not is_visible_mode:
		return
	
	# Update progress bar
	hp_bar.max_value = max_hp
	hp_bar.value = current_hp
	
	# Update label
	hp_label.text = "%d / %d" % [int(current_hp), int(max_hp)]
	
	# Color feedback based on HP percentage
	var hp_percent = current_hp / max_hp if max_hp > 0 else 0
	if hp_percent > 0.5:
		hp_bar.modulate = Color(0.2, 0.8, 1.0) # Cyan - healthy
	elif hp_percent > 0.25:
		hp_bar.modulate = Color(1.0, 0.8, 0.2) # Yellow - warning
	else:
		hp_bar.modulate = Color(1.0, 0.3, 0.3) # Red - critical

func _on_target_destroyed() -> void:
	"""Hide the HP bar when target is destroyed."""
	visible = false
	is_visible_mode = false

func reset() -> void:
	"""Reset the component for a new game."""
	visible = false
	is_visible_mode = false
	hp_bar.value = 0
