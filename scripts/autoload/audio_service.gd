extends Node

# AudioService - Manages sound effects and music
# Automatically handles sound playback in response to game events

const HIT_SOUND_PATH = "res://assets/sounds/hit_sound.mp3"
var hit_sound: AudioStream = null

var sfx_pool: Array[AudioStreamPlayer] = []
var max_pool_size: int = 16

func _ready() -> void:
	# Load sounds - using ResourceLoader for better safety
	if ResourceLoader.exists(HIT_SOUND_PATH):
		# We check if it can actually be loaded to avoid "no loader found" errors
		# in CLI environments where assets haven't been imported yet.
		hit_sound = load(HIT_SOUND_PATH) as AudioStream
	
	# Initialize pool of audio players
	for i in range(max_pool_size):
		var player = AudioStreamPlayer.new()
		add_child(player)
		sfx_pool.append(player)
	
	# Connect to relevant events
	_connect_signals()

func _connect_signals() -> void:
	if not Events.damage_dealt.is_connected(_on_damage_dealt):
		Events.damage_dealt.connect(_on_damage_dealt)

func _on_damage_dealt(_position: Vector2, _amount: float, _is_crit: bool) -> void:
	if hit_sound:
		play_sfx(hit_sound)

func play_sfx(stream: AudioStream) -> void:
	if not stream:
		return
		
	# Find an available player
	var player = _get_available_player()
	if player:
		player.stream = stream
		player.play()

func _get_available_player() -> AudioStreamPlayer:
	# First pass: find a player that isn't playing
	for player in sfx_pool:
		if not player.playing:
			return player
	
	# Second pass: reuse the player with the longest elapsed time (or just the first one for now)
	# Potential improvement: track which player was started longest ago
	return sfx_pool[0]
