extends Node

const SAVE_PATH := "user://leaderboard.json"
const MAX_ENTRIES := 3

var entries: Array = []


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	load_entries()


func qualifies(time_ms: int) -> bool:
	return entries.size() < MAX_ENTRIES or time_ms < entries[-1].time_ms

func add_entry(player_name: String, time_ms: int) -> void:
	entries.append({"name": player_name, "time_ms": time_ms})
	entries.sort_custom(func(a,b): return a.time_ms < b.time_ms)
	
	if entries.size() > MAX_ENTRIES:
		entries.resize(MAX_ENTRIES)
	save_entries()

func save_entries() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Could not save leaderboard")
		return
	f.store_string(JSON.stringify(entries))
	f.close()

func load_entries() -> void:
	entries.clear()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	if data is Array:
		for entry in data:
			entries.append({ "name": str(entry.name), "time_ms": int(entry.time_ms)})
