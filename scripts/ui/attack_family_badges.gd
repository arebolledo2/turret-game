class_name AttackFamilyBadges
extends HFlowContainer

## Uses the same overlapping families as item eligibility, not legacy turret categories.
const STYLES: Dictionary = {
	"projectile": ["Projectile", "turret_normal", "range"],
	"aoe": ["AoE", "turret_plasma", "dmg"],
	"instant": ["Instant", "damage", "rate"],
	"kinetic": ["Kinetic", "turret_melee", "slow"],
}
var shown_type: String = ""

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("h_separation", 8)
	add_theme_constant_override("v_separation", 6)

func show_turret(type_id: String) -> void:
	if type_id == shown_type:
		return
	shown_type = type_id
	for child in get_children():
		remove_child(child)
		child.queue_free()
	visible = not type_id.is_empty()
	if type_id.is_empty():
		return
	for family in TurretRegistry.get_attack_families(type_id):
		var style: Array = STYLES[family]
		var chip := StatChip.new().setup(style[1], style[0], style[2])
		chip.label.theme_type_variation = &""
		# Badges inside offer buttons must not intercept clicks or controller focus.
		for child in chip.get_children():
			if child is Control:
				child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(chip)
