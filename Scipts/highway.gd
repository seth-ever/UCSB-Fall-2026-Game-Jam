extends Node3D

@export var road_length: float = 10000.0
@export var runoff_length: float = 1000.0
@export var segment_length: float = 40.0
@export var lane_width: float = 4.6

@export var max_turn_for_segment: float = 0.3
@export var max_direction: float = 0.9

@export var generation_seed : int = -1


@export_group("Scenery")
@export var ocean_y : float = -45.0
@export var building_density : float = 12.0 / 500.0 

@export_group("Materials")
@export var road_material: StandardMaterial3D
@export var wall_material: StandardMaterial3D
@export var ocean_material: StandardMaterial3D
@export var cliff_material: StandardMaterial3D
@export var building_material: StandardMaterial3D

@export_group("Assets")
@export var boost_scene : PackedScene
@export var car_scene   : PackedScene

@export_group("Road Markings")
@export var lines_material : StandardMaterial3D
@export var lines_tile_length : float = 12.0
@export var lines_height : float = 0.015
@export var lines_step : float = 4.0

@export_group("Boosts")
@export var boost_density : float = 40.0 / 5000.0
@export var boost_amount : float = 18.0

@export_group("Traffic")
@export var traffic_density : float = 60.0 / 5000.0
@export var traffic_speed_min : float = 10.0
@export var traffic_speed_max : float = 20.0

var curve: Curve3D
var road_path: Path3D = null

var lane_centers :Array = [-6.39, -2.3, 2.3, 6.9]

var _rng := RandomNumberGenerator.new()
var total_length: float = 0.0

var _boosts : Array = []
var _traffic : Array = []

@onready var race_ui = $RaceUI
@onready var player: Node3D = $Player

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if generation_seed >= 0:
		_rng.seed = generation_seed
	else:
		_rng.randomize()
	
	race_ui.race_started.connect(func(): player._started = true)
	player.finished.connect(race_ui.finish_race)
	race_ui.race_finished.connect(on_race_finished)

	
	
	total_length = road_length + runoff_length
	
	_init_materials()
	_generate_curve()
	_build_road()
	_build_road_lines()
	_build_ocean()
	_build_city()
	
	_spawn_boosts()
	_spawn_traffic()
	
	player.setup(curve, road_length)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	_update_traffic(delta)
	_check_boosts()



func _init_materials() -> void:
	if road_material == null:
		road_material = StandardMaterial3D.new()
		road_material.albedo_color = Color(0.3, 0.3, 0.3)
	if wall_material == null:
		wall_material = StandardMaterial3D.new()
		wall_material.albedo_color = Color(0.4, 0.4, 0.4)
	if ocean_material == null:
		var om := StandardMaterial3D.new()
		om.albedo_color = Color(0.09,0.28,0.45)
		om.metalic = 0.35
		om.roughness = 0.12
		ocean_material = om
	if cliff_material == null:
		cliff_material = StandardMaterial3D.new()
		cliff_material.albedo_color = Color(0.36, 0.31, 0.26)
	if building_material == null:
		building_material  = StandardMaterial3D.new()
		building_material.albedo_color = Color(0.22, 0.2, 0.25)
	
	

func _generate_curve() -> void:
	curve = Curve3D.new()
	var position := Vector3.ZERO
	var direction := 0.0
	var points: Array = []
	
	var segment_count := int(total_length / segment_length) + 1
	for i in segment_count:
		points.append(position)
		direction += _rng.randf_range(-max_turn_for_segment, max_turn_for_segment)
		direction = clampf(direction, -max_direction, max_direction)
		var forward_position := Vector3(sin(direction), 0 , -cos(direction))
		position += forward_position * segment_length
		position.y += _rng.randf_range(-1.2, 1.2)
		position.y = clampf(position.y, -6.0, 6.0)
		
		
	for p in points:
		curve.add_point(p)
	
	for i in range(1, points.size() - 1):
		var interpolation: Vector3 = (points[i + 1] - points[i - 1]).normalized()
		curve.set_point_in(i, -interpolation * segment_length * 0.3)
		curve.set_point_out(i, interpolation * segment_length * 0.3)
		
	
func _build_road() -> void:
		var path := Path3D.new()
		path.curve = curve
		add_child(path)
		road_path = path
		
		var half := lane_width * 2.0
		
		
		# ROAD
		var poly := CSGPolygon3D.new()
		add_child(poly)
		poly.mode = CSGPolygon3D.MODE_PATH
		poly.path_node = poly.get_path_to(path)
		poly.path_interval_type = CSGPolygon3D.PATH_INTERVAL_DISTANCE
		poly.path_interval = 5.0
		poly.path_rotation = CSGPolygon3D.PATH_ROTATION_PATH_FOLLOW
		poly.smooth_faces = false
		poly.use_collision = false
		poly.polygon = PackedVector2Array([
			Vector2(-half, 0.0),          # road left edge (wall side)
			Vector2(half, 0.0),           # road right edge (ocean side)
			Vector2(half + 0.3, 1.1),     # guard rail lip
			Vector2(half + 0.6, 1.1),
			Vector2(half + 0.6, -0.5),
			Vector2(-half, -0.5),
		])
		
		poly.material = road_material
		
		# WALL
		var wall := CSGPolygon3D.new()
		add_child(wall)
		wall.mode = CSGPolygon3D.MODE_PATH
		wall.path_node = wall.get_path_to(path)
		wall.path_interval_type = CSGPolygon3D.PATH_INTERVAL_DISTANCE
		wall.path_interval = 5.0
		wall.path_rotation = CSGPolygon3D.PATH_ROTATION_PATH_FOLLOW
		wall.smooth_faces = false
		wall.use_collision = false
		wall.polygon = PackedVector2Array([
			Vector2(-half - 0.4, 3.0),
			Vector2(-half, 3.0),
			Vector2(-half, -0.5),
			Vector2(-half - 0.4, -0.5),
		])
		wall.material = wall_material
		
		#Cliff on Ocean side
		var cliff := CSGPolygon3D.new()
		add_child(cliff)
		cliff.mode = CSGPolygon3D.MODE_PATH
		cliff.path_node = cliff.get_path_to(path)
		cliff.path_interval_type = CSGPolygon3D.PATH_INTERVAL_DISTANCE
		cliff.path_interval = 8.0
		cliff.path_rotation = CSGPolygon3D.PATH_ROTATION_PATH_FOLLOW
		cliff.smooth_faces = false
		cliff.use_collision = false
		cliff.polygon = PackedVector2Array([
			Vector2(half + 0.6, -0.5),
			Vector2(half + 6.0, ocean_y - 5.0),
			Vector2(half - 2.0, ocean_y - 5.0),
			Vector2(half - 2.0, -0.5),
		])
		cliff.material = cliff_material
		
func _build_ocean() -> void:
	var ocean := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(90000, 90000)
	#Subdivide so that a shader can be applied later
	plane.subdivide_width = 200
	plane.subdivide_depth = 200
	plane.material = ocean_material
	ocean.mesh = plane
	add_child(ocean)
	
	var midPoint := curve.sample_baked(total_length * 0.5, true)
	ocean.global_position = Vector3(midPoint.x + 600, ocean_y, midPoint.z) #Offest to the right side
	
func _build_city() -> void:
	var total_building_count = total_length * building_density
	for i in total_building_count:
		var s := _rng.randf_range(0.0, total_length)
		var xf := curve.sample_baked_with_rotation(s, true, true)
		var out := _rng.randf_range(25.0, 160.0)
		var height := _rng.randf_range(12.0, 70.0)
		var width := _rng.randf_range(8.0, 22.0)
		var depth := _rng.randf_range(8.0, 22.0)
		
		var meshInstance := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(width, height, depth)
		mesh.material = building_material
		meshInstance.mesh = mesh
		add_child(meshInstance)
		
		meshInstance.global_position = xf.origin + xf.basis * Vector3(-out, height/2.0 -4.0, 0)
		meshInstance.rotation.y = _rng.randf_range(0, TAU)
		meshInstance.visibility_range_end = 2000.0
		meshInstance.visibility_range_end_margin = 50.0
		meshInstance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		
func _build_road_lines() -> void:
	if lines_material == null:
		return
	
	var half := lane_width * 2.0
	var surfaceTool := SurfaceTool.new()
	surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var prev_left :=  Vector3.ZERO
	var prev_right := Vector3.ZERO
	var prev_v := 0.0
	var first := true
	
	var s := 0.0
	while s <= total_length:
		var xf := curve.sample_baked_with_rotation(s, true, true)
		var left:  Vector3 = xf.origin + xf.basis * Vector3(-half, lines_height, 0)
		var right: Vector3 = xf.origin + xf.basis * Vector3( half, lines_height, 0)
		var v : float = s / lines_tile_length
		var up : Vector3 = xf.basis.y
		
		if not first:
			surfaceTool.set_normal(up); surfaceTool.set_uv(Vector2(0.0, prev_v)); surfaceTool.add_vertex(prev_left)
			surfaceTool.set_normal(up); surfaceTool.set_uv(Vector2(1.0, v));      surfaceTool.add_vertex(right)
			surfaceTool.set_normal(up); surfaceTool.set_uv(Vector2(1.0, prev_v)); surfaceTool.add_vertex(prev_right)
			
			surfaceTool.set_normal(up); surfaceTool.set_uv(Vector2(0.0, prev_v)); surfaceTool.add_vertex(prev_left)
			surfaceTool.set_normal(up); surfaceTool.set_uv(Vector2(0.0, v));      surfaceTool.add_vertex(left)
			surfaceTool.set_normal(up); surfaceTool.set_uv(Vector2(1.0, v));      surfaceTool.add_vertex(right)
			
		prev_left  = left
		prev_right = right
		prev_v     = v
		first = false
		s += lines_step
	
	var mesh := surfaceTool.commit()
	var meshInstance := MeshInstance3D.new()
	meshInstance.mesh = mesh
	meshInstance.material_override= lines_material
	meshInstance.extra_cull_margin = 16384.0
	add_child(meshInstance)

func on_race_finished(final_time : float) -> void:
	print("Finished in ", final_time)

func _spawn_boosts() -> void:
	var boost_count = boost_density * (road_length - 80.0)
	
	for i in boost_count:
		var s : float = _rng.randf_range(20.0 , road_length - 60.0)
		var lane_x : float = lane_centers[(_rng.randi() % 4)]
		
		
		var boost_mesh = boost_scene.instantiate() as MeshInstance3D
		add_child(boost_mesh)
		
		var xf := curve.sample_baked_with_rotation(s, true, true)
		boost_mesh.global_transform = Transform3D(xf.basis,
			xf.origin + xf.basis * Vector3(lane_x , 0.1, 0))
		
		_boosts.append({"s": s, "lane_x": lane_x, "node": boost_mesh, "active": true})

func _check_boosts() -> void:
	var player_s: float = player.path_distance
	var player_x: float = player.lateral_position
	for b in _boosts:
		if not b["active"]:
			continue
		if absf(b["s"] - player_s) < 3.0 and absf(b["lane_x"] - player_x) < 1.8:
			b["active"] = false
			(b["node"] as Node3D).visible = false
			player.apply_boost(boost_amount)

func _spawn_traffic() -> void:
	var traffic_count = traffic_density * (road_length - 100.0)
	for i in traffic_count:
		var s : float = _rng.randf_range(40.0 , road_length - 60.0)
		var lane_id = _rng.randi() % 4
		var lane_x : float = lane_centers[lane_id]
		
		var oncoming : bool = lane_id < 2
		var traffic_speed = _rng.randf_range(traffic_speed_min, traffic_speed_max)
		
		
		var car_mesh = car_scene.instantiate() as Node3D
		add_child(car_mesh)
		
		var xf := curve.sample_baked_with_rotation(s, true, true)
		car_mesh.global_transform = Transform3D(xf.basis,
			xf.origin + xf.basis * Vector3(lane_x , 0.1, 0))
		
		_traffic.append({"s": s, 
			"lane_x": lane_x,
			"speed": traffic_speed, 
			"node": car_mesh, 
			"oncoming": oncoming})
	
func _update_traffic(delta : float) -> void:
	for car in _traffic:
		if car['oncoming']:
			car["s"] -= car["speed"] * delta
			if car["s"] < -10.0:
				car["s"] = road_length + 30.0
		else:
			car["s"] += car["speed"] * delta
			if car["s"] > (road_length + 30.0):
				car["s"] = -10.0
		
		var xf := curve.sample_baked_with_rotation(car["s"], true, true)
		var lane_x : float = car["lane_x"]
		var basis := xf.basis
		
		if car["oncoming"]:
			basis = basis.rotated(basis.y, PI)
		
		car.node.global_transform = Transform3D(basis, xf.origin + xf.basis * Vector3(lane_x, 0, 0))
		
		
			
