class_name RunConfig
extends RefCounted

## Everything the start screen, dev panel and tools choose before a run begins.
## `ArenaWorld` reads it once at startup; restarts within the arena reuse it.
## Later phases add game mode, hero and run modifiers here.
var wave_limit: int = GameConstants.RUN_DEFAULT_WAVE_LIMIT
var difficulty: GameEnums.Difficulty = GameEnums.Difficulty.EASY
## Flag preset applied when the arena starts. Empty keeps the current flags.
var flag_preset: String = ""

## The original six-wave slice, kept for regression tools and tests.
static func slice() -> RunConfig:
	var config := RunConfig.new()
	config.wave_limit = 6
	return config

func difficulty_config() -> Dictionary:
	return DifficultyService.DIFFICULTY_CONFIG[difficulty].duplicate()

func difficulty_name() -> String:
	return str(DifficultyService.DIFFICULTY_CONFIG[difficulty]["name"])

## Clamps values so a bad command-line argument cannot produce an unplayable run.
func sanitize() -> RunConfig:
	wave_limit = clampi(wave_limit, 1, GameConstants.RUN_MAX_WAVE_LIMIT)
	if flag_preset != "" and flag_preset not in FeatureFlagService.PRESETS:
		flag_preset = ""
	return self

## Parses tool arguments: `--waves=N`, `--difficulty=easy|medium|hard`, `--preset=id`.
static func from_args(args: PackedStringArray) -> RunConfig:
	var config := RunConfig.new()
	for arg in args:
		if arg.begins_with("--waves="):
			config.wave_limit = arg.trim_prefix("--waves=").to_int()
		elif arg.begins_with("--difficulty="):
			match arg.trim_prefix("--difficulty=").to_lower():
				"easy": config.difficulty = GameEnums.Difficulty.EASY
				"medium": config.difficulty = GameEnums.Difficulty.MEDIUM
				"hard": config.difficulty = GameEnums.Difficulty.HARD
		elif arg.begins_with("--preset="):
			config.flag_preset = arg.trim_prefix("--preset=")
	return config.sanitize()
