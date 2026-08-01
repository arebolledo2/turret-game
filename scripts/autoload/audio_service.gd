extends Node

# AudioService - Manages sound effects and music
# Automatically handles sound playback in response to game events

const HIT_SOUND_SMALL_PATH = "res://assets/sounds/robot_hit_small.mp3"
const HIT_SOUND_LARGE_PATH = "res://assets/sounds/robot_hit_large.mp3"
var hit_sound_small: AudioStream = null
var hit_sound_large: AudioStream = null

var sfx_pool: Array[AudioStreamPlayer2D] = []
var max_pool_size: int = 16

# Spatial audio settings
const MAX_SOUND_DISTANCE = 1500.0
const ATTENUATION_FALLOFF = 2.0

func _ready() -> void:
	# Load sounds - using ResourceLoader for better safety
	if ResourceLoader.exists(HIT_SOUND_SMALL_PATH):
		hit_sound_small = load(HIT_SOUND_SMALL_PATH) as AudioStream
	else:
		DebugService.warn(DebugService.SYSTEMS, "AudioService: Failed to load ", HIT_SOUND_SMALL_PATH)

	if ResourceLoader.exists(HIT_SOUND_LARGE_PATH):
		hit_sound_large = load(HIT_SOUND_LARGE_PATH) as AudioStream
	else:
		DebugService.warn(DebugService.SYSTEMS, "AudioService: Failed to load ", HIT_SOUND_LARGE_PATH)
	
	# Initialize pool of audio players
	for i in range(max_pool_size):
		var player = AudioStreamPlayer2D.new()
		player.max_distance = MAX_SOUND_DISTANCE
		player.attenuation = ATTENUATION_FALLOFF
		add_child(player)
		sfx_pool.append(player)
	
	# Connect to relevant events
	_connect_signals()

func _connect_signals() -> void:
	if not Events.damage_dealt.is_connected(_on_damage_dealt):
		Events.damage_dealt.connect(_on_damage_dealt)

func _on_damage_dealt(_position: Vector2, _amount: float, is_crit: bool, enemy: Node2D) -> void:
	# Determine which hit sound to play based on enemy rank
	var sound_to_play: AudioStream = null
	
	if enemy and enemy.has_method("get") and "enemy_rank" in enemy:
		var rank = enemy.enemy_rank
		# Use large sound for lieutenants and captains, small sound for normal enemies
		if rank == GameEnums.EnemyRank.LIEUTENANT or rank == GameEnums.EnemyRank.CAPTAIN:
			sound_to_play = hit_sound_large
		else:
			sound_to_play = hit_sound_small
	else:
		# Default to small sound if no enemy info available
		sound_to_play = hit_sound_small
	
	if sound_to_play:
		play_sfx(sound_to_play, _position, 1.08 if is_crit else 1.0)

func play_sfx(stream: AudioStream, pos: Vector2 = Vector2.ZERO, base_pitch: float = 1.0) -> void:
	if not stream:
		return
		
	# Find an available player
	var player = _get_available_player()
	if player:
		player.stream = stream
		player.global_position = pos
		# Small pitch variation keeps repeated impacts from sounding identical.
		player.pitch_scale = clampf(base_pitch * randf_range(0.94, 1.06), 0.75, 1.25)
		player.play()

func _get_available_player() -> AudioStreamPlayer2D:
	# First pass: find a player that isn't playing
	for player in sfx_pool:
		if not player.playing:
			return player
	
	# Second pass: reuse the player with the longest elapsed time (or just the first one for now)
	# Potential improvement: track which player was started longest ago
	return sfx_pool[0]
