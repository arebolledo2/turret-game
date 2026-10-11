class_name GameAudio
extends Node3D

## Run-owned mixer. Critical cues have reserved voices; crowds cannot grow the pool.
const GENERAL_VOICES: int = 10
const CRITICAL_VOICES: int = 2
const STREAMS: Dictionary = {
	"ion": preload("res://assets/sounds/game/ion.wav"),
	"plasma": preload("res://assets/sounds/game/plasma.wav"),
	"shock": preload("res://assets/sounds/game/shock.wav"),
	"impact": preload("res://assets/sounds/game/impact.wav"),
	"hull": preload("res://assets/sounds/game/hull.wav"),
	"warning": preload("res://assets/sounds/game/warning.wav"),
	"pickup": preload("res://assets/sounds/game/pickup.wav"),
	"purchase": preload("res://assets/sounds/game/purchase.wav"),
	"wave": preload("res://assets/sounds/game/wave.wav"),
	"victory": preload("res://assets/sounds/game/victory.wav"),
	"defeat": preload("res://assets/sounds/game/defeat.wav")}
const CRITICAL: Array[String] = ["hull", "warning", "wave", "victory", "defeat"]
const INTERVALS: Dictionary = {"ion": .065, "plasma": .12, "shock": .18,
	"impact": .09, "pickup": .10, "warning": .22}
var world: ArenaWorld
var voices: Array[AudioStreamPlayer3D] = []
var remaining: Array[float] = []
var cooldowns: Dictionary = {}

func _exit_tree() -> void:
	# Stop pending physics-boundary playback before native audio resources detach.
	reset()

func _ready() -> void:
	for index in range(GENERAL_VOICES + CRITICAL_VOICES):
		var voice := AudioStreamPlayer3D.new()
		voice.bus = "SFX"
		voice.unit_size = 8.0
		voice.max_distance = 32.0
		voice.max_db = 0.0
		voice.volume_db = -16.0
		add_child(voice)
		voices.append(voice)
		remaining.append(0.0)

func play_cue(cue: String, at: Vector3) -> bool:
	if world.paused or not STREAMS.has(cue) or float(cooldowns.get(cue, 0.0)) > 0.0:
		return false
	var critical := cue in CRITICAL
	var first := GENERAL_VOICES if critical else 0
	var last := voices.size() if critical else GENERAL_VOICES
	var slot: int = -1
	for index in range(first, last):
		if remaining[index] <= 0.0:
			slot = index
			break
	if slot < 0:
		if not critical:
			return false
		# Replace the oldest critical cue only when its reserved pool is saturated.
		slot = first if remaining[first] <= remaining[first + 1] else first + 1
	var voice := voices[slot]
	voice.stop()
	voice.stream = STREAMS[cue]
	voice.position = at
	voice.volume_db = -8.0 if critical else (-22.0 if cue == "impact" else -16.0)
	voice.stream_paused = false
	voice.play()
	remaining[slot] = voice.stream.get_length()
	cooldowns[cue] = float(INTERVALS.get(cue, .08))
	return true

func _process(delta: float) -> void:
	for index in range(voices.size()):
		voices[index].stream_paused = world.paused
		if not world.paused:
			remaining[index] = maxf(0.0, remaining[index] - delta)
	if not world.paused:
		for cue: String in cooldowns:
			cooldowns[cue] = maxf(0.0, float(cooldowns[cue]) - delta)

func on_hit(actor: Node3D, _hit: CombatHit3D, _amount: float) -> void:
	play_cue("impact" if (actor as CombatActor).is_enemy else "hull", actor.position)

func on_explosion(at: Vector3, _radius: float) -> void:
	play_cue("plasma", at)

func on_arc(from: Vector3, _to: Vector3, _hop: int) -> void:
	play_cue("shock", from)

func on_shock(at: Vector3, _radius: float) -> void:
	play_cue("shock", at)

func reset() -> void:
	cooldowns.clear()
	for index in range(voices.size()):
		voices[index].stop()
		voices[index].stream_paused = false
		remaining[index] = 0.0
