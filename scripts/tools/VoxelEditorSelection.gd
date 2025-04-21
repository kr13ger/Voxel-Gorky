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

# Added variables for dragging
var is_dragging_selected_voxel = false
var drag_start_world_pos = Vector3.ZERO

# Debugging helpers
var debug_mode = true

func setup_selection(box: Panel, cam: Camera3D, container: Node3D):
	selection_box = box
	camera = cam
	voxel_container = container
	
	# Make sure the selection box is hidden initially
	if selection_box:
		selection_box.visible = false
		
	if debug_mode:
		print("VoxelEditorSelection: Setup completed")
		print("- Selection box: ", "Valid" if selection_box else "Invalid")
		print("- Camera: ", "Valid" if camera else "Invalid")
		print("- Voxel container: ", "Valid" if voxel_container else "Invalid")

func _input(event):
	if not camera or not selection_box:
		return
	
	# Skip input processing if the mouse is over UI elements
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		# Check if mouse is over UI panels
		if _is_mouse_over_ui(event.position):
			return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Start drag
				drag_start_position = event.position
				is_dragging = true
				
				if drag_mode == "move" and not selected_voxels.is_empty():
					# Check if we're clicking on a selected voxel
					var from = camera.project_ray_origin(event.position)
					var to = from + camera.project_ray_normal(event.position) * 1000
					
					var space_state = voxel_container.get_world_3d().direct_space_state
					var query = PhysicsRayQueryParameters3D.create(from, to)
					var result = space_state.intersect_ray(query)
					
					if result:
						# Check if we clicked on a selection area of a selected voxel
						var selected = false
						for voxel in selected_voxels:
							var selection_area = voxel.get_node_or_null("SelectionArea")
							if selection_area and result.collider == selection_area:
								selected = true
								break
						
						if selected:
							if debug_mode:
								print("Starting drag on selected voxel")
							
							drag_start_world_pos = result.position
							is_moving_voxels = true
							is_dragging_selected_voxel = true
							_start_moving_voxels()
					
				elif drag_mode == "select":
					# If not holding shift, clear selection
					if not Input.is_key_pressed(KEY_SHIFT):
						if debug_mode:
							print("Clearing selection on drag start (not holding shift)")
						clear_selection()
			else:
				# End drag
				if is_dragging:
					is_dragging = false
					
					if is_moving_voxels:
						is_moving_voxels = false
						is_dragging_selected_voxel = false
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

# NEW METHOD: Check if mouse is over any UI panel
func _is_mouse_over_ui(mouse_pos: Vector2) -> bool:
	var parent_editor = get_parent()
	if not parent_editor or not parent_editor.has_node("UI"):
		return false
		
	var ui_root = parent_editor.get_node("UI")
	
	# Check if mouse is over main UI panels
	var ui_panels = [
		"PropertyPanel", 
		"ViewControls", 
		"StatusPanel", 
		"FileDialog"
	]
	
	for panel_name in ui_panels:
		var panel = ui_root.get_node_or_null(panel_name)
		if panel and panel is Control and panel.visible:
			if panel.get_global_rect().has_point(mouse_pos):
				if debug_mode:
					print("Mouse is over UI panel: ", panel_name)
				return true
	
	# Check for any buttons or other interactive controls
	return _check_children_for_mouse(ui_root, mouse_pos)

# Helper function to check children controls recursively
func _check_children_for_mouse(control: Control, mouse_pos: Vector2) -> bool:
	for child in control.get_children():
		if child is Control and child.visible:
			if child is Button or child is OptionButton or child is CheckBox or child is ColorPickerButton:
				if child.get_global_rect().has_point(mouse_pos):
					if debug_mode:
						print("Mouse is over UI control: ", child.name)
					return true
			
			# Check children recursively
			if _check_children_for_mouse(child, mouse_pos):
				return true
				
	return false

func _process(delta):
	# Update moving voxels if in move mode
	if is_moving_voxels and is_dragging and is_dragging_selected_voxel:
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
	
	if debug_mode:
		print("Processing selection box with size: ", rect.size)
	
	# Select all voxels in the box
	for voxel_mesh in voxel_container.get_children():
		if voxel_mesh is MeshInstance3D:
			var screen_pos = camera.unproject_position(voxel_mesh.global_position)
			if rect.has_point(screen_pos):
				select_voxel(voxel_mesh)

func select_voxel(voxel_mesh):
	if not voxel_mesh:
		if debug_mode:
			print("Cannot select null voxel mesh")
		return
		
	if not voxel_mesh.has_meta("voxel_key"):
		if debug_mode:
			print("Voxel mesh has no 'voxel_key' metadata: ", voxel_mesh.name)
		return
		
	# Skip if already selected
	if voxel_mesh in selected_voxels:
		if debug_mode:
			print("Voxel already selected: ", voxel_mesh.get_meta("voxel_key"))
		return
	
	if debug_mode:
		print("Selecting voxel: ", voxel_mesh.get_meta("voxel_key"))
	
	# Add to selection array
	selected_voxels.append(voxel_mesh)
	
	# Highlight the selected voxel
	var material = voxel_mesh.material_override
	if material:
		material = material.duplicate()
		material.emission_enabled = true
		material.emission = Color(0.3, 0.8, 0.3)  # Brighter green for better visibility
		material.emission_energy_multiplier = 0.8  # Increased for better feedback
		voxel_mesh.material_override = material
	
	# Emit signal
	voxel_selected.emit(voxel_mesh)
	
	if debug_mode:
		print("Selected voxels count: ", selected_voxels.size())

func clear_selection():
	if debug_mode:
		print("Clearing selection with ", selected_voxels.size(), " voxels")
	
	# Remove highlighting from all selected voxels
	var valid_voxels = 0
	for voxel_mesh in selected_voxels:
		if is_instance_valid(voxel_mesh):
			valid_voxels += 1
			var material = voxel_mesh.material_override
			if material:
				material = material.duplicate()
				material.emission_enabled = false
				voxel_mesh.material_override = material
	
	if debug_mode and valid_voxels < selected_voxels.size():
		print("Warning: Some selected voxels are no longer valid (", selected_voxels.size() - valid_voxels, " invalid)")
	
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
		is_dragging_selected_voxel = false
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
	if not camera or move_start_positions.is_empty() or not voxel_container or not is_dragging_selected_voxel:
		return
	
	var mouse_pos = get_viewport().get_mouse_position()
	
	# Skip if mouse is over UI to prevent unwanted movements
	if _is_mouse_over_ui(mouse_pos):
		return
		
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000
	
	# Cast ray to find target position
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
		
		# Calculate the movement delta in world space
		var world_delta = hit_pos - drag_start_world_pos
		
		# Convert to grid units
		var grid_delta = Vector3i(
			round(world_delta.x / voxel_size),
			round(world_delta.y / voxel_size),
			round(world_delta.z / voxel_size)
		)
		
		# Only update if the grid position has changed
		if grid_delta != move_grid_offset:
			move_grid_offset = grid_delta
			
			# Update visual positions of all selected voxels
			for voxel_mesh in selected_voxels:
				if voxel_mesh.has_meta("voxel_key"):
					var voxel_key = voxel_mesh.get_meta("voxel_key")
					var parent_editor = get_parent()
					if parent_editor and parent_editor.current_voxel_data.has(voxel_key):
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
