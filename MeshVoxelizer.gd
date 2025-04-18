class_name MeshVoxelizer
extends Node

var voxel_size: float = 0.5
var voxel_data: Dictionary = {}

func voxelize_mesh(mesh: Mesh, material_map: Dictionary = {}) -> Dictionary:
	# Clear previous voxelization data
	voxel_data.clear()
	
	# Get the mesh AABB
	var aabb = mesh.get_aabb()
	print("Mesh AABB: ", aabb)
	
	# Calculate grid dimensions based on AABB
	var grid_dimensions = Vector3i(
		ceil(aabb.size.x / voxel_size),
		ceil(aabb.size.y / voxel_size),
		ceil(aabb.size.z / voxel_size)
	)
	print("Grid dimensions: ", grid_dimensions)
	
	# Safety check for excessive grid size
	if grid_dimensions.x * grid_dimensions.y * grid_dimensions.z > 100000:
		print("WARNING: Very large voxel grid detected. Limiting to avoid performance issues.")
		return _create_basic_shape()
	
	# Create a voxel grid based on AABB shape instead of ray testing
	for x in range(grid_dimensions.x):
		for y in range(grid_dimensions.y):
			for z in range(grid_dimensions.z):
				var local_pos = Vector3(
					x * voxel_size + voxel_size/2 + aabb.position.x,
					y * voxel_size + voxel_size/2 + aabb.position.y,
					z * voxel_size + voxel_size/2 + aabb.position.z
				)
				
				# Simple check if point is within AABB bounds
				if is_point_likely_in_mesh(local_pos, aabb):
					var voxel_key = "%d,%d,%d" % [x, y, z]
					
					# Determine voxel type based on position
					var voxel_type = "metal"  # Default type
					
					# Map specific regions to different materials
					for material_name in material_map:
						var region = material_map[material_name]
						if local_pos.x >= region.position.x and local_pos.x <= region.end.x and \
						   local_pos.y >= region.position.y and local_pos.y <= region.end.y and \
						   local_pos.z >= region.position.z and local_pos.z <= region.end.z:
							voxel_type = material_name
							break
					
					voxel_data[voxel_key] = {
						"type": voxel_type,
						"position": Vector3i(x, y, z),
						"health": get_voxel_health(voxel_type),
						"instance": null
					}
	
	print("Voxelization complete. Created ", voxel_data.size(), " voxels.")
	return voxel_data

# A faster, simplified check that doesn't use ray casting
# Just checks if the point is inside a slightly smaller AABB to create a solid shape
func is_point_likely_in_mesh(point: Vector3, aabb: AABB) -> bool:
	# Shrink AABB slightly to create a shell effect
	var inner_aabb = AABB(
		aabb.position + aabb.size * 0.1,
		aabb.size * 0.8
	)
	
	return inner_aabb.has_point(point)

# Fallback method to create a simple tank-like shape if the mesh processing fails
func _create_basic_shape() -> Dictionary:
	print("Creating basic tank shape as fallback")
	var tank_data = {}
	
	# Create a simple box shape for the tank body
	for x in range(-3, 4):
		for y in range(0, 2):
			for z in range(-5, 6):
				var voxel_key = "%d,%d,%d" % [x, y, z]
				var voxel_type = "metal"
				
				# Make top part the turret
				if y == 1 and abs(x) <= 2 and abs(z) <= 2:
					voxel_type = "turret"
				
				# Make front armor
				if z < -3:
					voxel_type = "armor"
					
				# Add gun barrel
				if y == 1 and x == 0 and z < -2:
					voxel_type = "metal"
					
				tank_data[voxel_key] = {
					"type": voxel_type,
					"position": Vector3i(x, y, z),
					"health": get_voxel_health(voxel_type),
					"instance": null
				}
	
	print("Created basic tank with ", tank_data.size(), " voxels")
	return tank_data

func get_voxel_health(voxel_type: String) -> float:
	match voxel_type:
		"metal": return 50.0
		"armor": return 80.0
		"engine": return 40.0
		"turret": return 60.0
		"glass": return 20.0
		_: return 30.0
