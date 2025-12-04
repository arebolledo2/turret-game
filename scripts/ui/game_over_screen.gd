class_name GameOverScreenUI
extends RefCounted

## Handles game over / victory screen display

var container: Control
var title_label: Label
var stats_label: Label
var restart_button: Button
var _owner: Node


func setup(nodes: Dictionary, owner: Node) -> void:
	container = nodes.get("container")
	title_label = nodes.get("title")
	stats_label = nodes.get("stats")
	restart_button = nodes.get("restart_button")
	_owner = owner


func show_game_over(victory: bool) -> void:
	if not container or not title_label or not stats_label:
		return

	# Set title based on victory/defeat
	title_label.text = "VICTORY!" if victory else "GAME OVER"
	title_label.modulate = Color.GREEN if victory else Color.RED

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

	# Show with fade animation
	container.visible = true
	container.modulate.a = 0.0
	var tween = _owner.create_tween()
	tween.tween_property(container, "modulate:a", 1.0, 0.5)

	if restart_button:
		restart_button.grab_focus()


func hide() -> void:
	if container:
		container.visible = false
