extends Node3D

@export var ramp_time : float = 0.6

@onready var _lights: Array[SpotLight3D] = [
	$lightcone/YellowLight,
	$lightcone/WhiteLight,
]

var _target_energies: Array[float] = []


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for light in _lights:
		_target_energies.append(light.light_energy)
		light.light_energy = 0.0

func turn_on() -> void:
	for i in _lights.size():
		var tween := create_tween()
		tween.tween_property(_lights[i], "light_energy", _target_energies[i], ramp_time)


func turn_off() -> void:
	for light in _lights:
		var tween := create_tween()
		tween.tween_property(light, "light_energy", 0.0, ramp_time)
