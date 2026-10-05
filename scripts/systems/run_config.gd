class_name RunConfig
extends RefCounted

## Everything the start screen, dev panel and tools choose before a run begins.
## `ArenaWorld` reads it once at startup; restarts within the arena reuse it.
## Later phases add game mode, hero and run modifiers here.
var wave_limit: int = GameConstants.RUN_DEFAULT_WAVE_LIMIT
var difficulty: GameEnums.Difficulty = GameEnums.Difficulty.EASY
## `survive` (classic) or `core` (protect the core). Core needs the `mode_protect_core` flag; otherwise the run is survive.
const MODE_SURVIVE: String = "survive"
const MODE_CORE: String = "core"
const MODES: Array[String] = [MODE_SURVIVE, MODE_CORE]
var mode: String = MODE_SURVIVE
## A specific terrain layout id (`--layout=`); empty picks one at random for the run.
var layout_id: String = ""
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
	if mode not in MODES:
		mode = MODE_SURVIVE
	if layout_id != "" and layout_id not in ArenaLayouts.ids():
		layout_id = ""
	return self

## Parses tool arguments: `--waves=N`, `--difficulty=easy|medium|hard|brutal`, `--mode=survive|core`, `--preset=id`.
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
				"brutal": config.difficulty = GameEnums.Difficulty.BRUTAL
		elif arg.begins_with("--layout="):
			config.layout_id = arg.trim_prefix("--layout=").to_lower()
		elif arg.begins_with("--mode="):
			config.mode = arg.trim_prefix("--mode=").to_lower()
		elif arg.begins_with("--preset="):
			config.flag_preset = arg.trim_prefix("--preset=")
	return config.sanitize()
