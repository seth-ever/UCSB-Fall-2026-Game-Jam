extends Node3D

@export var road_length: float = 10000.0
@export var runoff_length: float = 1000.0
@export var segment_length: float = 40.0

@export var lane_width: float = 4.6

@export var max_turn_for_segment: float = 0.3
@export var max_direction: float = 0.9

@export_group("Scenery")
@export var ocean_y : float = -45.0

@export_group("Materials")
@export var road_material: StandardMaterial3D
@export var wall_material: StandardMaterial3D
@export var ocean_material: StandardMaterial3D
@export var cliff_material: StandardMaterial3D



var curve: Curve3D
var road_path: Path3D = null

var rng := RandomNumberGenerator.new()
var total_length: float = 0.0


@onready var player: Node3D = $Player

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	total_length = road_length + runoff_length
	
	_init_materials()
	_generate_curve()
	_build_road()
	_build_ocean()
	
	player.setup(curve, road_length)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass



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
	
	

func _generate_curve() -> void:
	curve = Curve3D.new()
	var position := Vector3.ZERO
	var direction := 0.0
	var points: Array = []
	
	var segment_count := int(total_length / segment_length) + 1
	for i in segment_count:
		points.append(position)
		direction += rng.randf_range(-max_turn_for_segment, max_turn_for_segment)
		direction = clampf(direction, -max_direction, max_direction)
		var forward_position := Vector3(sin(direction), 0 , -cos(direction))
		position += forward_position * segment_length
		
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
	
		
		
