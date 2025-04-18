class_name MeshVoxelizer
extends Node

var voxel_size: float = 0.5
var voxel_data: Dictionary = {}

func voxelize_mesh(mesh: Mesh, material_map: Dictionary = {}) -> Dictionary:
	# Clear previous voxelization data
	voxel_data.clear()
	
	# Get the mesh AABB
	var aabb = mesh.get_aabb()
	
	# Calculate grid dimensions based on AABB
	var grid_dimensions = Vector3i(
		ceil(aabb.size.x / voxel_size),
		ceil(aabb.size.y / voxel_size),
		ceil(aabb.size.z / voxel_size)
	)
	
	# Create a voxel grid
	# Using raycasting to determine which points are inside the mesh
	for x in range(grid_dimensions.x):
		for y in range(grid_dimensions.y):
			for z in range(grid_dimensions.z):
				var local_pos = Vector3(
					x * voxel_size + voxel_size/2 + aabb.position.x,
					y * voxel_size + voxel_size/2 + aabb.position.y,
					z * voxel_size + voxel_size/2 + aabb.position.z
				)
				
				if point_in_mesh(mesh, local_pos):
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
	
	return voxel_data

# Using a simplified point-in-mesh test
func point_in_mesh(mesh: Mesh, point: Vector3) -> bool:
	# Simplified implementation - cast rays in 6 directions
	# If odd number of intersections in each direction, point is inside
	
	# In a full implementation, you'd use proper geometric algorithms
	# This is a placeholder for the actual geometric test
	
	# For demonstration, let's return a simple approximation
	# (In a real implementation, you would do proper intersection tests)
	var directions = [
		Vector3(1, 0, 0), Vector3(-1, 0, 0),
		Vector3(0, 1, 0), Vector3(0, -1, 0),
		Vector3(0, 0, 1), Vector3(0, 0, -1)
	]
	
	var intersection_count = 0
	for dir in directions:
		# In a real implementation, you would use mesh.intersect_ray() or similar
		# Here we're just approximating for demonstration
		var test_point = point + dir * 1000
		# Placeholder for actual ray-mesh intersection test
		intersection_count += 1  # This should be actual test result
	
	return intersection_count % 2 == 1

func get_voxel_health(voxel_type: String) -> float:
	match voxel_type:
		"metal": return 50.0
		"armor": return 80.0
		"engine": return 40.0
		"turret": return 60.0
		"glass": return 20.0
		_: return 30.0
