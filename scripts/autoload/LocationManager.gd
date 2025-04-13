extends Node

var _current_location: Node3D = null
var _location_size: Vector3 = Vector3.ZERO
var _voxel_grid: Dictionary = {}
var _voxel_size: float = 1.0

func initialize_location(location_node: Node3D, size: Vector3, voxel_size: float = 1.0) -> void:
	_current_location = location_node
	_location_size = size
	_voxel_size = voxel_size
	_voxel_grid.clear()
	Logger.info("Location initialized with size: %s and voxel size: %f" % [size, voxel_size], "LocationManager")
	DependencyContainer.register("location", location_node)

func get_voxel_at(position: Vector3) -> Dictionary:
	var grid_pos = _world_to_grid(position)
	var key = _grid_pos_to_key(grid_pos)
	
	if _voxel_grid.has(key):
		return _voxel_grid[key]
	return {}

func set_voxel(position: Vector3, voxel_data: Dictionary) -> void:
	var grid_pos = _world_to_grid(position)
	var key = _grid_pos_to_key(grid_pos)
	
	_voxel_grid[key] = voxel_data
	
	# Create visual representation if it doesn't exist
	if voxel_data.has("type") and voxel_data.has("instance") and voxel_data.instance == null:
		_create_voxel_instance(grid_pos, voxel_data)

func destroy_voxel(position: Vector3) -> bool:
	var grid_pos = _world_to_grid(position)
	var key = _grid_pos_to_key(grid_pos)
	
	if not _voxel_grid.has(key):
		return false
	
	var voxel_data = _voxel_grid[key]
	
	# Remove the visual instance
	if voxel_data.has("instance") and voxel_data.instance != null:
		voxel_data.instance.queue_free()
	
	# Remove from the grid
	_voxel_grid.erase(key)
	
	# Emit signal with destroyed block data
	SignalBus.emit_block_destroyed(voxel_data)
	
	return true

func is_position_in_bounds(position: Vector3) -> bool:
	var grid_pos = _world_to_grid(position)
	
	return (
		grid_pos.x >= 0 and grid_pos.x < _location_size.x and
		grid_pos.y >= 0 and grid_pos.y < _location_size.y and
		grid_pos.z >= 0 and grid_pos.z < _location_size.z
	)

func _world_to_grid(world_pos: Vector3) -> Vector3i:
	return Vector3i(
		floor(world_pos.x / _voxel_size),
		floor(world_pos.y / _voxel_size),
		floor(world_pos.z / _voxel_size)
	)

func _grid_to_world(grid_pos: Vector3i) -> Vector3:
	return Vector3(
		grid_pos.x * _voxel_size + _voxel_size / 2,
		grid_pos.y * _voxel_size + _voxel_size / 2,
		grid_pos.z * _voxel_size + _voxel_size / 2
	)

func _grid_pos_to_key(grid_pos: Vector3i) -> String:
	return "%d,%d,%d" % [grid_pos.x, grid_pos.y, grid_pos.z]

func _create_voxel_instance(grid_pos: Vector3i, voxel_data: Dictionary) -> void:
	var block_data = ItemDatabase.get_block_data(voxel_data.type)
	
	if block_data.empty():
		Logger.error("Failed to create voxel: Block type not found", "LocationManager")
		return
	
	# For simplicity, we'll use a basic cube mesh
	var mesh_instance = MeshInstance3D.new()
	var cube_mesh = BoxMesh.new()
	cube_mesh.size = Vector3.ONE * _voxel_size
	mesh_instance.mesh = cube_mesh
	
	# Set position
	mesh_instance.position = _grid_to_world(grid_pos)
	
	# Set material/texture
	var material = StandardMaterial3D.new()
	if block_data.has("texture_path"):
		var texture = load(block_data.texture_path)
		if texture:
			material.albedo_texture = texture
	
	# Set color based on type if no texture
	match voxel_data.type:
		"dirt":
			material.albedo_color = Color(0.5, 0.35, 0.05)
		"stone":
			material.albedo_color = Color(0.7, 0.7, 0.7)
		"metal":
			material.albedo_color = Color(0.6, 0.6, 0.8)
		_:
			material.albedo_color = Color(1, 1, 1)
	
	mesh_instance.material_override = material
	
	# Add collision
	var static_body = StaticBody3D.new()
	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3.ONE * _voxel_size
	collision_shape.shape = box_shape
	static_body.add_child(collision_shape)
	mesh_instance.add_child(static_body)
	
	# Add to scene
	_current_location.add_child(mesh_instance)
	
	# Update voxel data with the instance reference
	voxel_data.instance = mesh_instance
	
	# Add some metadata for identification
	mesh_instance.set_meta("voxel_type", voxel_data.type)
	mesh_instance.set_meta("grid_position", grid_pos)
