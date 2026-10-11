extends Control

@export_file("*.tscn") var game_scene: String = "res://highway.tscn"


@export var menu_song: AudioStream
@export var normal_click: AudioStream
@export var play_click: AudioStream
@export var hover_sfx : Array[AudioStream]

@onready var menu_box: VBoxContainer = $MenuBox
@onready var leaderboard_panel: PanelContainer = $LeaderboardPanel
@onready var score_label: Label = $LeaderboardPanel/VBoxContainer/ScoresLabel



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var playButton : Button =  $MenuBox/PlayButton
	var leaderboardButton : Button = $MenuBox/LeaderboardButton
	var backButton : Button = $LeaderboardPanel/VBoxContainer/BackButton
	
	playButton.pressed.connect(_on_play_pressed)
	playButton.mouse_entered.connect(_on_hover)
	playButton.focus_entered.connect(_on_hover)
	
	leaderboardButton.pressed.connect(_on_leaderboard_pressed)
	leaderboardButton.mouse_entered.connect(_on_hover)
	leaderboardButton.focus_entered.connect(_on_hover)
	
	backButton.pressed.connect(_on_back_pressed)
	backButton.mouse_entered.connect(_on_hover)
	backButton.focus_entered.connect(_on_hover)
	
	
	
	
	AudioManager.switch_music_synced(menu_song)



func _on_play_pressed() -> void:
	AudioManager.play_sfx(play_click)
	get_tree().change_scene_to_file(game_scene)

func _on_leaderboard_pressed() -> void:
	score_label.text = build_scores_text()
	menu_box.hide()
	leaderboard_panel.show()
	AudioManager.play_sfx(normal_click)
	

func build_scores_text() -> String:
	if Leaderboard.entries.is_empty():
		return "No Times Yet"
	var lines := []
	for i in Leaderboard.entries.size():
		var entry = Leaderboard.entries[i]
		lines.append("%2d.  %-3s  %s" % [i + 1, entry.name, format_ms(entry.time_ms)])
	return "\n".join(lines)
		
		
func format_ms(ms: int) ->String:
	return "%02d:%02d.%03d" % [ms / 60000, (ms / 1000) % 60, ms % 1000]

func _on_back_pressed() -> void:
	leaderboard_panel.hide()
	menu_box.show()
	AudioManager.play_sfx(normal_click)

func _on_hover() -> void:
	AudioManager.play_sfx_random(hover_sfx, 0.0, -5.0)
