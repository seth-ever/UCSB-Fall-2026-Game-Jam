extends Control

@export_file("*.tscn") var game_scene: String = "res://highway.tscn"

@onready var menu_box: VBoxContainer = $MenuBox
@onready var leaderboard_panel: PanelContainer = $LeaderboardPanel
@onready var score_label: Label = $LeaderboardPanel/VBoxContainer/ScoresLabel



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$MenuBox/PlayButton.pressed.connect(_on_play_pressed)
	$MenuBox/LeaderboardButton.pressed.connect(_on_leaderboard_pressed)
	$LeaderboardPanel/VBoxContainer/BackButton.pressed.connect(_on_back_pressed)
	pass # Replace with function body.




func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(game_scene)

func _on_leaderboard_pressed() -> void:
	score_label.text = build_scores_text()
	menu_box.hide()
	leaderboard_panel.show()
	

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
