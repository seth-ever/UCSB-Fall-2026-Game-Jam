extends Node3D

signal finished

@export_group("Visual Effect")
@export var aberration_material: ShaderMaterial
@export var max_aberration : float = 0.03
@export var aberration_smoothing : float = 4.0

@export_group("Bike Movement")
@export var max_natural_speed: float = 45.0
@export var max_absolute_speed: float = 68.0
@export var acceleration: float = 18.0
@export var brake_decelleration: float = 35
@export var coast_decelleration: float = 6.0
@export var lateral_movement_speed: float = 9.0
@export var lateral_position_limit: float = 8.7

@export_group("Feel")
@export var lean_max_degrees: float = 22.0
@export var lean_speed: float = 6.0
@export var base_player_fov: float = 75.0
@export var fov_per_speed: float = 0.35
@export var fov_change_speed: float = 4.0


var path_distance: float = 0.0
var lateral_position: float = 2.3
var speed: float = 0.0

var _current_lean: float = 0.0

var _curve: Curve3D = null
var _road_length: float = 0.0

var _started  : bool = false
var _finished : bool = false

var _current_aberration : float = 0.0

@onready var camera: Camera3D = $Camera3D


func setup(curve: Curve3D, road_length: float) -> void:
	_curve = curve
	_road_length = road_length
	path_distance = 5.0

func get_total_speed() -> float:
	return minf(speed, max_absolute_speed)
	
func apply_aberration(delta: float) -> void:
	var total_speed = get_total_speed()
	var t := clampf(inverse_lerp(0, max_absolute_speed, total_speed), 0.0, 1.0)
	t = t * t
	var target_aberration : float = t * max_aberration
	
	_current_aberration = lerpf(_current_aberration, target_aberration, 1.0 - exp(-aberration_smoothing * delta))
	
	aberration_material.set_shader_parameter("aberration_amount", _current_aberration)
	
	

func _physics_process(delta: float) -> void:

	

	if _curve == null:
		return
		
	if not _finished and path_distance >= _road_length:
		_finished = true
		finished.emit()
	
	if _finished:
		speed = move_toward(speed, 0.0, coast_decelleration * delta) #If done, coast down
	elif Input.is_action_pressed("move_up"):
		speed = move_toward(speed, max_natural_speed, acceleration * delta) #Accelleration
	elif Input.is_action_pressed("move_down"):
		speed = move_toward(speed, 0.0, brake_decelleration * delta) #Braking
	else:
		speed = move_toward(speed, 0.0, coast_decelleration * delta)  #Coasting, lose some speed
	
	#Add boost process
	
	var total_speed : float = get_total_speed()
	path_distance += total_speed * delta *int( _started)
	
	var steering := Input.get_axis("move_left", "move_right")
	lateral_position += steering * lateral_movement_speed *delta *int( _started)
	lateral_position = clampf(lateral_position, -lateral_position_limit, lateral_position_limit)
	
	var xf := _curve.sample_baked_with_rotation(path_distance, true, true)
	global_transform = Transform3D(xf.basis, 
	xf.origin + xf.basis * Vector3(lateral_position, 0.0, 0.0))
	
	var target_lean : float = -steering * deg_to_rad(lean_max_degrees)
	_current_lean = lerpf(_current_lean, target_lean, lean_speed * delta)
	camera.rotation.z = _current_lean
	
	var target_fov : float = base_player_fov + total_speed * fov_per_speed
	camera.fov = lerpf(camera.fov, target_fov, fov_change_speed * delta)
	
	apply_aberration(delta)
