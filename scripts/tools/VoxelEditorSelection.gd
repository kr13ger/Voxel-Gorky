# scripts/tools/VoxelEditorSelection.gd
class_name VoxelEditorSelection
extends Node

signal voxel_selected(voxel_mesh)
signal selection_cleared()
signal voxels_moved(move_data)

var selection_box: Panel
var camera: Camera3D
var voxel_container: Node3D
var selected_voxels = []
var drag_start_position = Vector2.ZERO
var is_dragging = false
var is_moving_voxels = false
var drag_mode = "select" # "select" or "move"
var move_start_positions = {}
var move_grid_offset = Vector3i.ZERO
var voxel_size: float = 1.0

func setup_selection(box: Panel, cam: Camera3D, container: Node3D):
	selection_box = box
	camera = cam
	voxel_container = container

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				drag_start_position = event.position
				is_dragging = true
				
				if drag_mode == "move" and not selected_voxels.is_empty():
					is_moving_voxels = true
					_start_moving_voxels()
				elif drag_mode == "select":
					if not Input.is_key_pressed(KEY_SHIFT):
						clear_selection()
			else:
				# End drag
				if is_dragging:
					is_dragging = false
					
					if is_moving_voxels:
						is_moving_voxels = false
						_finish_moving_voxels()
					elif drag_mode == "select":
						if drag_start_position.distance_to(event.position) > 5:
							_process_selection_box()
					
					selection_box.visible = false
	
	# Update selection box while dragging
	if not is_moving_voxels and is_dragging and drag_mode == "select" and event is InputEventMouseMotion:
		_update_selection_box(event.position)

func _process(delta):
	if is_moving_voxels and is_dragging:
		_update_moving_voxels()

func _update_selection_box(current_pos: Vector2):
	var top_left = Vector2(min(drag_start_position.x, current_pos.x), 
						   min(drag_start_position.y, current_pos.y))
	var size = Vector2(abs(current_pos.x - drag_start_position.x), 
					   abs(current_pos.y - drag_start_position.y))
	
	selection_box.position = top_left
	selection_box.size = size
	selection_box.visible = true

func _process_selection_box():
	var rect = Rect2(
		Vector2(min(drag_start_position.x, get_viewport().get_mouse_position().x),
				min(drag_start_position.y, get_viewport().get_mouse_position().y)),
		Vector2(abs(get_viewport().get_mouse_position().x - drag_start_position.x),
				abs(get_viewport().get_mouse_position().y - drag_start_position.y))
	)
	
	for voxel_mesh in voxel_container.get_children():
		var screen_pos = camera.unproject_position(voxel_mesh.global_position)
		if rect.has_point(screen_pos):
			select_voxel(voxel_mesh)

func select_voxel(voxel_mesh):
	if voxel_mesh in selected_voxels:
		return
	
	selected_voxels.append(voxel_mesh)
	
	# Highlight the selected voxel
	var mat = voxel_mesh.material_override.duplicate()
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.3, 0.3)
	mat.emission_energy = 0.5
	voxel_mesh.material_override = mat
	
	voxel_selected.emit(voxel_mesh)

func clear_selection():
	for voxel_mesh in selected_voxels:
		var mat = voxel_mesh.material_override.duplicate()
		mat.emission_enabled = false
		voxel_mesh.material_override = mat
	
	selected_voxels.clear()
	selection_cleared.emit()

func set_move_mode(enabled: bool):
	drag_mode = "move" if enabled else "select"

func _start_moving_voxels():
	move_start_positions.clear()
	
	for voxel_mesh in selected_voxels:
		var voxel_key = voxel_mesh.get_meta("voxel_key")
		move_start_positions[voxel_key] = voxel_mesh.position
	
	move_grid_offset = Vector3i.ZERO

func _update_moving_voxels():
	var mouse_pos = get_viewport().get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000
	
	var space_state = voxel_container.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)
	
	if result:
		var hit_pos = result.position
		var grid_pos = Vector3i(
			round(hit_pos.x / voxel_size),
			round(hit_pos.y / voxel_size),
			round(hit_pos.z / voxel_size)
		)
		
		if not move_start_positions.is_empty():
			var first_key = move_start_positions.keys()[0]
			# Get the voxel data from the parent editor instead
			var parent_editor = get_parent()
			if parent_editor and parent_editor.current_voxel_data.has(first_key):
				var first_pos = parent_editor.current_voxel_data[first_key]["position"]
				var current_grid_offset = grid_pos - first_pos
				
				if current_grid_offset != move_grid_offset:
					move_grid_offset = current_grid_offset
					
					for voxel_mesh in selected_voxels:
						var voxel_key = voxel_mesh.get_meta("voxel_key")
						if parent_editor.current_voxel_data.has(voxel_key):
							var original_pos = parent_editor.current_voxel_data[voxel_key]["position"]
							voxel_mesh.position = Vector3(
								(original_pos.x + move_grid_offset.x) * voxel_size,
								(original_pos.y + move_grid_offset.y) * voxel_size,
								(original_pos.z + move_grid_offset.z) * voxel_size
							)

func _finish_moving_voxels():
	if move_grid_offset == Vector3i.ZERO:
		return
	
	var move_data = {
		"offset": move_grid_offset,
		"voxels": selected_voxels.duplicate()
	}
	
	voxels_moved.emit(move_data)
