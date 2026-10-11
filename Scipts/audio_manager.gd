extends Node

@export var music_bus := &"Music"
@export var sfx_bus := &"SFX"

@export var musicVolume = -10.0

var music_player : AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE := 5

var prev_played = {} #last played per group

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
		create_tween().tween_property(music_player, "volume_db", musicVolume, fade_in)
	else:
		music_player.volume_db = musicVolume
		music_player.play()
		
func stop_music(fade_out := 0.0) -> void:
	if fade_out > 0.0:
		var tween := create_tween()
		tween.tween_property(music_player, "volume_db", -40.0, fade_out)
		tween.tween_callback(music_player.stop)
	else:
		music_player.stop()

func play_sfx(stream: AudioStream, pitch := 1.0, volume_db := 0.0) -> void:
	for p in sfx_players:
		if not p.playing:
			p.stream = stream
			p.pitch_scale = pitch
			p.volume_db = volume_db
			p.play()
			return

func switch_music_synced(new_stream: AudioStream) -> void:
	if music_player.stream == new_stream and music_player.playing:
		return
		
	var pos := 0.0
	if music_player.playing:
		pos = music_player.get_playback_position() + AudioServer.get_time_since_last_mix()
		var length := new_stream.get_length()
		if length > 0.0:
			pos = fmod(pos, length)
			
	music_player.stream = new_stream
	music_player.volume_db = musicVolume
	music_player.play(pos)

func play_sfx_random(streams: Array[AudioStream], pitch_variation:= 0.0, volume_db := 0.0) -> void:
	if streams.is_empty():
		return
	var idx := randi() % streams.size()
	if streams.size() > 1 and prev_played.get(streams, -1) == idx:
		idx = (idx + 1 + randi() % (streams.size() -1)) % streams.size()
	
	prev_played[streams] = idx
	play_sfx(streams[idx], randf_range(1.0 - pitch_variation, 1.0 + pitch_variation), volume_db)
	
	
	
