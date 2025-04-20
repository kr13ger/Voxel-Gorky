# scripts/tools/VoxelEditorGhostVoxel.gd
class_name VoxelEditorGhostVoxel
extends Node

signal voxel_placement_requested(position)

var ghost_voxel: MeshInstance3D
var camera: Camera3D
var editor: Node
var add_mode = false
var hover_position = Vector3i.ZERO

func setup_ghost_voxel(cam: Camera3D, editor_ref: Node):
	camera = cam
	editor = editor_ref
	_create_ghost_voxel()

func _create_ghost_voxel():
	ghost_voxel = MeshInstance3D.new()
	var cube_mesh = BoxMesh.new()
	cube_mesh.size = Vector3.ONE * editor.voxel_size * 0.95
	ghost_voxel.mesh = cube_mesh
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.7, 1.0, 0.5)
	material.flags_transparent = true
	ghost_voxel.material_override = material
	
	editor.add_child(ghost_voxel)
	ghost_voxel.visible = false

func set_add_mode(enabled: bool):
	add_mode = enabled
	ghost_voxel.visible = enabled
	
	if enabled:
		editor.ui.show_status("Click to place a voxel")
	else:
		editor.ui.show_status("Add voxel mode disabled")

func update_color(color: Color):
	if ghost_voxel:
		var mat = ghost_voxel.material_override.duplicate()
		mat.albedo_color = Color(color.r, color.g, color.b, 0.5)
		ghost_voxel.material_override = mat

func update_size(voxel_size: float):
	if ghost_voxel:
		var cube_mesh = BoxMesh.new()
		cube_mesh.size = Vector3.ONE * voxel_size * 0.95
		ghost_voxel.mesh = cube_mesh

func _process(delta):
	if add_mode:
		_update_ghost_position()

func _input(event):
	if add_mode and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_place_voxel()

func _update_ghost_position():
	var mouse_pos = editor.get_viewport().get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000
	
	var space_state = editor.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)
	
	if result:
		var hit_pos = result.position
		var normal = result.normal
		
		# Adjust position based on face normal
		var grid_pos = Vector3i(
			round((hit_pos.x + normal.x * editor.voxel_size * 0.5) / editor.voxel_size),
			round((hit_pos.y + normal.y * editor.voxel_size * 0.5) / editor.voxel_size),
			round((hit_pos.z + normal.z * editor.voxel_size * 0.5) / editor.voxel_size)
		)
		
		# Check if position is valid
		var key = "%d,%d,%d" % [grid_pos.x, grid_pos.y, grid_pos.z]
		
		if not editor.current_voxel_data.has(key):
			# Valid position
			ghost_voxel.visible = true
			ghost_voxel.position = Vector3(
				grid_pos.x * editor.voxel_size,
				grid_pos.y * editor.voxel_size,
				grid_pos.z * editor.voxel_size
			)
			hover_position = grid_pos
		else:
			# Invalid position
			ghost_voxel.visible = false
	else:
		ghost_voxel.visible = false

func _place_voxel():
	if not ghost_voxel.visible:
		return
	
	voxel_placement_requested.emit(hover_position)
