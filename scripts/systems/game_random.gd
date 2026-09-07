class_name GameRandom
extends RefCounted

## Independent streams: rendering and audio must never change gameplay rolls.
## Consumers can inject a different RandomNumberGenerator for isolated scenarios.
static var gameplay: RandomNumberGenerator = RandomNumberGenerator.new()
static var cosmetic: RandomNumberGenerator = RandomNumberGenerator.new()

static func reset(run_seed: int) -> void:
	gameplay.seed = run_seed
	cosmetic.seed = run_seed ^ 0x5EED
