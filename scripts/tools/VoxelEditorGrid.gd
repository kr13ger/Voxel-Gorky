# scripts/tools/VoxelEditorGrid.gd
class_name VoxelEditorGrid
extends Node

var grid_container: Node3D
var grid_size = Vector3i(20, 10, 20)
var grid_visible = true

func setup_grid(container: Node3D):
	grid_container = container
	update_grid(1.0)

func update_grid(voxel_size: float):
	# Clear existing grid
	for child in grid_container.get_children():
		child.queue_free()
	
	# Create a new grid with lines
	var grid_material = StandardMaterial3D.new()
	grid_material.albedo_color = Color(0.5, 0.5, 0.5, 0.3)
	grid_material.flags_transparent = true
	
	var line_mesh = ImmediateMesh.new()
	var grid_instance = MeshInstance3D.new()
	grid_instance.mesh = line_mesh
	grid_instance.material_override = grid_material
	
	# Draw X lines (every 5 cells to avoid clutter)
	line_mesh.clear_surfaces()
	line_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	
	var grid_step = 5
	
	for z in range(-grid_size.z/2, grid_size.z/2 + 1, grid_step):
		for y in range(-grid_size.y/2, grid_size.y/2 + 1, grid_step):
			line_mesh.surface_add_vertex(Vector3(-grid_size.x/2 * voxel_size, y * voxel_size, z * voxel_size))
			line_mesh.surface_add_vertex(Vector3(grid_size.x/2 * voxel_size, y * voxel_size, z * voxel_size))
	
	# Draw Z lines
	for x in range(-grid_size.x/2, grid_size.x/2 + 1, grid_step):
		for y in range(-grid_size.y/2, grid_size.y/2 + 1, grid_step):
			line_mesh.surface_add_vertex(Vector3(x * voxel_size, y * voxel_size, -grid_size.z/2 * voxel_size))
			line_mesh.surface_add_vertex(Vector3(x * voxel_size, y * voxel_size, grid_size.z/2 * voxel_size))
	
	# Draw Y lines
	for x in range(-grid_size.x/2, grid_size.x/2 + 1, grid_step):
		for z in range(-grid_size.z/2, grid_size.z/2 + 1, grid_step):
			line_mesh.surface_add_vertex(Vector3(x * voxel_size, -grid_size.y/2 * voxel_size, z * voxel_size))
			line_mesh.surface_add_vertex(Vector3(x * voxel_size, grid_size.y/2 * voxel_size, z * voxel_size))
	
	line_mesh.surface_end()
	
	grid_container.add_child(grid_instance)
	grid_container.visible = grid_visible

func set_visible(visible: bool):
	grid_visible = visible
	grid_container.visible = visible
