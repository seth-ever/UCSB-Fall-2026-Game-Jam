extends CanvasLayer


signal race_started
signal race_finished(final_time : float)

@export var race_music : AudioStream
@export var beep_sfx : AudioStream
@export var go_sfx : AudioStream
@export var win_sfx : AudioStream

@onready var countdown_label : Label = $StartCountDownLabel
@onready var timer_label : Label = $RaceTimerLabel

@onready var name_panel: PanelContainer = $NameEntryPanel
@onready var name_edit: LineEdit = $NameEntryPanel/VBoxContainer/NameEdit
@onready var submit_button: Button = $NameEntryPanel/VBoxContainer/SubmitButton

@onready var default_panel: PanelContainer = $DefaultPanel
@onready var return_button: Button = $DefaultPanel/VBoxContainer/ReturnButton

@onready var pause_panel: PanelContainer = $PausePanel
@onready var resume_button : Button = $PausePanel/VBoxContainer/ResumeButton
@onready var p_return_button: Button = $PausePanel/VBoxContainer/ReturnButton

var race_running : bool = false
var time_elapsed : float = 0.0
var final_time   : float = 0.0

var paused : bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	timer_label.text = format_time(0.0)
	
	start_countdown()
	
	name_edit.max_length = 3
	name_edit.text_changed.connect(on_name_change)
	submit_button.pressed.connect(on_submit)
	name_edit.text_submitted.connect(func(_t): on_submit())
	
	return_button.pressed.connect(return_to_menu)
	p_return_button.pressed.connect(return_to_menu)
	resume_button.pressed.connect(show_pause)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if race_running:
		time_elapsed += delta
		timer_label.text = format_time(time_elapsed)


func start_countdown() -> void:
	AudioManager.play_sfx(beep_sfx)
	for n in [3, 2, 1]:
		countdown_label.text = str(n)
		#Add play for countdown sfx
		await get_tree().create_timer(1.0).timeout
	countdown_label.text = "ACCELERATE!"
	AudioManager.switch_music_synced(race_music)
	race_running = true
	race_started.emit()
	await get_tree().create_timer(0.8).timeout
	countdown_label.hide()

func finish_race() -> void:
	if not race_running:
		return
	race_running = false
	race_finished.emit(time_elapsed)

func show_name_entry(time_ms: int) -> void:
	AudioManager.play_sfx(win_sfx)
	final_time = time_ms
	name_panel.show()
	name_edit.grab_focus()

func on_name_change(new_text: String) -> void:
	var caret := name_edit.caret_column
	name_edit.text = new_text.to_upper()
	name_edit.caret_column = caret

func on_submit() -> void:
	var player_name := name_edit.text.strip_edges()
	if player_name.is_empty():
		player_name = "STW"
	Leaderboard.add_entry(player_name, final_time)
	name_panel.hide()
	get_tree().change_scene_to_file("res://main_menu.tscn")

func format_time(t : float) -> String:
	var minutes : int = int(t / 60.0)
	var seconds : int = int(t) % 60
	var millis  : int = int((t - int(t)) * 1000.0)
	return "%02d:%02d.%02d" % [minutes, seconds, millis / 10]

func show_return() -> void:
	default_panel.show()
	return_button.grab_focus()
	
func return_to_menu() -> void:
	default_panel.hide()
	pause_panel.hide()
	Engine.time_scale = 1
	get_tree().change_scene_to_file("res://main_menu.tscn")

func show_pause() -> void:
	if paused:
		pause_panel.hide()
		Engine.time_scale = 1
	else:
		pause_panel.show()
		Engine.time_scale = 0
		
	
	paused = !paused
		
		
