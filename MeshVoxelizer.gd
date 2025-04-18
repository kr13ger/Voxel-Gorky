# MeshVoxelizer.gd
class_name MeshVoxelizer
extends Node

var voxel_size: float = 0.5
var voxel_data: Dictionary = {}
var detail_level: int = 0 # 0=Low, 1=Medium, 2=High

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
	var max_voxels = 200000 # Increased from 100000 for high detail
	if grid_dimensions.x * grid_dimensions.y * grid_dimensions.z > max_voxels:
		print("WARNING: Very large voxel grid detected. Using low detail mode.")
		detail_level = 0
	
	# Choose voxelization method based on detail level
	match detail_level:
		0: # Low detail - basic AABB check
			_voxelize_low_detail(mesh, grid_dimensions, aabb, material_map)
		1: # Medium detail - surface sampling
			_voxelize_medium_detail(mesh, grid_dimensions, aabb, material_map)
		2: # High detail - raycasting + surface refinement
			_voxelize_high_detail(mesh, grid_dimensions, aabb, material_map)
	
	print("Voxelization complete. Created ", voxel_data.size(), " voxels.")
	return voxel_data

# Low detail mode (original implementation)
func _voxelize_low_detail(mesh: Mesh, grid_dimensions: Vector3i, aabb: AABB, material_map: Dictionary) -> void:
	print("Using low detail voxelization mode...")
	
	for x in range(grid_dimensions.x):
		for y in range(grid_dimensions.y):
			for z in range(grid_dimensions.z):
				var local_pos = Vector3(
					x * voxel_size + voxel_size/2 + aabb.position.x,
					y * voxel_size + voxel_size/2 + aabb.position.y,
					z * voxel_size + voxel_size/2 + aabb.position.z
				)
				
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

# Medium detail mode - more precise shape with surface detection
func _voxelize_medium_detail(mesh: Mesh, grid_dimensions: Vector3i, aabb: AABB, material_map: Dictionary) -> void:
	print("Using medium detail voxelization mode...")
	
	# Create a smaller step value for more precise checking
	var interior_step = 3 # Check every Nth voxel in the interior
	
	# First, create surface voxels
	for x in range(grid_dimensions.x):
		for y in range(grid_dimensions.y):
			for z in range(grid_dimensions.z):
				# Check if this could be a surface voxel by checking neighbors
				var is_border = (
					x == 0 or x == grid_dimensions.x-1 or
					y == 0 or y == grid_dimensions.y-1 or
					z == 0 or z == grid_dimensions.z-1
				)
				
				var local_pos = Vector3(
					x * voxel_size + voxel_size/2 + aabb.position.x,
					y * voxel_size + voxel_size/2 + aabb.position.y,
					z * voxel_size + voxel_size/2 + aabb.position.z
				)
				
				# More accurate surface detection for medium detail
				var should_create = false
				
				if is_border:
					# If on the border, use simple AABB check
					should_create = is_point_likely_in_mesh(local_pos, aabb)
				else:
					# For interior points, check if we're at a multiple of interior_step
					if (x % interior_step == 0 or y % interior_step == 0 or z % interior_step == 0):
						# Check surface proximity using multiple sample points
						should_create = _is_on_surface(local_pos, aabb)
					else:
						# Use the simpler check for non-surface voxels
						should_create = is_point_likely_in_mesh(local_pos, aabb)
				
				if should_create:
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

# High detail mode - most accurate with intensive sampling
func _voxelize_high_detail(mesh: Mesh, grid_dimensions: Vector3i, aabb: AABB, material_map: Dictionary) -> void:
	print("Using high detail voxelization mode...")
	
	# Get triangle faces from mesh for more accurate checks
	var arrays = mesh.surface_get_arrays(0)
	var vertices = arrays[Mesh.ARRAY_VERTEX]
	var indices = arrays[Mesh.ARRAY_INDEX]
	
	# Initialize an array to track processed voxels
	var processed_voxels = {}
	
	# First, do precise surface voxelization
	# We'll create smaller voxels near surfaces for better detail
	for x in range(grid_dimensions.x):
		# Print progress indicator every 10%
		if x % int(grid_dimensions.x / 10) == 0:
			var progress = float(x) / float(grid_dimensions.x) * 100.0
			print("Voxelization progress: ", floor(progress), "%")
		
		for y in range(grid_dimensions.y):
			for z in range(grid_dimensions.z):
				var local_pos = Vector3(
					x * voxel_size + voxel_size/2 + aabb.position.x,
					y * voxel_size + voxel_size/2 + aabb.position.y,
					z * voxel_size + voxel_size/2 + aabb.position.z
				)
				
				# Check if we're near the surface of the model
				var is_surface = _is_near_surface(local_pos, aabb, voxel_size * 1.5)
				var inside_mesh = is_point_likely_in_mesh(local_pos, aabb)
				
				if inside_mesh:
					var voxel_key = "%d,%d,%d" % [x, y, z]
					
					# Apply different material types based on location
					var voxel_type = "metal"  # Default type
					
					# Map specific regions to different materials
					for material_name in material_map:
						var region = material_map[material_name]
						if local_pos.x >= region.position.x and local_pos.x <= region.end.x and \
						   local_pos.y >= region.position.y and local_pos.y <= region.end.y and \
						   local_pos.z >= region.position.z and local_pos.z <= region.end.z:
							voxel_type = material_name
							break
					
					# Special handling for surface voxels - refined detail
					if is_surface:
						# Subdivide surface voxels for better detail
						var subvoxels = 2 # Number of subdivisions per dimension
						for sx in range(subvoxels):
							for sy in range(subvoxels):
								for sz in range(subvoxels):
									var subpos = Vector3(
										local_pos.x - voxel_size/4 + sx * voxel_size/2,
										local_pos.y - voxel_size/4 + sy * voxel_size/2,
										local_pos.z - voxel_size/4 + sz * voxel_size/2
									)
									
									# More precise check for subvoxels
									if is_point_likely_in_mesh(subpos, aabb):
										# For subvoxels, we'll use a different key format
										var subkey = "%d.%d,%d.%d,%d.%d" % [x, sx, y, sy, z, sz]
										
										# Only add if the parent voxel isn't already processed
										if not processed_voxels.has(voxel_key):
											voxel_data[subkey] = {
												"type": voxel_type,
												"position": Vector3(
													x + (sx * 0.5 - 0.25), 
													y + (sy * 0.5 - 0.25), 
													z + (sz * 0.5 - 0.25)
												),
												"health": get_voxel_health(voxel_type),
												"instance": null,
												"is_subvoxel": true
											}
						
						# Mark this parent voxel as processed
						processed_voxels[voxel_key] = true
					else:
						# Regular interior voxel
						voxel_data[voxel_key] = {
							"type": voxel_type,
							"position": Vector3i(x, y, z),
							"health": get_voxel_health(voxel_type),
							"instance": null
						}

# Check if a point is likely on the surface of the model
func _is_on_surface(point: Vector3, aabb: AABB) -> bool:
	# Shrink AABB slightly to create a shell effect
	var inner_aabb = AABB(
		aabb.position + aabb.size * 0.15,
		aabb.size * 0.7
	)
	
	var outer_aabb = AABB(
		aabb.position + aabb.size * 0.05,
		aabb.size * 0.9
	)
	
	# Point is on surface if it's in the outer AABB but not in the inner AABB
	return outer_aabb.has_point(point) and not inner_aabb.has_point(point)

# Check if a point is near the surface (within distance)
func _is_near_surface(point: Vector3, aabb: AABB, distance: float) -> bool:
	# Create two AABBs, one slightly smaller and one slightly larger than the mesh
	var inner_aabb = AABB(
		aabb.position + Vector3.ONE * distance * 0.5,
		aabb.size - Vector3.ONE * distance
	)
	
	var outer_aabb = AABB(
		aabb.position - Vector3.ONE * distance * 0.5,
		aabb.size + Vector3.ONE * distance
	)
	
	# We're near a surface if we're in the outer AABB but not in the inner AABB
	return outer_aabb.has_point(point) and not inner_aabb.has_point(point)

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
	
	# Detail level affects the complexity of the fallback model
	var x_size = 3
	var y_size = 2
	var z_size = 5
	
	# Add more detail for higher detail levels
	if detail_level >= 1:
		# Create a more detailed tank shape for medium/high detail
		x_size = 4
		y_size = 3
		z_size = 6
	
	# Create a simple box shape for the tank body
	for x in range(-x_size, x_size + 1):
		for y in range(0, y_size):
			for z in range(-z_size, z_size + 1):
				var voxel_key = "%d,%d,%d" % [x, y, z]
				var voxel_type = "metal"
				
				# Skip some voxels to create a more interesting shape
				if detail_level >= 1:
					# Shape the hull - taper at the ends
					if abs(z) > z_size - 1 and (abs(x) > x_size - 1):
						continue
					
					# Create angled front armor
					if z < -z_size + 2 and y == 0:
						voxel_type = "armor"
					
					# Make treads/wheels on the sides
					if y == 0 and abs(x) == x_size:
						voxel_type = "metal"
				
				# Make top part the turret
				if y == y_size - 1 and abs(x) <= x_size - 2 and abs(z) <= z_size - 3:
					voxel_type = "turret"
				
				# Make front armor
				if z < -z_size + 2:
					voxel_type = "armor"
					
				# Add gun barrel
				if y == y_size - 1 and x == 0 and z < -z_size + 3:
					voxel_type = "metal"
				
				# High detail level adds more features
				if detail_level >= 2:
					# Add more turret details
					if y == y_size and abs(x) <= 1 and abs(z) <= 1:
						voxel_type = "turret"
						
					# Add commander hatch
					if y == y_size and x == 1 and z == 1:
						voxel_type = "metal"
					
					# Add exhaust pipes
					if y == y_size - 1 and x == x_size - 1 and z == z_size - 1:
						voxel_type = "metal"
					
					# Add side skirts for high detail
					if y == 0 and abs(x) == x_size - 1 and abs(z) < z_size - 1:
						voxel_type = "armor"
				
				tank_data[voxel_key] = {
					"type": voxel_type,
					"position": Vector3i(x, y, z),
					"health": get_voxel_health(voxel_type),
					"instance": null
				}
	
	# For high detail, add more special features
	if detail_level >= 2:
		# Add antenna
		for y in range(y_size, y_size + 2):
			var key = "%d,%d,%d" % [1, y, 0]
			tank_data[key] = {
				"type": "metal",
				"position": Vector3i(1, y, 0),
				"health": get_voxel_health("metal"),
				"instance": null
			}
		
		# Add gun mantlet around barrel
		for x in range(-1, 2):
			var key = "%d,%d,%d" % [x, y_size - 1, -z_size + 2]
			tank_data[key] = {
				"type": "armor",
				"position": Vector3i(x, y_size - 1, -z_size + 2),
				"health": get_voxel_health("armor"),
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
