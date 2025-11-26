extends CanvasLayer

@onready var health_bar: ProgressBar = $MarginContainer/VBoxContainer/TopRow/HealthBar
@onready var wave_label: Label = $MarginContainer/VBoxContainer/TopRow/WaveInfo/WaveLabel
@onready var timer_label: Label = $MarginContainer/VBoxContainer/TopRow/WaveInfo/TimerLabel
@onready var xp_label: Label = $MarginContainer/VBoxContainer/TopRow/StatsContainer/XPLabel
@onready var turret_label: Label = $MarginContainer/VBoxContainer/TopRow/StatsContainer/TurretLabel
@onready var wave_announcement: Control = $WaveAnnouncement
@onready var wave_announcement_label: Label = $WaveAnnouncement/WaveLabel
@onready var game_over_screen: Control = $GameOverScreen
@onready var game_over_title: Label = $GameOverScreen/Panel/VBoxContainer/Title
@onready var stats_label: Label = $GameOverScreen/Panel/VBoxContainer/StatsLabel
@onready var difficulty_screen: Control = $DifficultySelect
@onready var hud_container: MarginContainer = $MarginContainer

var player: Node2D = null

func _ready() -> void:
	# Hide overlays and HUD initially
	wave_announcement.visible = false
	game_over_screen.visible = false
	difficulty_screen.visible = false
	hud_container.visible = false
	
	# Connect to events
	Events.player_damaged.connect(_on_player_damaged)
	Events.wave_timer_updated.connect(_on_wave_timer_updated)
	Events.wave_started.connect(_on_wave_started)
	Events.xp_collected.connect(_on_xp_collected)
	Events.turret_spawned.connect(_on_turret_spawned)
	Events.show_wave_announcement.connect(_on_show_wave_announcement)
	Events.hide_wave_announcement.connect(_on_hide_wave_announcement)
	Events.game_over.connect(_on_game_over)
	Events.show_difficulty_select.connect(_on_show_difficulty_select)
	Events.game_started.connect(_on_game_started)
	
	# Initialize labels
	update_xp(0)
	update_turret_count(0)

func _on_game_started() -> void:
	# Show HUD and get player reference
	hud_container.visible = true
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	if player:
		update_health_bar(player.current_health, player.max_health)

func _on_player_damaged(current_health: float, max_health: float) -> void:
	update_health_bar(current_health, max_health)

func update_health_bar(current: float, maximum: float) -> void:
	if health_bar:
		health_bar.max_value = maximum
		health_bar.value = current
		
		# Color based on health
		var health_percent := current / maximum
		if health_percent > 0.5:
			health_bar.modulate = Color.GREEN
		elif health_percent > 0.25:
			health_bar.modulate = Color.YELLOW
		else:
			health_bar.modulate = Color.RED

func _on_wave_timer_updated(time_remaining: float) -> void:
	if timer_label:
		var minutes := int(time_remaining) / 60
		var seconds := int(time_remaining) % 60
		timer_label.text = "%d:%02d" % [minutes, seconds]

func _on_wave_started(wave_number: int) -> void:
	if wave_label:
		wave_label.text = "Wave %d" % wave_number

func _on_xp_collected(_amount: int, total: int) -> void:
	update_xp(total)

func update_xp(total: int) -> void:
	if xp_label:
		xp_label.text = "XP: %d" % total

func _on_turret_spawned(_turret: Node2D, _position: Vector2) -> void:
	update_turret_count(Globals.turrets_spawned)

func update_turret_count(count: int) -> void:
	if turret_label:
		turret_label.text = "Turrets: %d" % count

func _on_show_wave_announcement(wave_number: int) -> void:
	if wave_announcement and wave_announcement_label:
		wave_announcement_label.text = "Wave %d" % wave_number
		wave_announcement.visible = true
		
		# Animate in
		wave_announcement.modulate.a = 0.0
		wave_announcement.scale = Vector2(0.5, 0.5)
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(wave_announcement, "modulate:a", 1.0, 0.3)
		tween.tween_property(wave_announcement, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _on_hide_wave_announcement() -> void:
	if wave_announcement:
		var tween = create_tween()
		tween.tween_property(wave_announcement, "modulate:a", 0.0, 0.2)
		tween.tween_callback(func(): wave_announcement.visible = false)

func _on_game_over(victory: bool) -> void:
	if game_over_screen and game_over_title and stats_label:
		game_over_title.text = "VICTORY!" if victory else "GAME OVER"
		game_over_title.modulate = Color.GREEN if victory else Color.RED
		
		# Format stats
		var time_minutes := int(Globals.time_survived) / 60
		var time_seconds := int(Globals.time_survived) % 60
		stats_label.text = """Wave Reached: %d
Enemies Killed: %d
XP Collected: %d
Turrets Spawned: %d
Time Survived: %d:%02d""" % [
			Globals.current_wave,
			Globals.total_kills,
			Globals.total_xp,
			Globals.turrets_spawned,
			time_minutes, time_seconds
		]
		
		game_over_screen.visible = true
		game_over_screen.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(game_over_screen, "modulate:a", 1.0, 0.5)

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()

# =============================================================================
# DIFFICULTY SELECTION
# =============================================================================
func _on_show_difficulty_select() -> void:
	difficulty_screen.visible = true
	difficulty_screen.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(difficulty_screen, "modulate:a", 1.0, 0.3)

func _on_easy_pressed() -> void:
	_select_difficulty(Globals.Difficulty.EASY)

func _on_medium_pressed() -> void:
	_select_difficulty(Globals.Difficulty.MEDIUM)

func _on_hard_pressed() -> void:
	_select_difficulty(Globals.Difficulty.HARD)

func _select_difficulty(difficulty: Globals.Difficulty) -> void:
	var tween = create_tween()
	tween.tween_property(difficulty_screen, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func(): 
		difficulty_screen.visible = false
		Events.difficulty_selected.emit(difficulty)
	)
