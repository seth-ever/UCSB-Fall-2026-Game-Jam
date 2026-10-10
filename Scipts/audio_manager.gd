extends Node

@export var music_bus := &"Music"
@export var sfx_bus := &"SFX"

var music_player : AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE := 5


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.bus = music_bus
	add_child(music_player)
	
	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = sfx_bus
		add_child(p)
		sfx_players.append(p)
	
	


func play_music(stream: AudioStream, fade_in := 0.0) -> void:
	music_player.stream = stream
	if fade_in > 0.0:
		music_player.volume_db = -40.0
		music_player.play()
		create_tween().tween_property(music_player, "volume_db", 0.0, fade_in)
	else:
		music_player.volume_db = -10.0
		music_player.play()
		
func stop_music(fade_out := 0.0) -> void:
	if fade_out > 0.0:
		var tween := create_tween()
		tween.tween_property(music_player, "volume_db", -40.0, fade_out)
		tween.tween_callback(music_player.stop)
	else:
		music_player.stop()
