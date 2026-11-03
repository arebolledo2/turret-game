class_name HeroPanel
extends VBoxContainer

## The hero's level, XP and form, shown in the shop sidebar. Evolutions are taken in the popup after each wave, not here.
var title: Label
var xp_bar: TurretXpBar
var detail: Label

func _init() -> void:
	add_theme_constant_override("separation", 8)
	title = UiBuilder.label(self, "", 26, UiPalette.INK, true)
	xp_bar = TurretXpBar.new()
	add_child(xp_bar)
	detail = UiBuilder.label(self, "", 21, UiPalette.MUTED, true)

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
