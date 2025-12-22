class_name HUDGameDisplay
extends Node

## Manages in-game HUD elements (health, wave, gold, xp)
## Extracted from hud.gd to reduce file size

var health_bar: ProgressBar
var health_label: Label
var wave_label: Label
var timer_label: Label
var xp_label: Label
var gold_label: Label
var turret_label: Label

func initialize(nodes: Dictionary) -> void:
	health_bar = nodes.get("health_bar")
	health_label = nodes.get("health_label")
	wave_label = nodes.get("wave_label")
	timer_label = nodes.get("timer_label")
	xp_label = nodes.get("xp_label")
	gold_label = nodes.get("gold_label")
	turret_label = nodes.get("turret_label")

func update_health_bar(current: float, maximum: float) -> void:
	if health_bar:
		health_bar.max_value = maximum
		health_bar.value = current
	if health_label:
		health_label.text = "%d / %d" % [int(current), int(maximum)]

func update_wave_timer(time_remaining: float) -> void:
	if timer_label:
		var minutes := int(time_remaining) / 60
		var seconds := int(time_remaining) % 60
		timer_label.text = "%d:%02d" % [minutes, seconds]

func update_wave_number(wave_number: int) -> void:
	if wave_label:
		wave_label.text = "Wave %d" % wave_number

func update_xp(total: int) -> void:
	if xp_label:
		xp_label.text = "XP: %d" % total

func update_gold(total: int) -> void:
	if gold_label:
		gold_label.text = "Gold: %d" % total

func update_turret_count(count: int) -> void:
	if turret_label:
		turret_label.text = "Turrets: %d" % count
