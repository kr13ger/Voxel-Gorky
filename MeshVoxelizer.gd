# scripts/tools/MeshVoxelizer.gd
class_name MeshVoxelizer
extends Node

var voxel_size: float = 0.5
var voxel_data: Dictionary = {}
var detail_level: int = 0 # 0=Low, 1=Medium, 2=High
var debug_mode: bool = true # Set to true to get more detailed logging

# Set this extremely high for complex models
var ABSOLUTE_MAX_VOXELS: int = 2000000  # 2 million voxel limit

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
	
	# Extract triangles from the mesh
	var all_triangles = _extract_triangles(mesh)
	
	if all_triangles.is_empty():
		print("No triangles found in mesh. Using fallback.")
		return _create_basic_shape()
	
	print("Processing ", all_triangles.size(), " triangles...")
	
	# Always use the complete approach for all detail levels and voxel sizes
	print("Using complete voxelization with ray casting...")
	
	# First pass: Create an occupancy grid from triangle rasterization
	var triangle_grid = _rasterize_triangles(all_triangles, aabb, grid_dimensions)
	
	# Second pass: Fill interior using ray casting
	var complete_grid = _fill_interior_with_raycasting(triangle_grid, grid_dimensions, aabb) 
	
	# Third pass: Convert grid to voxels with material assignment
	_convert_grid_to_voxels(complete_grid, grid_dimensions, aabb, material_map)
	
	# Add thickness based on detail level
	if detail_level >= 1:
		_add_thickness(grid_dimensions, detail_level)
	
	# If voxelization failed or produced no voxels, use fallback shape
	if voxel_data.is_empty():
		print("Voxelization produced no voxels. Using fallback shape.")
		return _create_basic_shape()
	
	print("Voxelization complete. Created ", voxel_data.size(), " voxels.")
	return voxel_data

# Extract all triangles from the mesh
func _extract_triangles(mesh: Mesh) -> Array:
	var all_triangles = []
	
	for surface_idx in range(mesh.get_surface_count()):
		var arrays = mesh.surface_get_arrays(surface_idx)
		
		if arrays.size() <= Mesh.ARRAY_VERTEX:
			continue
			
		var vertices = arrays[Mesh.ARRAY_VERTEX]
		
		if not vertices or vertices.size() == 0:
			continue
			
		# Different handling for indexed vs non-indexed geometry
		if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] != null:
			var indices = arrays[Mesh.ARRAY_INDEX]
			
			if indices.size() < 3:
				continue
			
			print("Surface ", surface_idx, " has ", vertices.size(), " vertices and ", indices.size(), " indices")
			
			# Process indexed triangles
			for i in range(0, indices.size(), 3):
				if i + 2 >= indices.size():
					break
					
				var v1 = vertices[indices[i]]
				var v2 = vertices[indices[i+1]]
				var v3 = vertices[indices[i+2]]
				
				all_triangles.append([v1, v2, v3])
		else:
			# Non-indexed geometry (vertices are already grouped in threes)
			print("Surface ", surface_idx, " has ", vertices.size(), " vertices (non-indexed)")
			
			for i in range(0, vertices.size(), 3):
				if i + 2 >= vertices.size():
					break
					
				var v1 = vertices[i]
				var v2 = vertices[i+1]
				var v3 = vertices[i+2]
				
				all_triangles.append([v1, v2, v3])
	
	return all_triangles

# Rasterize triangles into a 3D grid
func _rasterize_triangles(triangles: Array, aabb: AABB, grid_dimensions: Vector3i) -> Array:
	print("Rasterizing triangles into 3D grid...")
	
	# Create occupancy grid
	var grid = []
	
	# Initialize grid to all false (empty)
	for x in range(grid_dimensions.x):
		grid.append([])
		for y in range(grid_dimensions.y):
			grid[x].append([])
			for z in range(grid_dimensions.z):
				grid[x][y].append(false)
	
	# Process triangles in batches to show progress
	var batch_size = 1000
	var total_batches = ceil(float(triangles.size()) / batch_size)
	var processed_triangles = 0
	
	for batch in range(total_batches):
		var start_idx = batch * batch_size
		var end_idx = min(start_idx + batch_size, triangles.size())
		
		if batch % 10 == 0 or debug_mode:
			print("Rasterizing batch ", batch + 1, " of ", total_batches, " (triangles ", start_idx, "-", end_idx, ")")
		
		for i in range(start_idx, end_idx):
			var triangle = triangles[i]
			var v1 = triangle[0]
			var v2 = triangle[1]
			var v3 = triangle[2]
			
			# Get triangle bounds in grid coordinates
			var grid_min = Vector3i(
				max(0, floor((min(v1.x, min(v2.x, v3.x)) - aabb.position.x) / voxel_size)),
				max(0, floor((min(v1.y, min(v2.y, v3.y)) - aabb.position.y) / voxel_size)),
				max(0, floor((min(v1.z, min(v2.z, v3.z)) - aabb.position.z) / voxel_size))
			)
			
			var grid_max = Vector3i(
				min(grid_dimensions.x - 1, ceil((max(v1.x, max(v2.x, v3.x)) - aabb.position.x) / voxel_size)),
				min(grid_dimensions.y - 1, ceil((max(v1.y, max(v2.y, v3.y)) - aabb.position.y) / voxel_size)),
				min(grid_dimensions.z - 1, ceil((max(v1.z, max(v2.z, v3.z)) - aabb.position.z) / voxel_size))
			)
			
			# Rasterize this triangle (extensive sampling)
			_rasterize_single_triangle(v1, v2, v3, grid_min, grid_max, aabb, grid)
			
			processed_triangles += 1
			
			# Report progress periodically
			if processed_triangles % 10000 == 0:
				print("Processed ", processed_triangles, " triangles...")
	
	# Count rasterized voxels
	var rasterized_count = 0
	for x in range(grid_dimensions.x):
		for y in range(grid_dimensions.y):
			for z in range(grid_dimensions.z):
				if grid[x][y][z]:
					rasterized_count += 1
	
	print("Triangle rasterization complete. Created ", rasterized_count, " surface voxels.")
	return grid

# Rasterize a single triangle into the grid using barycentric coordinates
func _rasterize_single_triangle(v1: Vector3, v2: Vector3, v3: Vector3, grid_min: Vector3i, 
							   grid_max: Vector3i, aabb: AABB, grid: Array) -> void:
	# Calculate triangle size for adaptive sampling
	var edge1_len = (v2 - v1).length()
	var edge2_len = (v3 - v2).length()
	var edge3_len = (v1 - v3).length()
	var max_edge = max(edge1_len, max(edge2_len, edge3_len))
	
	# Adjust sampling density based on voxel size and triangle size
	var density = max(15, int(max_edge / (voxel_size * 0.25)))
	density = min(density, 40)  # Cap to avoid excessive computation
	
	# Rasterize the edges and interior
	# 1. Edges sampling (higher density)
	for t in range(density + 1):
		var fraction = float(t) / density
		
		# Sample points along each edge
		var pt1 = v1.lerp(v2, fraction)
		var pt2 = v2.lerp(v3, fraction)
		var pt3 = v3.lerp(v1, fraction)
		
		_mark_point_in_grid(pt1, aabb, grid)
		_mark_point_in_grid(pt2, aabb, grid)
		_mark_point_in_grid(pt3, aabb, grid)
	
	# 2. Interior sampling using barycentric coordinates
	for u in range(1, density):
		for v in range(1, density - u):
			var a = float(u) / density
			var b = float(v) / density
			var c = 1.0 - a - b
			
			var point = v1 * a + v2 * b + v3 * c
			_mark_point_in_grid(point, aabb, grid)

# Mark a point in the grid if it's within bounds
func _mark_point_in_grid(point: Vector3, aabb: AABB, grid: Array) -> void:
	# Convert to grid coordinates
	var grid_x = floor((point.x - aabb.position.x) / voxel_size)
	var grid_y = floor((point.y - aabb.position.y) / voxel_size)
	var grid_z = floor((point.z - aabb.position.z) / voxel_size)
	
	# Skip if out of bounds
	if grid_x < 0 or grid_x >= grid.size() or \
	   grid_y < 0 or grid_y >= grid[0].size() or \
	   grid_z < 0 or grid_z >= grid[0][0].size():
		return
	
	# Mark as occupied
	grid[grid_x][grid_y][grid_z] = true

# Fill the interior of the model using ray casting
func _fill_interior_with_raycasting(surface_grid: Array, grid_dimensions: Vector3i, aabb: AABB) -> Array:
	print("Filling interior using ray casting...")
	
	# Create a copy of the grid for the result
	var result_grid = []
	for x in range(grid_dimensions.x):
		result_grid.append([])
		for y in range(grid_dimensions.y):
			result_grid[x].append([])
			for z in range(grid_dimensions.z):
				result_grid[x][y].append(surface_grid[x][y][z])
	
	# We'll cast rays in six directions to determine inside/outside
	var ray_counts = []
	var directions = [
		Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
		Vector3i(0, 1, 0), Vector3i(0, -1, 0),
		Vector3i(0, 0, 1), Vector3i(0, 0, -1)
	]
	
	# Report progress periodically
	var filled_voxels = 0
	var total_checks = 0
	
	# Process in slices for progress reporting
	for x in range(grid_dimensions.x):
		if x % 10 == 0 or debug_mode:
			print("Processing ray casting for slice ", x, " of ", grid_dimensions.x)
		
		for y in range(grid_dimensions.y):
			for z in range(grid_dimensions.z):
				# Skip if already marked (part of surface)
				if surface_grid[x][y][z]:
					continue
				
				total_checks += 1
				
				# Cast rays in all 6 directions
				var ray_crossings = 0
				
				for dir in directions:
					var hit_count = 0
					var curr_x = x
					var curr_y = y
					var curr_z = z
					
					# Cast ray until we hit boundary
					while true:
						curr_x += dir.x
						curr_y += dir.y
						curr_z += dir.z
						
						# If ray exits grid, stop counting
						if curr_x < 0 or curr_x >= grid_dimensions.x or \
						   curr_y < 0 or curr_y >= grid_dimensions.y or \
						   curr_z < 0 or curr_z >= grid_dimensions.z:
							break
						
						# Count surface crossing
						if surface_grid[curr_x][curr_y][curr_z]:
							hit_count += 1
					
					# If odd number of crossings, we're inside in this direction
					if hit_count % 2 == 1:
						ray_crossings += 1
				
				# If majority of rays show we're inside, fill this voxel
				if ray_crossings > 3:  # At least 4 out of 6 directions
					result_grid[x][y][z] = true
					filled_voxels += 1
				
				# Progress reporting
				if total_checks % 100000 == 0:
					print("Checked ", total_checks, " voxels, filled ", filled_voxels, " interior voxels")
	
	print("Interior filling complete. Added ", filled_voxels, " interior voxels.")
	return result_grid

# Convert the completed grid to voxel data with material assignments
func _convert_grid_to_voxels(grid: Array, grid_dimensions: Vector3i, aabb: AABB, material_map: Dictionary) -> void:
	print("Converting completed grid to voxels...")
	
	var voxel_count = 0
	
	for x in range(grid_dimensions.x):
		if x % 20 == 0 or debug_mode:
			print("Converting slice ", x, " of ", grid_dimensions.x)
			
		for y in range(grid_dimensions.y):
			for z in range(grid_dimensions.z):
				if grid[x][y][z]:
					# Create voxel key
					var voxel_key = "%d,%d,%d" % [x, y, z]
					
					# Skip if voxel already exists (shouldn't happen)
					if voxel_data.has(voxel_key):
						continue
					
					# Calculate world position for material assignment
					var world_pos = Vector3(
						x * voxel_size + voxel_size/2 + aabb.position.x,
						y * voxel_size + voxel_size/2 + aabb.position.y,
						z * voxel_size + voxel_size/2 + aabb.position.z
					)
					
					# Determine voxel type based on position
					var voxel_type = "metal"  # Default type
					
					# Map specific regions to different materials
					for material_name in material_map:
						var region = material_map[material_name]
						if world_pos.x >= region.position.x and world_pos.x <= region.end.x and \
						   world_pos.y >= region.position.y and world_pos.y <= region.end.y and \
						   world_pos.z >= region.position.z and world_pos.z <= region.end.z:
							voxel_type = material_name
							break
					
					# Create the voxel
					voxel_data[voxel_key] = {
						"type": voxel_type,
						"position": Vector3i(x, y, z),
						"health": get_voxel_health(voxel_type),
						"instance": null
					}
					
					voxel_count += 1
					
					# Check limit after each voxel
					if voxel_count >= ABSOLUTE_MAX_VOXELS:
						print("WARNING: Reached voxel limit during conversion.")
						return
	
	print("Grid conversion complete. Created ", voxel_count, " voxels.")

# Add thickness to surface voxels based on detail level
func _add_thickness(grid_dimensions: Vector3i, detail: int) -> void:
	print("Adding thickness based on detail level ", detail, "...")
	
	# Create a list of original keys to avoid modifying while iterating
	var original_keys = voxel_data.keys()
	var original_count = original_keys.size()
	
	# Determine thickness based on detail level
	var thickness = 1
	if detail >= 2:  # High detail
		thickness = 2
	
	# Add neighbors for each existing voxel
	for key in original_keys:
		var parts = key.split(",")
		var x = int(parts[0])
		var y = int(parts[1])
		var z = int(parts[2])
		
		var voxel_type = voxel_data[key].type
		
		# Process neighbors within thickness range
		for dx in range(-thickness, thickness+1):
			for dy in range(-thickness, thickness+1):
				for dz in range(-thickness, thickness+1):
					# Skip the original voxel
					if dx == 0 and dy == 0 and dz == 0:
						continue
					
					# Calculate Manhattan distance
					var distance = abs(dx) + abs(dy) + abs(dz)
					
					# Skip if too far based on detail level
					if distance > thickness:
						continue
					
					# Add more neighbor filtering based on detail
					if detail < 2 and distance > 1:
						# For low/medium detail, only add direct neighbors
						continue
					
					# Calculate neighbor position
					var nx = x + dx
					var ny = y + dy
					var nz = z + dz
					
					# Skip if out of bounds
					if nx < 0 or nx >= grid_dimensions.x or \
					   ny < 0 or ny >= grid_dimensions.y or \
					   nz < 0 or nz >= grid_dimensions.z:
						continue
					
					# Create neighbor key
					var neighbor_key = "%d,%d,%d" % [nx, ny, nz]
					
					# Add if not already exists
					if not voxel_data.has(neighbor_key):
						voxel_data[neighbor_key] = {
							"type": voxel_type,
							"position": Vector3i(nx, ny, nz),
							"health": get_voxel_health(voxel_type),
							"instance": null
						}
					
					# Check limit
					if voxel_data.size() >= ABSOLUTE_MAX_VOXELS:
						print("WARNING: Reached voxel limit while adding thickness.")
						var added = voxel_data.size() - original_count
						print("Added ", added, " thickness voxels before limit.")
						return
	
	var added = voxel_data.size() - original_count
	print("Added ", added, " thickness voxels.")

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
