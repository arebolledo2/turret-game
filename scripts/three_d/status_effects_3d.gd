class_name StatusEffects3D
extends RefCounted

## Uses the shared status lifetime/refresh rules without the Node2D event bus.
var effects: Dictionary = {}

func apply(hit: CombatHit3D) -> void:
	if hit.slow_intensity <= 0.0 or hit.slow_duration <= 0.0:
		return
	var intensity := clampf(hit.slow_intensity, 0.0, .9)
	if effects.has(hit.damage_type):
		effects[hit.damage_type].refresh(0.0, hit.slow_duration, intensity)
	else:
		effects[hit.damage_type] = StatusEffect.new(hit.damage_type, 0.0, hit.slow_duration, 1.0, intensity)

func advance(delta: float) -> void:
	for type in effects.keys():
		var effect: StatusEffect = effects[type]
		effect.process(delta)
		if effect.is_expired():
			effects.erase(type)

func speed_multiplier() -> float:
	var strongest: float = 0.0
	for effect: StatusEffect in effects.values():
		strongest = maxf(strongest, effect.slow_intensity)
	return 1.0 - strongest

func clear() -> void:
	effects.clear()
