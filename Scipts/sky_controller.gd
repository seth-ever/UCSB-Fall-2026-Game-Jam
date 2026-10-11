class_name SkyController
extends Node

@export_group("Skyboxes")
@export var sunset_panorama: Texture2D
@export var night_panorama: Texture2D

@export_group("Blend distances (meters)")
@export var dusk_start_fraction: float = 0.25
@export var entry_blend_out: float = 15.0
@export var entry_blend_in: float = 25.0
@export var exit_blend_in: float = 20.0
@export var exit_blend_out: float = 10.0
@export var panorama_swap_at: float = 0.5

@export_group("Sunset look (race start)")
@export var sunset_sun_rotation: Vector3 = Vector3(-8, 115, 0)
@export var sunset_sun_color: Color = Color(1.0, 0.72, 0.45)
@export var sunset_sun_energy: float = 1.5
@export var sunset_ambient_color: Color = Color(1.0, 0.85, 0.72)
@export var sunset_ambient_energy: float = 1.0
@export var sunset_fog_color: Color = Color(0.95, 0.6, 0.42)
@export var sunset_fog_density: float = 0.0016
@export var sunset_sky_energy: float = 1.0

@export_group("Dusk look (at tunnel entrance)")
@export var dusk_sun_rotation: Vector3 = Vector3(-2, 128, 0)
@export var dusk_sun_color: Color = Color(0.95, 0.45, 0.35)
@export var dusk_sun_energy: float = 0.5
@export var dusk_ambient_color: Color = Color(0.6, 0.5, 0.6)
@export var dusk_ambient_energy: float = 0.6
@export var dusk_fog_color: Color = Color(0.5, 0.35, 0.42)
@export var dusk_fog_density: float = 0.0021
@export var dusk_sky_energy: float = 0.45

@export_group("Tunnel interior (its own dark preset)")
@export var tunnel_ambient_color: Color = Color(0.3, 0.3, 0.32)
@export var tunnel_ambient_energy: float = 0.12
@export var tunnel_fog_color: Color = Color(0.06, 0.06, 0.07)
@export var tunnel_fog_density: float = 0.05
@export var tunnel_sun_energy: float = 0.0

@export_group("Night look (after the tunnel)")
@export var night_sun_rotation: Vector3 = Vector3(-35, 220, 0)
@export var night_sun_color: Color = Color(0.55, 0.65, 1.0)
@export var night_sun_energy: float = 0.35
@export var night_ambient_color: Color = Color(0.4, 0.42, 0.5)
@export var night_ambient_energy: float = 0.5
@export var night_fog_color: Color = Color(0.18, 0.2, 0.38)
@export var night_fog_density: float = 0.0026
@export var night_sky_energy: float = 0.6

@export_group("Post")
@export var glow_enabled: bool = true
@export var glow_intensity_day: float = 0.5
@export var glow_intensity_night: float = 1.2
@export var saturation: float = 1.15

enum Phase { SUNSET, DUSK, TUNNEL, NIGHT }

var phase: Phase = Phase.SUNSET

var _env: Environment
var _sky: Sky
var _sky_mat: PanoramaSkyMaterial
var _sun: DirectionalLight3D
var _player: Node = null
var _road_length: float = 1.0
var _tunnel_start: float = 0.0
var _tunnel_end: float = 0.0
var _panorama_swapped: bool = false


signal tunnel_entered()
signal night_started()


func _ready() -> void:
	_build()


func track_player(player: Node, road_length: float,
		tunnel_start: float, tunnel_end: float) -> void:
	_player = player
	_road_length = maxf(road_length, 1.0)
	_tunnel_start = tunnel_start
	_tunnel_end = tunnel_end


func _build() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY

	_sky = Sky.new()
	_sky_mat = PanoramaSkyMaterial.new()
	if sunset_panorama != null:
		_sky_mat.panorama = sunset_panorama
	_sky_mat.energy_multiplier = sunset_sky_energy
	_sky.sky_material = _sky_mat
	_env.sky = _sky

	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.fog_enabled = true
	_env.fog_sky_affect = 0.4
	_env.glow_enabled = glow_enabled
	_env.glow_bloom = 0.15
	_env.adjustment_enabled = true
	_env.adjustment_saturation = saturation

	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)

	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = false
	add_child(_sun)

	_apply_sunset()


func _process(_delta: float) -> void:
	if _player == null:
		return

	var d: float = _player.path_distance

	if d >= _tunnel_end + exit_blend_out:
		if phase != Phase.NIGHT:
			phase = Phase.NIGHT
			_enter_night_state()
		return

	if d >= _tunnel_end - exit_blend_in:
		var span: float = maxf(exit_blend_in + exit_blend_out, 0.0001)
		var t: float = clampf((d - (_tunnel_end - exit_blend_in)) / span, 0.0, 1.0)
		_apply_exit_blend(t)
		return

	if d >= _tunnel_start + entry_blend_in:
		if phase != Phase.TUNNEL:
			phase = Phase.TUNNEL
			_enter_tunnel_state()
		_check_panorama_swap(d)
		_apply_tunnel_flat()
		_park_sun_for_night()
		return

	if d >= _tunnel_start - entry_blend_out:
		if phase != Phase.TUNNEL:
			phase = Phase.TUNNEL
			_enter_tunnel_state()
		var span2: float = maxf(entry_blend_out + entry_blend_in, 0.0001)
		var t2: float = clampf((d - (_tunnel_start - entry_blend_out)) / span2, 0.0, 1.0)
		_apply_entry_blend(t2)
		return

	var dusk_start_dist: float = _road_length * dusk_start_fraction
	var dusk_end_dist: float = _tunnel_start - entry_blend_out
	if d >= dusk_start_dist:
		phase = Phase.DUSK
		var span3: float = maxf(dusk_end_dist - dusk_start_dist, 0.0001)
		var t3: float = clampf((d - dusk_start_dist) / span3, 0.0, 1.0)
		_apply_dusk_blend(t3)
	else:
		phase = Phase.SUNSET

func _apply_dusk_blend(t: float) -> void:
	_sun.rotation_degrees = sunset_sun_rotation.lerp(dusk_sun_rotation, t)
	_sun.light_color = sunset_sun_color.lerp(dusk_sun_color, t)
	_sun.light_energy = lerpf(sunset_sun_energy, dusk_sun_energy, t)

	_env.ambient_light_color = sunset_ambient_color.lerp(dusk_ambient_color, t)
	_env.ambient_light_energy = lerpf(sunset_ambient_energy, dusk_ambient_energy, t)
	_env.fog_light_color = sunset_fog_color.lerp(dusk_fog_color, t)
	_env.fog_density = lerpf(sunset_fog_density, dusk_fog_density, t)

	_sky_mat.energy_multiplier = lerpf(sunset_sky_energy, dusk_sky_energy, t)
	_env.glow_intensity = lerpf(glow_intensity_day, glow_intensity_night, t * 0.4)


func _enter_tunnel_state() -> void:
	tunnel_entered.emit()


func _set_sky_hidden(hidden: bool) -> void:
	if hidden:
		if _env.background_mode != Environment.BG_COLOR:
			_env.background_mode = Environment.BG_COLOR
			_env.background_color = Color.BLACK
			_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	else:
		if _env.background_mode != Environment.BG_SKY:
			_env.background_mode = Environment.BG_SKY
			_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY


func _apply_entry_blend(t: float) -> void:

	_set_sky_hidden(_player.path_distance >= _tunnel_start)

	_env.ambient_light_color = dusk_ambient_color.lerp(tunnel_ambient_color, t)
	_env.ambient_light_energy = lerpf(dusk_ambient_energy, tunnel_ambient_energy, t)
	_env.fog_light_color = dusk_fog_color.lerp(tunnel_fog_color, t)
	_env.fog_density = lerpf(dusk_fog_density, tunnel_fog_density, t)
	_sun.light_color = dusk_sun_color
	_sun.light_energy = lerpf(dusk_sun_energy, tunnel_sun_energy, t)
	_sun.rotation_degrees = dusk_sun_rotation
	_env.glow_intensity = glow_intensity_day
	_sky_mat.energy_multiplier = lerpf(dusk_sky_energy, night_sky_energy, t)


func _check_panorama_swap(d: float) -> void:
	if _panorama_swapped:
		return
	var tunnel_len: float = maxf(_tunnel_end - _tunnel_start, 0.0001)
	if (d - _tunnel_start) / tunnel_len < panorama_swap_at:
		return
	_panorama_swapped = true
	if night_panorama != null:
		_sky_mat.panorama = night_panorama
	_sky_mat.energy_multiplier = night_sky_energy


func _park_sun_for_night() -> void:
	_sun.rotation_degrees = night_sun_rotation
	_sun.light_color = night_sun_color


func _apply_exit_blend(t: float) -> void:
	if not _panorama_swapped:
		_panorama_swapped = true
		if night_panorama != null:
			_sky_mat.panorama = night_panorama
		_sky_mat.energy_multiplier = night_sky_energy
	_park_sun_for_night()

	_set_sky_hidden(false)

	_env.ambient_light_color = tunnel_ambient_color.lerp(night_ambient_color, t)
	_env.ambient_light_energy = lerpf(tunnel_ambient_energy, night_ambient_energy, t)
	_env.fog_light_color = tunnel_fog_color.lerp(night_fog_color, t)
	_env.fog_density = lerpf(tunnel_fog_density, night_fog_density, t)
	_sun.light_energy = lerpf(tunnel_sun_energy, night_sun_energy, t)
	_env.glow_intensity = lerpf(glow_intensity_day, glow_intensity_night, t)

func _lerp_lighting(
		a_amb_col: Color, a_amb_e: float, a_fog_col: Color, a_fog_d: float,
		a_sun_col: Color, a_sun_e: float, a_sun_rot: Vector3,
		b_amb_col: Color, b_amb_e: float, b_fog_col: Color, b_fog_d: float,
		b_sun_col: Color, b_sun_e: float, b_sun_rot: Vector3,
		a_glow: float, b_glow: float, t: float) -> void:
	_env.ambient_light_color = a_amb_col.lerp(b_amb_col, t)
	_env.ambient_light_energy = lerpf(a_amb_e, b_amb_e, t)
	_env.fog_light_color = a_fog_col.lerp(b_fog_col, t)
	_env.fog_density = lerpf(a_fog_d, b_fog_d, t)
	_sun.light_color = a_sun_col.lerp(b_sun_col, t)
	_sun.light_energy = lerpf(a_sun_e, b_sun_e, t)
	_sun.rotation_degrees = a_sun_rot.lerp(b_sun_rot, t)
	_env.glow_intensity = lerpf(a_glow, b_glow, t)


func _apply_tunnel_flat() -> void:
	_set_sky_hidden(true)
	_env.ambient_light_color = tunnel_ambient_color
	_env.ambient_light_energy = tunnel_ambient_energy
	_env.fog_light_color = tunnel_fog_color
	_env.fog_density = tunnel_fog_density
	_sun.light_energy = tunnel_sun_energy
	_env.glow_intensity = glow_intensity_day

func _enter_night_state() -> void:
	_apply_night_instant()
	night_started.emit()


func _apply_sunset() -> void:
	_env.background_mode = Environment.BG_SKY
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_sun.rotation_degrees = sunset_sun_rotation
	_sun.light_color = sunset_sun_color
	_sun.light_energy = sunset_sun_energy
	_env.ambient_light_color = sunset_ambient_color
	_env.ambient_light_energy = sunset_ambient_energy
	_env.fog_light_color = sunset_fog_color
	_env.fog_density = sunset_fog_density
	_env.glow_intensity = glow_intensity_day
	_sky_mat.energy_multiplier = sunset_sky_energy
	if sunset_panorama != null:
		_sky_mat.panorama = sunset_panorama


func _apply_night_instant() -> void:
	_env.background_mode = Environment.BG_SKY
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	if night_panorama != null:
		_sky_mat.panorama = night_panorama
	_panorama_swapped = true
	_sky_mat.energy_multiplier = night_sky_energy
	_sun.rotation_degrees = night_sun_rotation
	_sun.light_color = night_sun_color
	_sun.light_energy = night_sun_energy
	_env.ambient_light_color = night_ambient_color
	_env.ambient_light_energy = night_ambient_energy
	_env.fog_light_color = night_fog_color
	_env.fog_density = night_fog_density
	_env.glow_intensity = glow_intensity_night

func force_night() -> void:
	phase = Phase.NIGHT
	_apply_night_instant()
	night_started.emit()


func force_day() -> void:
	phase = Phase.SUNSET
	_panorama_swapped = false
	_apply_sunset()
