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

# Debugging helpers
var debug_mode = false

func setup_selection(box: Panel, cam: Camera3D, container: Node3D):
	selection_box = box
	camera = cam
	voxel_container = container
	
	# Make sure the selection box is hidden initially
	if selection_box:
		selection_box.visible = false

func _input(event):
	if not camera or not selection_box:
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Start drag
				drag_start_position = event.position
				is_dragging = true
				
				if drag_mode == "move" and not selected_voxels.is_empty():
					is_moving_voxels = true
					_start_moving_voxels()
				elif drag_mode == "select":
					# If not holding shift, clear selection
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
						# Only process selection box if we've moved a significant distance
						if drag_start_position.distance_to(event.position) > 5:
							_process_selection_box()
					
					# Hide the selection box
					selection_box.visible = false
	
	# Update selection box while dragging for selection
	if not is_moving_voxels and is_dragging and drag_mode == "select" and event is InputEventMouseMotion:
		_update_selection_box(event.position)

func _process(delta):
	# Update moving voxels if in move mode
	if is_moving_voxels and is_dragging:
		_update_moving_voxels()

func _update_selection_box(current_pos: Vector2):
	if not selection_box:
		return
		
	var top_left = Vector2(min(drag_start_position.x, current_pos.x), 
						   min(drag_start_position.y, current_pos.y))
	var size = Vector2(abs(current_pos.x - drag_start_position.x), 
					   abs(current_pos.y - drag_start_position.y))
	
	selection_box.position = top_left
	selection_box.size = size
	selection_box.visible = true

func _process_selection_box():
	if not camera or selected_voxels == null:
		return
		
	var rect = Rect2(
		Vector2(min(drag_start_position.x, get_viewport().get_mouse_position().x),
				min(drag_start_position.y, get_viewport().get_mouse_position().y)),
		Vector2(abs(get_viewport().get_mouse_position().x - drag_start_position.x),
				abs(get_viewport().get_mouse_position().y - drag_start_position.y))
	)
	
	# Skip if the rectangle is too small (likely a single click)
	if rect.size.length() < 5:
		return
	
	# Select all voxels in the box
	for voxel_mesh in voxel_container.get_children():
		if voxel_mesh is MeshInstance3D:
			var screen_pos = camera.unproject_position(voxel_mesh.global_position)
			if rect.has_point(screen_pos):
				select_voxel(voxel_mesh)

func select_voxel(voxel_mesh):
	if not voxel_mesh or not voxel_mesh.has_meta("voxel_key"):
		return
		
	# Skip if already selected
	if voxel_mesh in selected_voxels:
		return
	
	# Add to selection array
	selected_voxels.append(voxel_mesh)
	
	# Highlight the selected voxel
	var material = voxel_mesh.material_override
	if material:
		material = material.duplicate()
		material.emission_enabled = true
		material.emission = Color(0.3, 0.3, 0.3)
		material.emission_energy = 0.5
		voxel_mesh.material_override = material
	
	# Emit signal
	voxel_selected.emit(voxel_mesh)

func clear_selection():
	# Remove highlighting from all selected voxels
	for voxel_mesh in selected_voxels:
		if is_instance_valid(voxel_mesh):
			var material = voxel_mesh.material_override
			if material:
				material = material.duplicate()
				material.emission_enabled = false
				voxel_mesh.material_override = material
	
	# Clear the array
	selected_voxels.clear()
	
	# Emit signal
	selection_cleared.emit()

func set_move_mode(enabled: bool):
	drag_mode = "move" if enabled else "select"
	
	if enabled and not selected_voxels.is_empty():
		if debug_mode:
			print("Move mode enabled with ", selected_voxels.size(), " voxels selected")
	elif not enabled:
		# Reset any in-progress move
		is_moving_voxels = false
		move_start_positions.clear()
		move_grid_offset = Vector3i.ZERO

func _start_moving_voxels():
	move_start_positions.clear()
	
	# Store initial positions of all selected voxels
	for voxel_mesh in selected_voxels:
		if voxel_mesh.has_meta("voxel_key"):
			var voxel_key = voxel_mesh.get_meta("voxel_key")
			move_start_positions[voxel_key] = voxel_mesh.position
	
	# Reset grid offset
	move_grid_offset = Vector3i.ZERO
	
	if debug_mode:
		print("Started moving ", move_start_positions.size(), " voxels")

func _update_moving_voxels():
	if not camera or move_start_positions.is_empty() or not voxel_container:
		return
	
	var mouse_pos = get_viewport().get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000
	
	# Cast ray to find target position
	# Fixed: Get the world through the voxel_container
	var space_state = voxel_container.get_world_3d().direct_space_state  
	var query = PhysicsRayQueryParameters3D.create(from, to)
	
	# Exclude selected voxels from the ray
	for voxel in selected_voxels:
		var area = voxel.get_node_or_null("SelectionArea")
		if area and area is Area3D:
			query.exclude.append(area.get_rid())
	
	var result = space_state.intersect_ray(query)
	
	if result:
		var hit_pos = result.position
		var normal = result.normal
		
		# Calculate grid position (add normal to place adjacent to hit surface)
		var grid_pos = Vector3i(
			round((hit_pos.x + normal.x * voxel_size * 0.5) / voxel_size),
			round((hit_pos.y + normal.y * voxel_size * 0.5) / voxel_size),
			round((hit_pos.z + normal.z * voxel_size * 0.5) / voxel_size)
		)
		
		# If we have a reference point, calculate the offset
		if not move_start_positions.is_empty():
			# Get the first voxel as reference
			var first_key = move_start_positions.keys()[0]
			
			# Get the parent editor
			var parent_editor = get_parent()
			if parent_editor and parent_editor.current_voxel_data.has(first_key):
				var first_pos = parent_editor.current_voxel_data[first_key]["position"]
				var current_grid_offset = grid_pos - first_pos
				
				# Only update if the offset has changed
				if current_grid_offset != move_grid_offset:
					move_grid_offset = current_grid_offset
					
					# Update visual positions of all selected voxels
					for voxel_mesh in selected_voxels:
						if voxel_mesh.has_meta("voxel_key"):
							var voxel_key = voxel_mesh.get_meta("voxel_key")
							if parent_editor.current_voxel_data.has(voxel_key):
								var original_pos = parent_editor.current_voxel_data[voxel_key]["position"]
								voxel_mesh.position = Vector3(
									(original_pos.x + move_grid_offset.x) * voxel_size,
									(original_pos.y + move_grid_offset.y) * voxel_size,
									(original_pos.z + move_grid_offset.z) * voxel_size
								)

func _finish_moving_voxels():
	# If there was no movement, do nothing
	if move_grid_offset == Vector3i.ZERO:
		return
	
	# Emit signal to notify of the move
	var move_data = {
		"offset": move_grid_offset,
		"voxels": selected_voxels.duplicate()
	}
	
	if debug_mode:
		print("Finished moving voxels with offset: ", move_grid_offset)
	
	voxels_moved.emit(move_data)
