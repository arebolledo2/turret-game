class_name HeroPanel
extends VBoxContainer

## The hero's level, XP and ready evolutions, shown in the shop sidebar. Evolving happens here, like a turret's inspector.
signal evolved

var world: ArenaWorld
var title: Label
var xp_bar: TurretXpBar
var detail: Label
var choices: VBoxContainer

func _init() -> void:
	add_theme_constant_override("separation", 8)
	title = UiBuilder.label(self, "", 26, UiPalette.INK, true)
	xp_bar = TurretXpBar.new()
	add_child(xp_bar)
	detail = UiBuilder.label(self, "", 21, UiPalette.MUTED, true)
	choices = VBoxContainer.new()
	choices.add_theme_constant_override("separation", 6)
	add_child(choices)

func refresh() -> void:
	var growth: HeroProgression = PlayerStatsService.state.hero_progression
	visible = PlayerStatsService.state.turret_progression_enabled
	if not visible:
		return
	var form := HeroForms.row(growth.evolution_form)
	title.text = "Hero - level %d%s" % [growth.level, " - " + str(form.name) if not form.is_empty() else ""]
	xp_bar.show_progress(growth.level, growth.xp)
	var multipliers := growth.stat_multipliers()
	detail.text = "%d/%d XP from collected scrap · hull x%.2f · damage x%.2f · speed x%.2f" % [
		growth.xp, HeroProgression.cost_to_next(growth.level),
		multipliers.health, multipliers.damage, multipliers.fire_rate]
	for child in choices.get_children():
		child.queue_free()
	for form_id in growth.evolution_options():
		var option := HeroForms.row(form_id)
		var button := Button.new()
		button.text = "Evolve: %s - %s" % [option.name, option.description]
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size.y = 56
		button.pressed.connect(_evolve.bind(form_id))
		choices.add_child(button)

func _evolve(form_id: String) -> void:
	if world.evolve_hero(form_id):
		evolved.emit()
