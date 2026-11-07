class_name HeroPanel
extends VBoxContainer

## The hero's level, XP and form, shown in the shop sidebar; XP and growth multipliers are in the tooltip.
## Evolutions are taken in the popup after each wave, not here.
var title: Label
var xp_bar: TurretXpBar

func _init() -> void:
	add_theme_constant_override("separation", 8)
	mouse_filter = Control.MOUSE_FILTER_PASS
	title = UiBuilder.label(self, "", 26, UiPalette.INK, true)
	xp_bar = TurretXpBar.new()
	xp_bar.custom_minimum_size.y = 6
	add_child(xp_bar)

func refresh() -> void:
	var growth: HeroProgression = PlayerStatsService.state.hero_progression
	visible = PlayerStatsService.state.turret_progression_enabled
	if not visible:
		return
	var form := HeroForms.row(growth.evolution_form)
	title.text = "Hero · Lv %d%s" % [growth.level, " · " + str(form.name) if not form.is_empty() else ""]
	xp_bar.show_progress(growth.level, growth.xp)
	var multipliers := growth.stat_multipliers()
	tooltip_text = "%d / %d XP from collected scrap\nHull %+d%% · Damage %+d%% · Speed %+d%%" % [
		growth.xp, HeroProgression.cost_to_next(growth.level), roundi((multipliers.health - 1.0) * 100.0),
		roundi((multipliers.damage - 1.0) * 100.0), roundi((multipliers.fire_rate - 1.0) * 100.0)]
