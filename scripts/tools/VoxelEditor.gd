# scripts/tools/VoxelEditor.gd
@tool
extends Node3D

# References to sub-components
var ui
var camera_controller
var selection
var operations
var history
var grid
var ghost_voxel
var file_manager

# Node references
var voxel_container: Node3D
var grid_visualizer: Node3D
var ui_root: Control

# Shared state
var current_voxel_data = {}
var voxel_size = 1.0
var current_color = Color(0.6, 0.6, 0.8)
var current_material_type = "metal"

func _ready():
	print("VoxelEditor initializing...")
	
	# Initialize node references
	voxel_container = get_node_or_null("VoxelContainer")
	if not voxel_container:
		print("ERROR: VoxelContainer not found!")
		voxel_container = Node3D.new()
		voxel_container.name = "VoxelContainer"
		add_child(voxel_container)
	
	grid_visualizer = get_node_or_null("GridVisualizer")
	if not grid_visualizer:
		print("ERROR: GridVisualizer not found!")
		grid_visualizer = Node3D.new()
		grid_visualizer.name = "GridVisualizer"
		add_child(grid_visualizer)

	ui_root = get_node_or_null("UI")
	if not ui_root:
		print("ERROR: UI not found!")
		return
	
	# Initialize sub-components
	_initialize_components()
	
	# Connect signals between components
	_connect_component_signals()
	
	print("VoxelEditor ready")

func _initialize_components():
	# UI Component
	ui = VoxelEditorUI.new()
	ui.name = "UIManager"
	add_child(ui)
	ui.setup_ui(ui_root)
	
	# Camera Component
	camera_controller = VoxelEditorCamera.new()
	camera_controller.name = "CameraController"
	add_child(camera_controller)
	var editor_camera = get_node_or_null("EditorCamera")
	if editor_camera:
		camera_controller.setup_camera(editor_camera)
	
	# Selection Component
	selection = VoxelEditorSelection.new()
	selection.name = "SelectionManager"
	add_child(selection)
	selection.setup_selection(ui.selection_box, camera_controller.camera_node, voxel_container)
	selection.voxel_size = voxel_size
	
	# Operations Component
	operations = VoxelEditorOperations.new()
	operations.name = "OperationsManager"
	add_child(operations)
	operations.setup_operations(voxel_container, self)
	
	# History Component
	history = VoxelEditorHistory.new()
	history.name = "HistoryManager"
	add_child(history)
	history.setup_history(self)
	
	# Grid Component
	grid = VoxelEditorGrid.new()
	grid.name = "GridManager"
	add_child(grid)
	grid.setup_grid(grid_visualizer)
	
	# Ghost Voxel Component
	ghost_voxel = VoxelEditorGhostVoxel.new()
	ghost_voxel.name = "GhostVoxelManager"
	add_child(ghost_voxel)
	ghost_voxel.setup_ghost_voxel(camera_controller.camera_node, self)
	
	# File Manager Component
	file_manager = VoxelEditorFileManager.new()
	file_manager.name = "FileManager"
	add_child(file_manager)
	file_manager.setup_file_manager(self, ui_root)

# Set up selection for a voxel mesh
func _setup_voxel_selection(voxel_mesh):
	# Make sure each voxel has a working selection area
	var area = voxel_mesh.get_node_or_null("SelectionArea")
	
	if not area:
		area = Area3D.new()
		area.name = "SelectionArea"
		
		var collision_shape = CollisionShape3D.new()
		var box_shape = BoxShape3D.new()
		box_shape.size = Vector3.ONE * voxel_size
		collision_shape.shape = box_shape
		
		area.add_child(collision_shape)
		voxel_mesh.add_child(area)
	
	# Make sure the area has input monitoring enabled
	area.input_ray_pickable = true
	area.monitoring = true
	area.monitorable = true
	
	# Connect input event
	if area.has_signal("input_event") and not area.is_connected("input_event", _on_voxel_input_event):
		area.connect("input_event", _on_voxel_input_event.bind(voxel_mesh))

# Handle input on voxels
func _on_voxel_input_event(_camera, event, _clicked_pos, _normal, _shape_idx, voxel_mesh):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Select the voxel if not dragging for box selection
			if selection and not selection.is_dragging:
				if Input.is_key_pressed(KEY_SHIFT):
					# Add to selection with shift
					selection.select_voxel(voxel_mesh)
				else:
					# Clear previous selection and select this one
					selection.clear_selection()
					selection.select_voxel(voxel_mesh)

func _connect_component_signals():
	# Connect UI signals if UI is valid
	if ui:
		if ui.has_signal("color_changed"):
			ui.connect("color_changed", _on_color_changed)
		if ui.has_signal("material_type_changed"):
			ui.connect("material_type_changed", _on_material_type_changed)
		if ui.has_signal("apply_to_selected"):
			ui.connect("apply_to_selected", _on_apply_to_selected)
		if ui.has_signal("delete_selected"):
			ui.connect("delete_selected", _on_delete_selected)
		if ui.has_signal("duplicate_selected"):
			ui.connect("duplicate_selected", _on_duplicate_selected)
		if ui.has_signal("move_toggled"):
			ui.connect("move_toggled", _on_move_toggled)
		if ui.has_signal("add_voxel_toggled"):
			ui.connect("add_voxel_toggled", _on_add_voxel_toggled)
		if ui.has_signal("undo_pressed"):
			ui.connect("undo_pressed", _on_undo_pressed)
		if ui.has_signal("redo_pressed"):
			ui.connect("redo_pressed", _on_redo_pressed)
		if ui.has_signal("load_model_pressed"):
			ui.connect("load_model_pressed", _on_load_model_pressed)
		if ui.has_signal("save_model_pressed"):
			ui.connect("save_model_pressed", _on_save_model_pressed)
		if ui.has_signal("show_grid_toggled"):
			ui.connect("show_grid_toggled", _on_show_grid_toggled)
		if ui.has_signal("show_wireframe_toggled"):
			ui.connect("show_wireframe_toggled", _on_show_wireframe_toggled)
	
	# Connect selection signals if selection is valid
	if selection:
		if selection.has_signal("voxel_selected"):
			selection.connect("voxel_selected", _on_voxel_selected)
		if selection.has_signal("selection_cleared"):
			selection.connect("selection_cleared", _on_selection_cleared)
		if selection.has_signal("voxels_moved"):
			selection.connect("voxels_moved", _on_voxels_moved)
	
	# Connect operations signals if operations is valid
	if operations:
		if operations.has_signal("voxel_added"):
			operations.connect("voxel_added", _on_voxel_added)
		if operations.has_signal("voxel_deleted"):
			operations.connect("voxel_deleted", _on_voxel_deleted)
		if operations.has_signal("voxel_modified"):
			operations.connect("voxel_modified", _on_voxel_modified)
		if operations.has_signal("voxels_moved"):
			operations.connect("voxels_moved", _on_voxels_moved)
	
	# Connect history signals if history is valid
	if history and history.has_signal("state_restored"):
		history.connect("state_restored", _on_state_restored)
	
	# Connect ghost voxel signals if ghost_voxel is valid
	if ghost_voxel and ghost_voxel.has_signal("voxel_placement_requested"):
		ghost_voxel.connect("voxel_placement_requested", _on_voxel_placement_requested)
	
	# Connect file manager signals if file_manager is valid
	if file_manager:
		if file_manager.has_signal("model_loaded"):
			file_manager.connect("model_loaded", _on_model_loaded)
		if file_manager.has_signal("model_saved"):
			file_manager.connect("model_saved", _on_model_saved)

# Custom implementation of operations
func _apply_to_selected():
	if not selection or selection.selected_voxels.is_empty():
		if ui:
			ui.show_status("No voxels selected")
		return
	
	var modified_keys = []
	
	for voxel_mesh in selection.selected_voxels:
		if voxel_mesh.has_meta("voxel_key"):
			var voxel_key = voxel_mesh.get_meta("voxel_key")
			modified_keys.append(voxel_key)
			
			# Apply material type and color
			if current_voxel_data.has(voxel_key):
				current_voxel_data[voxel_key]["type"] = current_material_type
				
				# Update visual representation
				var mat = StandardMaterial3D.new()
				mat.albedo_color = current_color
				
				# Add emission for selected effect
				mat.emission_enabled = true
				mat.emission = Color(0.3, 0.3, 0.3)
				mat.emission_energy = 0.5
				
				if current_material_type == "glass":
					mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					mat.albedo_color.a = 0.7
				else:
					mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				
				voxel_mesh.material_override = mat
	
	if operations and operations.has_signal("voxel_modified"):
		operations.emit_signal("voxel_modified", {"type": "modify", "keys": modified_keys})
	
	if ui:
		ui.show_status("Applied changes to " + str(modified_keys.size()) + " voxels")

func _delete_selected():
	if not selection or selection.selected_voxels.is_empty():
		if ui:
			ui.show_status("No voxels selected")
		return
	
	var deleted_keys = []
	var deleted_count = 0
	
	# Create a copy of the array since we'll be modifying it
	var selected_copy = selection.selected_voxels.duplicate()
	
	for voxel_mesh in selected_copy:
		if voxel_mesh.has_meta("voxel_key"):
			var voxel_key = voxel_mesh.get_meta("voxel_key")
			deleted_keys.append(voxel_key)
			
			if current_voxel_data.has(voxel_key):
				current_voxel_data.erase(voxel_key)
				deleted_count += 1
			
			# Remove from selection first
			selection.selected_voxels.erase(voxel_mesh)
			
			# Delete the mesh
			voxel_mesh.queue_free()
	
	if operations and operations.has_signal("voxel_deleted"):
		operations.emit_signal("voxel_deleted", {"type": "delete", "keys": deleted_keys})
	
	if ui:
		ui.update_selection_count(selection.selected_voxels.size())
		ui.show_status("Deleted " + str(deleted_count) + " voxels")

func _duplicate_selected():
	if not selection or selection.selected_voxels.is_empty():
		if ui:
			ui.show_status("No voxels selected")
		return
	
	var new_voxels = []
	var offset = Vector3i(1, 0, 0)  # Offset in x direction
	
	for voxel_mesh in selection.selected_voxels:
		if voxel_mesh.has_meta("voxel_key"):
			var voxel_key = voxel_mesh.get_meta("voxel_key")
			
			if current_voxel_data.has(voxel_key):
				var original_voxel = current_voxel_data[voxel_key]
				var original_pos = original_voxel["position"]
				
				var new_pos = Vector3i(original_pos.x, original_pos.y, original_pos.z) + offset
				var new_key = "%d,%d,%d" % [new_pos.x, new_pos.y, new_pos.z]
				
				# Skip if destination already has a voxel
				if current_voxel_data.has(new_key):
					continue
				
				# Create new voxel data
				var new_voxel = {
					"type": original_voxel["type"],
					"position": new_pos,
					"health": original_voxel.get("health", 50.0),
					"instance": null
				}
				
				# Add to data
				current_voxel_data[new_key] = new_voxel
				
				# Create visual representation
				if operations:
					var new_mesh = operations.create_voxel_mesh(new_key, new_voxel)
					if voxel_container and new_mesh:
						voxel_container.add_child(new_mesh)
						
						# Set up selection for the new voxel
						_setup_voxel_selection(new_mesh)
						
						new_voxels.append(new_mesh)
	
	# Clear selection and select only the new voxels
	if selection:
		selection.clear_selection()
		for voxel in new_voxels:
			selection.select_voxel(voxel)
	
	if operations and operations.has_signal("voxel_added"):
		operations.emit_signal("voxel_added", {"type": "duplicate", "count": new_voxels.size()})
	
	if ui:
		ui.show_status("Duplicated " + str(new_voxels.size()) + " voxels")

# UI Event Handlers
func _on_color_changed(color: Color):
	current_color = color
	if ghost_voxel:
		ghost_voxel.update_color(color)

func _on_material_type_changed(type: String):
	current_material_type = type

func _on_apply_to_selected():
	_apply_to_selected()

func _on_delete_selected():
	_delete_selected()

func _on_duplicate_selected():
	_duplicate_selected()

func _on_move_toggled(enabled: bool):
	if selection:
		selection.set_move_mode(enabled)
	
	if ui:
		if enabled:
			ui.show_status("Move mode enabled. Select and drag voxels.")
		else:
			ui.show_status("Move mode disabled.")

func _on_add_voxel_toggled(enabled: bool):
	if ghost_voxel:
		ghost_voxel.set_add_mode(enabled)

func _on_undo_pressed():
	if history:
		history.undo()

func _on_redo_pressed():
	if history:
		history.redo()

func _on_load_model_pressed():
	if file_manager:
		file_manager.show_load_dialog()

func _on_save_model_pressed():
	if file_manager:
		file_manager.show_save_dialog()

func _on_show_grid_toggled(enabled: bool):
	if grid:
		grid.set_visible(enabled)

func _on_show_wireframe_toggled(enabled: bool):
	if operations:
		operations.set_wireframe(enabled)

# Selection Event Handlers
func _on_voxel_selected(voxel_mesh):
	if ui and selection:
		ui.update_selection_count(selection.selected_voxels.size())
		ui.set_buttons_enabled(true)

func _on_selection_cleared():
	if ui:
		ui.update_selection_count(0)
		ui.set_buttons_enabled(false)

# Operations Event Handlers
func _on_voxel_added(data):
	if history:
		history.add_operation(data)

func _on_voxel_deleted(data):
	if history:
		history.add_operation(data)

func _on_voxel_modified(data):
	if history:
		history.add_operation(data)

func _on_voxels_moved(data):
	if history:
		history.add_operation(data)
	
	if operations:
		operations.move_voxels(data)

func _on_voxel_placement_requested(position: Vector3i):
	if operations:
		operations.add_voxel(position)

# File Event Handlers
func _on_model_loaded(voxel_data: Dictionary, model_path: String):
	current_voxel_data = voxel_data
	
	if operations:
		operations.recreate_voxels(voxel_data)
	
	# Set up selection for all voxels
	if voxel_container:
		for child in voxel_container.get_children():
			if child is MeshInstance3D:
				_setup_voxel_selection(child)
	
	if grid:
		grid.update_grid(voxel_size)
	
	if ghost_voxel:
		ghost_voxel.update_size(voxel_size)
	
	if selection:
		selection.voxel_size = voxel_size
	
	if history:
		history.clear()
	
	if ui:
		ui.show_status("Loaded model with " + str(voxel_data.size()) + " voxels from " + model_path)

func _on_model_saved(model_path: String):
	if ui:
		ui.show_status("Model saved to " + model_path)

# History Event Handlers
func _on_state_restored(state: Dictionary):
	current_voxel_data = state.voxel_data.duplicate(true)
	
	if selection:
		selection.clear_selection()
	
	if operations:
		operations.recreate_voxels(current_voxel_data)
	
	# Set up selection for all voxels
	if voxel_container:
		for child in voxel_container.get_children():
			if child is MeshInstance3D:
				_setup_voxel_selection(child)
	
	# Restore selection if needed
	if selection and voxel_container:
		for key in state.selected_keys:
			for child in voxel_container.get_children():
				if child.has_meta("voxel_key") and child.get_meta("voxel_key") == key:
					selection.select_voxel(child)
