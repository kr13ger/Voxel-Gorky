# scripts/tools/VoxelEditor.gd
@tool
extends Node3D

# References to important nodes
var voxel_container
var selection_box
var camera
var ui
var grid_visualizer

# For tracking selection
var selected_voxels = []
var drag_start_position = Vector2.ZERO
var is_dragging = false
var is_moving_voxels = false
var drag_mode = "select" # "select", "move"
var current_voxel_data = {}
var voxel_size = 1.0
var loaded_model_path = ""

# For editing properties
var current_color = Color(1, 1, 1)
var current_material_type = "metal"

# Material type options and colors
var material_types = ["metal", "armor", "turret", "glass", "engine"]
var material_colors = {
	"metal": Color(0.6, 0.6, 0.8),
	"armor": Color(0.3, 0.3, 0.4),
	"turret": Color(0.5, 0.5, 0.7),
	"glass": Color(0.8, 0.9, 1.0, 0.7),
	"engine": Color(0.7, 0.3, 0.3)
}

# Camera control
var camera_orbit_speed = 0.005
var camera_distance = 15.0
var camera_height = 10.0
var orbit_angle = 0.0
var is_orbiting = false
var orbit_center = Vector3.ZERO

# Grid settings
var grid_size = Vector3i(20, 10, 20)
var show_grid = true

# Operation history
var history = []
var history_index = -1
var max_history = 30

# Voxel addition
var add_mode = false
var hover_position = Vector3.ZERO
var ghost_voxel = null

# Moving voxels
var move_start_positions = {}
var move_grid_offset = Vector3i.ZERO

func _ready():
	print("!!! VoxelEditor _ready() called !!!")
	
	var button = get_node_or_null("UI/PropertyPanel/VBoxContainer/LoadModelButton")
	if button:
		print("Button found!")
		button.pressed.connect(_on_load_model)
	else:
		print("Button NOT found!")
		
	# Initialize node references
	_initialize_node_references()
	
	# Ensure UI is available before setting it up
	if not ui:
		print("CRITICAL ERROR: UI node not found!")
		return
	
	# Setup UI connections
	_setup_ui()
	
	# Setup selection box
	_setup_selection_box()
	
	# Setup grid
	_create_grid_visualization()
	
	# Create ghost voxel for additions
	_create_ghost_voxel()
	
	# Update UI states
	_update_ui_states()
	
	print("VoxelEditor ready")
# Add this after _ready() but before _setup_ui()
func _notification(what):
	if what == NOTIFICATION_READY:
		# Use call_deferred to ensure all nodes are ready
		call_deferred("_setup_ui_deferred")

func _setup_ui_deferred():
	print("Setting up UI (deferred)...")
	
	if not ui:
		print("ERROR: Cannot setup UI - UI node is null!")
		return
	
	# Try to get the button directly with get_node
	var load_button = get_node_or_null("UI/PropertyPanel/VBoxContainer/LoadModelButton")
	if load_button:
		print("LoadModelButton found with absolute path")
		var result = load_button.pressed.connect(_on_load_model)
		print("Connection result: " + str(result))
		if result == OK:
			print("Load Model button connected successfully")
		else:
			print("ERROR: Failed to connect Load Model button")
	else:
		print("ERROR: LoadModelButton not found with absolute path")
		
func _initialize_node_references():
	print("Initializing node references...")
	
	voxel_container = get_node_or_null("VoxelContainer")
	if not voxel_container:
		print("ERROR: VoxelContainer not found!")
	else:
		print("VoxelContainer found successfully")
	
	camera = get_node_or_null("EditorCamera")
	if not camera:
		print("ERROR: EditorCamera not found!")
	else:
		print("EditorCamera found successfully")
	
	ui = get_node_or_null("UI")
	if not ui:
		print("ERROR: UI not found!")
	else:
		print("UI found successfully")
	
	if ui:
		selection_box = ui.get_node_or_null("SelectionBox")
		if not selection_box:
			print("ERROR: SelectionBox not found!")
		else:
			print("SelectionBox found successfully")
	
	grid_visualizer = get_node_or_null("GridVisualizer")
	if not grid_visualizer:
		print("ERROR: GridVisualizer not found!")
	else:
		print("GridVisualizer found successfully")
	
	print("Node references initialization complete")

func _setup_ui():
	print("Setting up UI...")
	
	if not ui:
		print("ERROR: Cannot setup UI - UI node is null!")
		return
	
	# Check if PropertyPanel exists
	var property_panel = ui.get_node_or_null("PropertyPanel")
	if not property_panel:
		print("ERROR: PropertyPanel not found!")
		return
	else:
		print("PropertyPanel found successfully")
	
	# Check if VBoxContainer exists
	var vbox = property_panel.get_node_or_null("VBoxContainer")
	if not vbox:
		print("ERROR: VBoxContainer not found!")
		return
	else:
		print("VBoxContainer found successfully")
	
	# Connect Load Model button with proper path checking
	var load_button_path = "PropertyPanel/VBoxContainer/LoadModelButton"
	var load_button = ui.get_node_or_null(load_button_path)
	if load_button:
		print("LoadModelButton found at path: " + load_button_path)
		print("Connecting Load Model button...")
		var result = load_button.pressed.connect(_on_load_model)
		if result == OK:
			print("Load Model button connected successfully")
		else:
			print("ERROR: Failed to connect Load Model button, error code: " + str(result))
	else:
		print("ERROR: LoadModelButton not found at path: " + load_button_path)
		# Try alternative path directly from VBoxContainer
		load_button = vbox.get_node_or_null("LoadModelButton")
		if load_button:
			print("LoadModelButton found in VBoxContainer")
			var result = load_button.pressed.connect(_on_load_model)
			if result == OK:
				print("Load Model button connected successfully (alternative path)")
			else:
				print("ERROR: Failed to connect Load Model button, error code: " + str(result))
		else:
			print("ERROR: LoadModelButton not found in VBoxContainer either")
	
	# [Rest of your UI setup code remains the same]
	
	print("UI setup complete")

func _on_load_model():
	print("!!! Load Model button clicked !!!")
	
	if not ui:
		print("ERROR: UI is null!")
		return
	
	# Create a new FileDialog to ensure it works
	var dialog = FileDialog.new()
	dialog.title = "Open Voxel Model"
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters = PackedStringArray(["*.tres ; Voxel Resources"])
	dialog.access = FileDialog.ACCESS_RESOURCES
	dialog.size = Vector2i(600, 400)
	
	# Make it a popup
	dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	
	# Connect signals
	dialog.file_selected.connect(_on_file_dialog_selected)
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.close_requested.connect(func(): dialog.queue_free())
	
	# Add to scene
	add_child(dialog)
	
	# Show the dialog
	dialog.popup_centered()
	
	print("FileDialog created and shown")

func _on_save_model():
	print("Save Model button was clicked!")
	
	if not ui:
		print("ERROR: UI is null!")
		return
	
	if current_voxel_data.is_empty():
		var status_label = ui.get_node_or_null("StatusPanel/StatusLabel")
		if status_label:
			status_label.text = "No voxel data to save"
		return
	
	# Create a new save dialog
	var dialog = FileDialog.new()
	dialog.title = "Save Voxel Model"
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.filters = PackedStringArray(["*.tres ; Voxel Resources"])
	dialog.access = FileDialog.ACCESS_RESOURCES
	dialog.size = Vector2i(600, 400)
	
	# Set initial filename if we have one
	if not loaded_model_path.is_empty():
		dialog.current_file = loaded_model_path.get_file()
	else:
		dialog.current_file = "voxel_model.tres"
	
	# Make it a popup
	dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	
	# Connect signals
	dialog.file_selected.connect(_on_save_file_dialog_selected)
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.close_requested.connect(func(): dialog.queue_free())
	
	# Add to scene
	add_child(dialog)
	
	# Show the dialog
	dialog.popup_centered()
	
	print("Save dialog created and shown")

func _on_save_file_dialog_selected(path):
	print("Save file selected: ", path)
	_save_model_to_path(path)

func _on_file_dialog_selected(path):
	print("File selected: ", path)
	load_voxel_model(path)

func load_voxel_model(model_path):
	print("Loading voxel model: ", model_path)
	
	# Clear existing voxel container
	for child in voxel_container.get_children():
		child.queue_free()
	
	selected_voxels.clear()
	
	# Load the voxel resource
	if not ResourceLoader.exists(model_path):
		if ui and ui.has_node("StatusPanel/StatusLabel"):
			ui.get_node("StatusPanel/StatusLabel").text = "Voxel model not found: " + model_path
		return false
	
	var resource = ResourceLoader.load(model_path)
	if not resource or not resource.has_meta("voxel_data"):
		if ui and ui.has_node("StatusPanel/StatusLabel"):
			ui.get_node("StatusPanel/StatusLabel").text = "Invalid voxel resource - missing 'voxel_data' meta"
		return false
	
	# Get data and size
	current_voxel_data = resource.get_meta("voxel_data")
	if resource.has_meta("voxel_size"):
		voxel_size = resource.get_meta("voxel_size")
	
	# Create visual voxels
	_create_voxel_meshes()
	
	# Update UI
	if ui and ui.has_node("StatusPanel/StatusLabel"):
		ui.get_node("StatusPanel/StatusLabel").text = "Loaded model with " + str(current_voxel_data.size()) + " voxels"
	loaded_model_path = model_path
	
	# Reset history
	history.clear()
	history_index = -1
	_add_to_history("load")
	
	# Update grid
	_create_grid_visualization()
	
	# Update ghost voxel size
	_update_ghost_voxel_size()
	
	return true

func _save_model_to_path(path):
	# Create a resource to save
	var resource = Resource.new()
	resource.set_meta("voxel_data", current_voxel_data)
	resource.set_meta("voxel_size", voxel_size)
	
	# Save the resource
	var err = ResourceSaver.save(resource, path)
	if err == OK:
		if ui and ui.has_node("StatusPanel/StatusLabel"):
			ui.get_node("StatusPanel/StatusLabel").text = "Model saved to " + path
		loaded_model_path = path
	else:
		if ui and ui.has_node("StatusPanel/StatusLabel"):
			ui.get_node("StatusPanel/StatusLabel").text = "Error saving model: " + str(err)
# Include all other functions from the original script...
# (I've focused on the file dialog related functions for brevity, but all other functions remain the same)

func _setup_selection_box():
	selection_box.visible = false
	# Set a semi-transparent material for the selection box
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.6, 1.0, 0.2)
	style.border_color = Color(0.3, 0.6, 1.0, 0.8)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	selection_box.add_theme_stylebox_override("panel", style)

func _create_grid_visualization():
	# Clear existing grid
	for child in grid_visualizer.get_children():
		child.queue_free()
	
	# Create a new grid with lines
	var grid_material = StandardMaterial3D.new()
	grid_material.albedo_color = Color(0.5, 0.5, 0.5, 0.3)
	grid_material.flags_transparent = true
	
	var line_mesh = ImmediateMesh.new()
	var grid_instance = MeshInstance3D.new()
	grid_instance.mesh = line_mesh
	grid_instance.material_override = grid_material
	
	# Draw X lines
	line_mesh.clear_surfaces()
	line_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	
	for z in range(-grid_size.z/2, grid_size.z/2 + 1):
		for y in range(-grid_size.y/2, grid_size.y/2 + 1):
			line_mesh.surface_add_vertex(Vector3(-grid_size.x/2 * voxel_size, y * voxel_size, z * voxel_size))
			line_mesh.surface_add_vertex(Vector3(grid_size.x/2 * voxel_size, y * voxel_size, z * voxel_size))
	
	# Draw Z lines
	for x in range(-grid_size.x/2, grid_size.x/2 + 1):
		for y in range(-grid_size.y/2, grid_size.y/2 + 1):
			line_mesh.surface_add_vertex(Vector3(x * voxel_size, y * voxel_size, -grid_size.z/2 * voxel_size))
			line_mesh.surface_add_vertex(Vector3(x * voxel_size, y * voxel_size, grid_size.z/2 * voxel_size))
	
	# Draw Y lines
	for x in range(-grid_size.x/2, grid_size.x/2 + 1):
		for z in range(-grid_size.z/2, grid_size.z/2 + 1):
			line_mesh.surface_add_vertex(Vector3(x * voxel_size, -grid_size.y/2 * voxel_size, z * voxel_size))
			line_mesh.surface_add_vertex(Vector3(x * voxel_size, grid_size.y/2 * voxel_size, z * voxel_size))
	
	line_mesh.surface_end()
	
	grid_visualizer.add_child(grid_instance)
	grid_visualizer.visible = show_grid

func _create_ghost_voxel():
	ghost_voxel = MeshInstance3D.new()
	var cube_mesh = BoxMesh.new()
	cube_mesh.size = Vector3.ONE * voxel_size * 0.95
	ghost_voxel.mesh = cube_mesh
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.7, 1.0, 0.5)
	material.flags_transparent = true
	ghost_voxel.material_override = material
	
	add_child(ghost_voxel)
	ghost_voxel.visible = false

func _create_voxel_meshes():
	# Create visual representation for each voxel
	for key in current_voxel_data:
		var voxel = current_voxel_data[key]
		var voxel_mesh = _create_voxel_mesh(key, voxel)
		voxel_container.add_child(voxel_mesh)

func _create_voxel_mesh(key, voxel_data):
	var mesh_instance = MeshInstance3D.new()
	var cube_mesh = BoxMesh.new()
	cube_mesh.size = Vector3.ONE * voxel_size * 0.95  # Slightly smaller to avoid z-fighting
	mesh_instance.mesh = cube_mesh
	
	# Position voxel
	var pos = voxel_data["position"]
	mesh_instance.position = Vector3(
		pos.x * voxel_size,
		pos.y * voxel_size,
		pos.z * voxel_size
	)
	
	# Create material based on type
	var material = StandardMaterial3D.new()
	match voxel_data["type"]:
		"metal":
			material.albedo_color = material_colors["metal"]
		"armor":
			material.albedo_color = material_colors["armor"]
		"turret":
			material.albedo_color = material_colors["turret"]
		"glass":
			material.albedo_color = material_colors["glass"]
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		"engine":
			material.albedo_color = material_colors["engine"]
		_:
			material.albedo_color = Color(0.7, 0.7, 0.7)
	
	mesh_instance.material_override = material
	
	# Store the voxel key for reference
	mesh_instance.set_meta("voxel_key", key)
	
	# Make it selectable with input (we'll use area3D for collision detection)
	var area = Area3D.new()
	area.name = "SelectionArea"
	
	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3.ONE * voxel_size
	collision_shape.shape = box_shape
	
	area.add_child(collision_shape)
	mesh_instance.add_child(area)
	
	area.input_event.connect(_on_voxel_input_event.bind(mesh_instance))
	
	return mesh_instance

func _process(delta):
	# Handle auto-rotation
	if ui.get_node("ViewControls/VBoxContainer/AutoRotateCheck").button_pressed:
		orbit_angle += camera_orbit_speed * delta * 20
		_update_camera_position()
	
	# Update ghost voxel position
	if add_mode:
		_update_ghost_voxel_position()
	
	# Update voxel movement if dragging
	if is_moving_voxels and is_dragging:
		_update_moving_voxels()

func _input(event):
	# Handle camera controls
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			is_orbiting = event.pressed
		
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_distance -= 1.0
			camera_distance = max(5.0, camera_distance)
			_update_camera_position()
		
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance += 1.0
			camera_distance = min(50.0, camera_distance)
			_update_camera_position()
	
	if event is InputEventMouseMotion:
		if is_orbiting:
			orbit_angle += event.relative.x * camera_orbit_speed
			camera_height += event.relative.y * camera_orbit_speed * 5.0
			camera_height = clamp(camera_height, 5.0, 30.0)
			_update_camera_position()
	
	# Handle mouse input for selection and moving
	if not add_mode and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Start drag
				drag_start_position = event.position
				is_dragging = true
				
				if drag_mode == "move" and not selected_voxels.is_empty():
					# Start moving voxels
					is_moving_voxels = true
					_start_moving_voxels()
				elif drag_mode == "select":
					# Clear selection if not holding shift
					if not Input.is_key_pressed(KEY_SHIFT):
						_clear_selection()
			else:
				# End drag
				if is_dragging:
					is_dragging = false
					
					if is_moving_voxels:
						is_moving_voxels = false
						_finish_moving_voxels()
					elif drag_mode == "select":
						# If this was just a click (no actual drag), it's handled by _on_voxel_input_event
						if drag_start_position.distance_to(event.position) > 5:
							_process_selection_box()
					
					selection_box.visible = false
	
	# Update selection box while dragging
	if not add_mode and not is_moving_voxels and is_dragging and drag_mode == "select" and event is InputEventMouseMotion:
		_update_selection_box(drag_start_position, event.position)
	
	# Handle voxel placement in add mode
	if add_mode and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_place_voxel_at_ghost()
	
	# Handle keyboard shortcuts
	if event is InputEventKey:
		if event.pressed:
			# Delete key
			if event.keycode == KEY_DELETE:
				_delete_selected()
			
			# Ctrl+Z for undo
			if event.keycode == KEY_Z and event.ctrl_pressed:
				_on_undo()
			
			# Ctrl+Y or Ctrl+Shift+Z for redo
			if (event.keycode == KEY_Y and event.ctrl_pressed) or (event.keycode == KEY_Z and event.ctrl_pressed and event.shift_pressed):
				_on_redo()
			
			# Ctrl+D for duplicate
			if event.keycode == KEY_D and event.ctrl_pressed:
				_duplicate_selected()
			
			# Escape to exit add/move modes
			if event.keycode == KEY_ESCAPE:
				if add_mode:
					_toggle_add_mode(false)
					ui.get_node("PropertyPanel/VBoxContainer/AddVoxelButton").button_pressed = false
				elif drag_mode == "move":
					drag_mode = "select"
					ui.get_node("PropertyPanel/VBoxContainer/MoveButton").button_pressed = false
					_update_ui_states()

func _update_camera_position():
	var x = cos(orbit_angle) * camera_distance
	var z = sin(orbit_angle) * camera_distance
	camera.position = Vector3(x, camera_height, z) + orbit_center
	camera.look_at(orbit_center)

func _update_selection_box(start_pos, end_pos):
	# Update selection box visual
	selection_box.visible = true
	
	# Calculate rect in screen space
	var top_left = Vector2(min(start_pos.x, end_pos.x), min(start_pos.y, end_pos.y))
	var size = Vector2(abs(end_pos.x - start_pos.x), abs(end_pos.y - start_pos.y))
	
	# Update box position and size
	selection_box.position = top_left
	selection_box.size = size

func _process_selection_box():
	# Get the selection rectangle in screen space
	var rect = Rect2(
		Vector2(min(drag_start_position.x, get_viewport().get_mouse_position().x),
			   min(drag_start_position.y, get_viewport().get_mouse_position().y)),
		Vector2(abs(get_viewport().get_mouse_position().x - drag_start_position.x),
			   abs(get_viewport().get_mouse_position().y - drag_start_position.y))
	)
	
	# Check each voxel
	for voxel_mesh in voxel_container.get_children():
		# Convert voxel position to screen space
		var screen_pos = camera.unproject_position(voxel_mesh.global_position)
		
		# If in the selection rectangle, select it
		if rect.has_point(screen_pos):
			_select_voxel(voxel_mesh)
	
	# Add to history if we selected something
	if selected_voxels.size() > 0:
		_add_to_history("select")

func _on_voxel_input_event(camera, event, clicked_pos, normal, shape_idx, voxel_mesh):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# If not in add mode and not moving, select this voxel
			if not add_mode and drag_mode == "select":
				# Check if we were dragging
				if not is_dragging or drag_start_position.distance_to(event.position) < 5:
					if not Input.is_key_pressed(KEY_SHIFT):
						_clear_selection()
					_select_voxel(voxel_mesh)
					_add_to_history("select")

func _select_voxel(voxel_mesh):
	# Check if already selected
	if voxel_mesh in selected_voxels:
		return
	
	# Add to selection
	selected_voxels.append(voxel_mesh)
	
	# Highlight the selected voxel
	var mat = voxel_mesh.material_override.duplicate()
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.3, 0.3)
	mat.emission_energy = 0.5
	voxel_mesh.material_override = mat
	
	# Update UI
	ui.get_node("StatusPanel/StatusLabel").text = str(selected_voxels.size()) + " voxels selected"
	_update_ui_states()

func _clear_selection():
	# Remove highlight from all selected voxels
	for voxel_mesh in selected_voxels:
		var voxel_key = voxel_mesh.get_meta("voxel_key")
		if current_voxel_data.has(voxel_key):
			var voxel = current_voxel_data[voxel_key]
			
			var mat = voxel_mesh.material_override.duplicate()
			mat.emission_enabled = false
			voxel_mesh.material_override = mat
	
	selected_voxels.clear()
	ui.get_node("StatusPanel/StatusLabel").text = "No voxels selected"
	_update_ui_states()

func _update_ui_states():
	# Update button states based on selection
	var has_selection = not selected_voxels.is_empty()
	ui.get_node("PropertyPanel/VBoxContainer/ApplyButton").disabled = !has_selection
	ui.get_node("PropertyPanel/VBoxContainer/DeleteButton").disabled = !has_selection
	ui.get_node("PropertyPanel/VBoxContainer/DuplicateButton").disabled = !has_selection
	ui.get_node("PropertyPanel/VBoxContainer/MoveButton").disabled = !has_selection

func _on_color_changed(color):
	current_color = color
	
	# Update ghost voxel color if in add mode
	if add_mode and ghost_voxel:
		var mat = ghost_voxel.material_override.duplicate()
		mat.albedo_color = Color(current_color.r, current_color.g, current_color.b, 0.5)
		ghost_voxel.material_override = mat

func _on_material_type_selected(index):
	current_material_type = material_types[index]
	
	# Update current color to match the material type
	if material_colors.has(current_material_type):
		current_color = material_colors[current_material_type]
		ui.get_node("PropertyPanel/VBoxContainer/ColorPicker").color = current_color

func _apply_to_selected():
	if selected_voxels.empty():
		ui.get_node("StatusPanel/StatusLabel").text = "No voxels selected"
		return
	
	# Add to history before making changes
	_add_to_history("modify")
	
	# Apply current color and material type to all selected voxels
	for voxel_mesh in selected_voxels:
		var voxel_key = voxel_mesh.get_meta("voxel_key")
		if current_voxel_data.has(voxel_key):
			# Update data
			current_voxel_data[voxel_key]["type"] = current_material_type
			
			# Update visual
			var mat = voxel_mesh.material_override.duplicate()
			mat.albedo_color = current_color
			
			# For glass, enable transparency
			if current_material_type == "glass":
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			else:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			
			voxel_mesh.material_override = mat
			
			# Keep selection highlight
			mat.emission_enabled = true
			mat.emission = Color(0.3, 0.3, 0.3)
			mat.emission_energy = 0.5
	
	ui.get_node("StatusPanel/StatusLabel").text = "Applied changes to " + str(selected_voxels.size()) + " voxels"

func _delete_selected():
	if selected_voxels.empty():
		ui.get_node("StatusPanel/StatusLabel").text = "No voxels selected"
		return
	
	var deleted_count = selected_voxels.size()
	
	# Add to history before deleting
	_add_to_history("delete")
	
	# Delete selected voxels
	for voxel_mesh in selected_voxels:
		var voxel_key = voxel_mesh.get_meta("voxel_key")
		
		# Remove from data
		if current_voxel_data.has(voxel_key):
			current_voxel_data.erase(voxel_key)
		
		# Remove visual
		voxel_mesh.queue_free()
	
	selected_voxels.clear()
	ui.get_node("StatusPanel/StatusLabel").text = "Deleted " + str(deleted_count) + " voxels"
	_update_ui_states()

func _duplicate_selected():
	if selected_voxels.empty():
		ui.get_node("StatusPanel/StatusLabel").text = "No voxels selected"
		return
	
	# Add to history before duplicating
	_add_to_history("duplicate")
	
	var original_keys = []
	var new_voxels = []
	var offset = Vector3i(1, 0, 0)  # Offset for duplicated voxels
	
	# First pass - create new data
	for voxel_mesh in selected_voxels:
		var voxel_key = voxel_mesh.get_meta("voxel_key")
		original_keys.append(voxel_key)
		
		if current_voxel_data.has(voxel_key):
			var original_voxel = current_voxel_data[voxel_key]
			var original_pos = original_voxel["position"]
			
			# Create duplicated voxel at an offset position
			var new_pos = Vector3i(original_pos.x, original_pos.y, original_pos.z) + offset
			var new_key = "%d,%d,%d" % [new_pos.x, new_pos.y, new_pos.z]
			
			# Skip if a voxel already exists at the new position
			if current_voxel_data.has(new_key):
				continue
			
			# Create new voxel data
			var new_voxel = {
				"type": original_voxel["type"],
				"position": new_pos,
				"health": original_voxel["health"],
				"instance": null
			}
			
			current_voxel_data[new_key] = new_voxel
			
			# Create visual for the new voxel
			var new_mesh = _create_voxel_mesh(new_key, new_voxel)
			voxel_container.add_child(new_mesh)
			new_voxels.append(new_mesh)
	
	# Clear original selection
	_clear_selection()
	
	# Select the new voxels
	for voxel in new_voxels:
		_select_voxel(voxel)
	
	ui.get_node("StatusPanel/StatusLabel").text = "Duplicated " + str(new_voxels.size()) + " voxels"

func _on_add_voxel_toggled(enabled):
	_toggle_add_mode(enabled)

func _toggle_add_mode(enabled):
	add_mode = enabled
	ghost_voxel.visible = enabled
	
	# Exit move mode if entering add mode
	if enabled and drag_mode == "move":
		drag_mode = "select"
		ui.get_node("PropertyPanel/VBoxContainer/MoveButton").button_pressed = false
	
	if enabled:
		ui.get_node("StatusPanel/StatusLabel").text = "Click to place a voxel"
	else:
		ui.get_node("StatusPanel/StatusLabel").text = "Add voxel mode disabled"

func _on_move_button_toggled(enabled):
	# Can't move if nothing selected
	if enabled and selected_voxels.empty():
		ui.get_node("PropertyPanel/VBoxContainer/MoveButton").button_pressed = false
		return
	
	drag_mode = "move" if enabled else "select"
	
	# Exit add mode if entering move mode
	if enabled and add_mode:
		_toggle_add_mode(false)
		ui.get_node("PropertyPanel/VBoxContainer/AddVoxelButton").button_pressed = false
	
	if enabled:
		ui.get_node("StatusPanel/StatusLabel").text = "Drag to move selected voxels"
	else:
		ui.get_node("StatusPanel/StatusLabel").text = "Move mode disabled"

func _start_moving_voxels():
	# Record initial positions of all selected voxels
	move_start_positions.clear()
	
	for voxel_mesh in selected_voxels:
		var voxel_key = voxel_mesh.get_meta("voxel_key")
		if current_voxel_data.has(voxel_key):
			move_start_positions[voxel_key] = voxel_mesh.position
	
	move_grid_offset = Vector3i.ZERO
	
	# Add to history before moving
	_add_to_history("move_start")

func _update_moving_voxels():
	# Get movement in screen space
	var mouse_pos = get_viewport().get_mouse_position()
	
	# Convert to world space movement using raycasting
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [] # Optionally exclude objects
	
	var result = space_state.intersect_ray(query)
	
	if result:
		# Find the closest grid position
		var hit_pos = result.position
		var grid_pos = Vector3i(
			round(hit_pos.x / voxel_size),
			round(hit_pos.y / voxel_size),
			round(hit_pos.z / voxel_size)
		)
		
		# Calculate the movement offset in grid units
		var start_hit = null
		if not move_start_positions.is_empty():
			# Just use the first voxel as reference
			var first_key = move_start_positions.keys()[0]
			var first_pos = current_voxel_data[first_key]["position"]
			var current_grid_offset = grid_pos - first_pos
			
			# Only update if the grid offset changed
			if current_grid_offset != move_grid_offset:
				move_grid_offset = current_grid_offset
				
				# Move all selected voxels
				for voxel_mesh in selected_voxels:
					var voxel_key = voxel_mesh.get_meta("voxel_key")
					if current_voxel_data.has(voxel_key):
						var original_pos = current_voxel_data[voxel_key]["position"]
						voxel_mesh.position = Vector3(
							(original_pos.x + move_grid_offset.x) * voxel_size,
							(original_pos.y + move_grid_offset.y) * voxel_size,
							(original_pos.z + move_grid_offset.z) * voxel_size
						)

func _finish_moving_voxels():
	if move_grid_offset == Vector3i.ZERO:
		# No movement occurred
		return
	
	# Add to history for the finished move
	_add_to_history("move_finish")
	
	# Create new voxel data at the new positions
	var moved_voxels = {}
	var keys_to_remove = []
	
	for voxel_mesh in selected_voxels:
		var old_key = voxel_mesh.get_meta("voxel_key")
		
		if current_voxel_data.has(old_key):
			var voxel_data = current_voxel_data[old_key]
			var old_pos = voxel_data["position"]
			var new_pos = old_pos + move_grid_offset
			var new_key = "%d,%d,%d" % [new_pos.x, new_pos.y, new_pos.z]
			
			# Skip if destination already has a voxel (that's not being moved)
			if current_voxel_data.has(new_key) and not (new_key in keys_to_remove):
				continue
			
			# Create new voxel data
			var new_voxel_data = voxel_data.duplicate()
			new_voxel_data["position"] = new_pos
			
			moved_voxels[new_key] = new_voxel_data
			keys_to_remove.append(old_key)
			
			# Update the mesh meta
			voxel_mesh.set_meta("voxel_key", new_key)
		
	# Remove old voxels and add new ones
	for key in keys_to_remove:
		current_voxel_data.erase(key)
	
	for key in moved_voxels:
		current_voxel_data[key] = moved_voxels[key]
	
	ui.get_node("StatusPanel/StatusLabel").text = "Moved " + str(moved_voxels.size()) + " voxels"

func _update_ghost_voxel_position():
	# Cast ray from camera to mouse position
	var mouse_pos = get_viewport().get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	
	var result = space_state.intersect_ray(query)
	
	if result:
		# Find the closest grid position
		var hit_pos = result.position
		var normal = result.normal
		
		# Adjust position based on face normal
		var grid_pos = Vector3i(
			round((hit_pos.x + normal.x * voxel_size * 0.5) / voxel_size),
			round((hit_pos.y + normal.y * voxel_size * 0.5) / voxel_size),
			round((hit_pos.z + normal.z * voxel_size * 0.5) / voxel_size)
		)
		
		# Check if position is valid
		var key = "%d,%d,%d" % [grid_pos.x, grid_pos.y, grid_pos.z]
		
		if not current_voxel_data.has(key):
			# Valid position
			ghost_voxel.visible = true
			ghost_voxel.position = Vector3(
				grid_pos.x * voxel_size,
				grid_pos.y * voxel_size,
				grid_pos.z * voxel_size
			)
			hover_position = grid_pos
		else:
			# Invalid position
			ghost_voxel.visible = false
	else:
		ghost_voxel.visible = false

func _place_voxel_at_ghost():
	if not ghost_voxel.visible:
		return
	
	var grid_pos = hover_position
	var key = "%d,%d,%d" % [grid_pos.x, grid_pos.y, grid_pos.z]
	
	# Don't overwrite existing voxels
	if current_voxel_data.has(key):
		return
	
	# Add to history before adding a voxel
	_add_to_history("add")
	
	# Create new voxel data
	var new_voxel = {
		"type": current_material_type,
		"position": grid_pos,
		"health": _get_voxel_health(current_material_type),
		"instance": null
	}
	
	current_voxel_data[key] = new_voxel
	
	# Create visual for the new voxel
	var new_mesh = _create_voxel_mesh(key, new_voxel)
	voxel_container.add_child(new_mesh)
	
	# Select the new voxel
	_clear_selection()
	_select_voxel(new_mesh)
	
	ui.get_node("StatusPanel/StatusLabel").text = "Added new voxel at " + key

func _update_ghost_voxel_size():
	# Update ghost voxel mesh size if it exists
	if ghost_voxel:
		var cube_mesh = BoxMesh.new()
		cube_mesh.size = Vector3.ONE * voxel_size * 0.95
		ghost_voxel.mesh = cube_mesh

func _on_show_grid_toggled(toggled):
	show_grid = toggled
	grid_visualizer.visible = toggled

func _on_show_wireframe_toggled(toggled):
	for voxel in voxel_container.get_children():
		if voxel is MeshInstance3D:
			var mat = voxel.material_override
			if mat:
				mat = mat.duplicate()
				mat.wireframe = toggled
				voxel.material_override = mat

func _on_auto_rotate_toggled(toggled):
	if not toggled:
		ui.get_node("StatusPanel/StatusLabel").text = "Auto-rotate disabled"

# History operations
func _add_to_history(operation_type):
	# Truncate forward history if we're in the middle
	if history_index < history.size() - 1:
		history.resize(history_index + 1)
	
	# Store the current state
	var history_state = {
		"operation": operation_type,
		"voxel_data": current_voxel_data.duplicate(true),
		"selected_keys": []
	}
	
	# Store selected voxel keys
	for voxel in selected_voxels:
		if voxel.has_meta("voxel_key"):
			history_state.selected_keys.append(voxel.get_meta("voxel_key"))
	
	history.append(history_state)
	history_index = history.size() - 1
	
	# Limit history size
	if history.size() > max_history:
		history.remove_at(0)
		history_index = max(0, history_index - 1)
	
	# Update undo/redo button states
	ui.get_node("PropertyPanel/VBoxContainer/UndoButton").disabled = history_index <= 0
	ui.get_node("PropertyPanel/VBoxContainer/RedoButton").disabled = history_index >= history.size() - 1

func _on_undo():
	if history_index <= 0:
		return
	
	history_index -= 1
	_restore_history_state(history_index)
	
	ui.get_node("PropertyPanel/VBoxContainer/UndoButton").disabled = history_index <= 0
	ui.get_node("PropertyPanel/VBoxContainer/RedoButton").disabled = false
	
	ui.get_node("StatusPanel/StatusLabel").text = "Undo operation"

func _on_redo():
	if history_index >= history.size() - 1:
		return
	
	history_index += 1
	_restore_history_state(history_index)
	
	ui.get_node("PropertyPanel/VBoxContainer/UndoButton").disabled = false
	ui.get_node("PropertyPanel/VBoxContainer/RedoButton").disabled = history_index >= history.size() - 1
	
	ui.get_node("StatusPanel/StatusLabel").text = "Redo operation"

func _restore_history_state(index):
	var state = history[index]
	
	# Restore voxel data
	current_voxel_data = state.voxel_data.duplicate(true)
	
	# Clear and rebuild voxel container
	for child in voxel_container.get_children():
		child.queue_free()
	selected_voxels.clear()
	
	_create_voxel_meshes()
	
	# Restore selection
	for voxel in voxel_container.get_children():
		if voxel.has_meta("voxel_key") and voxel.get_meta("voxel_key") in state.selected_keys:
			_select_voxel(voxel)

# Helper function to get voxel health based on type
func _get_voxel_health(voxel_type: String) -> float:
	match voxel_type:
		"metal": return 50.0
		"armor": return 80.0
		"engine": return 40.0
		"turret": return 60.0
		"glass": return 20.0
		_: return 30.0
