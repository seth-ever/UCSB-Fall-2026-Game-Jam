extends CanvasLayer


signal race_started
signal race_finished(final_time : float)

@onready var countdown_label : Label = $StartCountDownLabel
@onready var timer_label : Label = $RaceTimerLabel

var race_running : bool = false
var time_elapsed : float = 0.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	timer_label.text = format_time(0.0)
	start_countdown()
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if race_running:
		time_elapsed += delta
		timer_label.text = format_time(time_elapsed)


func start_countdown() -> void:
	for n in [3, 2, 1]:
		countdown_label.text = str(n)
		await get_tree().create_timer(1.0).timeout
	countdown_label.text = "ACCELERATE!"
	race_running = true
	race_started.emit()
	await get_tree().create_timer(0.8).timeout
	countdown_label.hide()

func finish_race() -> void:
	if not race_running:
		return
	race_running = false
	race_finished.emit(time_elapsed)

func format_time(t : float) -> String:
	var minutes : int = int(t / 60.0)
	var seconds : int = int(t) % 60
	var millis  : int = int((t - int(t)) * 1000.0)
	return "%02d:%02d.%02d" % [minutes, seconds, millis / 10]
