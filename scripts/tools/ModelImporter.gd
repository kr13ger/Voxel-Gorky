# scripts/tools/ModelImporter.gd
extends Node3D

@export var model_path: String = ""
@export var output_path: String = "res://assets/models/vehicles/"
@export var voxel_size: float = 0.5
@export var use_fallback: bool = false
@export_enum("Low", "Medium", "High") var detail_level: int = 0
@export var adaptive_resolution: bool = false

# UI references
@onready var model_container = $ModelContainer
@onready var grid_container = $GridContainer
@onready var preview_container = $PreviewContainer
@onready var regions_visualizer = $RegionsVisualizer
@onready var status_label = $UI/StatusPanel/StatusLabel
@onready var voxel_size_slider = $UI/ParametersPanel/VBoxContainer/GridContainer/VoxelSizeSlider
@onready var detail_options = $UI/ParametersPanel/VBoxContainer/GridContainer/DetailOptions
@onready var adaptive_check = $UI/ParametersPanel/VBoxContainer/GridContainer/AdaptiveCheck
@onready var model_path_edit = $UI/ParametersPanel/VBoxContainer/GridContainer/ModelPath
@onready var file_dialog = $UI/FileDialog
@onready var material_regions_dialog = $UI/MaterialRegionsDialog
@onready var camera = $Camera3D

# Internal variables
var loaded_model: MeshInstance3D
var grid_lines: Node3D
var preview_voxels: Node3D
var voxelizer: MeshVoxelizer
var model_aabb: AABB
var material_map: Dictionary = {}
var current_voxel_data: Dictionary = {}
var region_visualizations: Dictionary = {}

# Camera control variables
var camera_orbit_speed = 0.005
var camera_distance = 15.0
var camera_height = 10.0
var orbit_angle = 0.0
var is_orbiting = false
var orbit_center = Vector3.ZERO

func _ready():
	print("ModelImporter starting...")
	
	# Create required nodes if they don't exist in the scene
	_ensure_required_nodes()
	
	# Setup UI connections
	_setup_ui()
	
	# Create directories if they don't exist
	_ensure_directories_exist()
	
	# Set material regions dialog to hidden initially
	material_regions_dialog.hide()
	
	# Load model if specified
	if not model_path.is_empty() and not use_fallback:
		_load_model(model_path)
	else:
		_create_fallback_model_preview()
	
	# Update camera position
	_update_camera_position()

func _ensure_required_nodes():
	# Make sure all required container nodes exist
	if not has_node("ModelContainer"):
		model_container = Node3D.new()
		model_container.name = "ModelContainer"
		add_child(model_container)
	else:
		model_container = get_node("ModelContainer")
	
	if not has_node("GridContainer"):
		grid_container = Node3D.new()
		grid_container.name = "GridContainer"
		add_child(grid_container)
	else:
		grid_container = get_node("GridContainer")
	
	if not has_node("PreviewContainer"):
		preview_container = Node3D.new()
		preview_container.name = "PreviewContainer"
		add_child(preview_container)
	else:
		preview_container = get_node("PreviewContainer")
		
	if not has_node("RegionsVisualizer"):
		regions_visualizer = Node3D.new()
		regions_visualizer.name = "RegionsVisualizer"
		add_child(regions_visualizer)
	else:
		regions_visualizer = get_node("RegionsVisualizer")

# Setup UI connections
func _setup_ui():
	# Connect UI signals
	$UI/ParametersPanel/VBoxContainer/PreviewButton.pressed.connect(_on_preview_button_pressed)
	$UI/ParametersPanel/VBoxContainer/SaveButton.pressed.connect(_on_save_button_pressed)
	$UI/ParametersPanel/VBoxContainer/QuitButton.pressed.connect(_on_quit_button_pressed)
	$UI/ParametersPanel/VBoxContainer/LoadModelButton.pressed.connect(_on_load_model_button_pressed)
	
	# Connect file dialog
	if has_node("UI/ParametersPanel/VBoxContainer/BrowseModelButton"):
		$UI/ParametersPanel/VBoxContainer/BrowseModelButton.pressed.connect(_on_browse_model_button_pressed)
	file_dialog.file_selected.connect(_on_file_dialog_file_selected)
	
	# Connect material regions dialog
	if has_node("UI/ParametersPanel/VBoxContainer/EditRegionsButton"):
		$UI/ParametersPanel/VBoxContainer/EditRegionsButton.pressed.connect(_on_edit_regions_button_pressed)
	
	material_regions_dialog.get_node("Panel/VBoxContainer/HBoxContainer/CloseButton").pressed.connect(_on_regions_dialog_close)
	material_regions_dialog.get_node("Panel/VBoxContainer/HBoxContainer/ApplyButton").pressed.connect(_on_regions_dialog_apply)
	material_regions_dialog.get_node("Panel/VBoxContainer/AddMaterialButton").pressed.connect(_on_add_material_region)
	
	# Connect spinbox value changed signals
	var tabs = material_regions_dialog.get_node("Panel/VBoxContainer/RegionsTabContainer")
	for tab_idx in range(tabs.get_tab_count()):
		var tab = tabs.get_tab_control(tab_idx)
		var material_name = tab.name
		
		var min_container = tab.get_node("VBoxContainer/GridContainer/MinPosContainer")
		var max_container = tab.get_node("VBoxContainer/GridContainer/MaxPosContainer")
		
		# Connect spinboxes for min position
		min_container.get_node("XSpin").value_changed.connect(_on_region_value_changed.bind(material_name))
		min_container.get_node("YSpin").value_changed.connect(_on_region_value_changed.bind(material_name))
		min_container.get_node("ZSpin").value_changed.connect(_on_region_value_changed.bind(material_name))
		
		# Connect spinboxes for max position
		max_container.get_node("XSpin").value_changed.connect(_on_region_value_changed.bind(material_name))
		max_container.get_node("YSpin").value_changed.connect(_on_region_value_changed.bind(material_name))
		max_container.get_node("ZSpin").value_changed.connect(_on_region_value_changed.bind(material_name))
		
		# Connect color picker
		tab.get_node("VBoxContainer/GridContainer/ColorPickerButton").color_changed.connect(_on_region_color_changed.bind(material_name))
	
	voxel_size_slider.value = voxel_size
	voxel_size_slider.value_changed.connect(_on_voxel_size_changed)
	
	detail_options.selected = detail_level
	detail_options.item_selected.connect(_on_detail_level_changed)
	
	adaptive_check.button_pressed = adaptive_resolution
	adaptive_check.toggled.connect(_on_adaptive_resolution_toggled)
	
	model_path_edit.text = model_path
	model_path_edit.text_submitted.connect(_on_model_path_changed)
	
	# View control checkboxes
	$UI/ViewControls/VBoxContainer/ShowModelCheck.toggled.connect(_on_show_model_toggled)
	$UI/ViewControls/VBoxContainer/ShowGridCheck.toggled.connect(_on_show_grid_toggled)
	$UI/ViewControls/VBoxContainer/ShowPreviewCheck.toggled.connect(_on_show_preview_toggled)
	if has_node("UI/ViewControls/VBoxContainer/ShowRegionsCheck"):
		$UI/ViewControls/VBoxContainer/ShowRegionsCheck.toggled.connect(_on_show_regions_toggled)

func _process(delta):
	# Handle automatic camera orbit if enabled
	if $UI/ViewControls/VBoxContainer/AutoRotateCheck.button_pressed:
		orbit_angle += camera_orbit_speed * delta * 20
		_update_camera_position()

func _input(event):
	# Handle camera controls
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			is_orbiting = event.pressed
	
	if event is InputEventMouseMotion:
		if is_orbiting:
			orbit_angle += event.relative.x * camera_orbit_speed
			camera_height += event.relative.y * camera_orbit_speed * 5.0
			camera_height = clamp(camera_height, 5.0, 30.0)
			_update_camera_position()
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_distance -= 1.0
			camera_distance = max(5.0, camera_distance)
			_update_camera_position()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance += 1.0
			camera_distance = min(50.0, camera_distance)
			_update_camera_position()

func _update_camera_position():
	var x = cos(orbit_angle) * camera_distance
	var z = sin(orbit_angle) * camera_distance
	camera.position = Vector3(x, camera_height, z) + orbit_center
	camera.look_at(orbit_center)

# Load and display the 3D model
func _load_model(path: String):
	status_label.text = "Loading model: " + path
	
	# Clear any existing model
	for child in model_container.get_children():
		child.queue_free()
	
	# Try to load the mesh
	if not ResourceLoader.exists(path):
		status_label.text = "Model not found: " + path
		return
	
	var mesh_resource = load(path)
	if not mesh_resource is Mesh:
		status_label.text = "Resource is not a mesh: " + path
		return
	
	# Create mesh instance
	loaded_model = MeshInstance3D.new()
	loaded_model.mesh = mesh_resource
	model_container.add_child(loaded_model)
	
	# Get the model's AABB for grid sizing
	model_aabb = mesh_resource.get_aabb()
	
	# Create default material regions
	_create_default_material_map()
	
	# Create grid visualization
	_create_grid_visualization()
	
	# Update orbit center based on model
	orbit_center = model_aabb.position + model_aabb.size / 2
	_update_camera_position()
	
	# Draw material regions
	_update_material_region_visualizations()
	
	status_label.text = "Model loaded successfully: " + path

# Create default material regions based on model AABB
func _create_default_material_map():
	material_map = {
		"metal": AABB(model_aabb.position, model_aabb.size), # Default
		"armor": AABB(
			Vector3(model_aabb.position.x, model_aabb.position.y, model_aabb.position.z), 
			Vector3(model_aabb.size.x, model_aabb.size.y * 0.2, model_aabb.size.z)
		), # Bottom
		"turret": AABB(
			Vector3(
				model_aabb.position.x + model_aabb.size.x * 0.25,
				model_aabb.position.y + model_aabb.size.y * 0.7,
				model_aabb.position.z + model_aabb.size.z * 0.25
			),
			Vector3(model_aabb.size.x * 0.5, model_aabb.size.y * 0.3, model_aabb.size.z * 0.5)
		), # Top
	}
	
	# Set default region colors
	region_visualizations = {
		"metal": Color(0.6, 0.6, 0.8, 0.4),
		"armor": Color(0.3, 0.3, 0.4, 0.4),
		"turret": Color(0.5, 0.5, 0.7, 0.4)
	}

# Create a visualization of the voxel grid
func _create_grid_visualization():
	status_label.text = "Creating grid visualization..."
	
	# Clear any existing grid
	for child in grid_container.get_children():
		child.queue_free()
	
	# Calculate grid dimensions based on model AABB and voxel size
	var adjusted_voxel_size = voxel_size
	if adaptive_resolution:
		match detail_level:
			0: # Low
				adjusted_voxel_size = voxel_size
			1: # Medium
				adjusted_voxel_size = voxel_size * 0.5
			2: # High
				adjusted_voxel_size = voxel_size * 0.25
	
	grid_lines = Node3D.new()
	grid_lines.name = "GridLines"
	grid_container.add_child(grid_lines)
	
	# Calculate grid dimensions
	var grid_dimensions = Vector3i(
		ceil(model_aabb.size.x / adjusted_voxel_size),
		ceil(model_aabb.size.y / adjusted_voxel_size),
		ceil(model_aabb.size.z / adjusted_voxel_size)
	)
	
	print("Grid dimensions: ", grid_dimensions)
	
	# Create grid lines (every 5 cells to avoid too much clutter)
	var grid_step = 5
	var line_material = StandardMaterial3D.new()
	line_material.albedo_color = Color(0.5, 0.5, 1.0, 0.3) # Semi-transparent blue
	line_material.flags_transparent = true
	
	# Create a box outline showing the grid boundaries
	var box_lines = _create_box(
		model_aabb.position,
		model_aabb.position + Vector3(
			grid_dimensions.x * adjusted_voxel_size,
			grid_dimensions.y * adjusted_voxel_size,
			grid_dimensions.z * adjusted_voxel_size
		),
		Color(1, 1, 0, 0.8) # Yellow for the bounding box
	)
	grid_lines.add_child(box_lines)
	
	# Create X lines (limit to avoid too many lines)
	for y in range(0, grid_dimensions.y + 1, grid_step):
		for z in range(0, grid_dimensions.z + 1, grid_step):
			var line = _create_line(
				Vector3(0, y * adjusted_voxel_size, z * adjusted_voxel_size) + model_aabb.position,
				Vector3(grid_dimensions.x * adjusted_voxel_size, 0, 0),
				line_material
			)
			grid_lines.add_child(line)
	
	# Create Y lines
	for x in range(0, grid_dimensions.x + 1, grid_step):
		for z in range(0, grid_dimensions.z + 1, grid_step):
			var line = _create_line(
				Vector3(x * adjusted_voxel_size, 0, z * adjusted_voxel_size) + model_aabb.position,
				Vector3(0, grid_dimensions.y * adjusted_voxel_size, 0),
				line_material
			)
			grid_lines.add_child(line)
	
	# Create Z lines
	for x in range(0, grid_dimensions.x + 1, grid_step):
		for y in range(0, grid_dimensions.y + 1, grid_step):
			var line = _create_line(
				Vector3(x * adjusted_voxel_size, y * adjusted_voxel_size, 0) + model_aabb.position,
				Vector3(0, 0, grid_dimensions.z * adjusted_voxel_size),
				line_material
			)
			grid_lines.add_child(line)
	
	status_label.text = "Grid visualization created"

# Helper function to create a line
func _create_line(start: Vector3, direction: Vector3, material: Material) -> MeshInstance3D:
	var line_mesh = ImmediateMesh.new()
	var line_instance = MeshInstance3D.new()
	
	line_mesh.clear_surfaces()
	line_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	line_mesh.surface_add_vertex(start)
	line_mesh.surface_add_vertex(start + direction)
	line_mesh.surface_end()
	
	line_instance.mesh = line_mesh
	line_instance.material_override = material
	
	return line_instance

# Helper function to create a box outline
func _create_box(start: Vector3, end: Vector3, color: Color) -> Node3D:
	var box_container = Node3D.new()
	box_container.name = "BoundingBox"
	
	var line_material = StandardMaterial3D.new()
	line_material.albedo_color = color
	line_material.flags_transparent = true
	
	# Define the 8 corners of the box
	var corners = [
		Vector3(start.x, start.y, start.z),
		Vector3(end.x, start.y, start.z),
		Vector3(start.x, end.y, start.z),
		Vector3(end.x, end.y, start.z),
		Vector3(start.x, start.y, end.z),
		Vector3(end.x, start.y, end.z),
		Vector3(start.x, end.y, end.z),
		Vector3(end.x, end.y, end.z)
	]
	
	# Define the 12 edges of the box (indices of corners to connect)
	var edges = [
		[0, 1], [0, 2], [1, 3], [2, 3],  # Bottom face
		[4, 5], [4, 6], [5, 7], [6, 7],  # Top face
		[0, 4], [1, 5], [2, 6], [3, 7]   # Connecting edges
	]
	
	# Create lines for each edge
	for edge in edges:
		var line = _create_line(corners[edge[0]], corners[edge[1]] - corners[edge[0]], line_material)
		box_container.add_child(line)
	
	return box_container

# Create a preview of the voxelization result
func create_voxel_preview():
	status_label.text = "Creating voxel preview..."
	
	# Clear any existing preview
	for child in preview_container.get_children():
		child.queue_free()
	
	# Initialize voxelizer if needed
	if not voxelizer:
		voxelizer = MeshVoxelizer.new()
		add_child(voxelizer)
	
	# Configure voxelizer
	var adjusted_voxel_size = voxel_size
	if adaptive_resolution:
		match detail_level:
			0: # Low
				adjusted_voxel_size = voxel_size
			1: # Medium
				adjusted_voxel_size = voxel_size * 0.5
			2: # High
				adjusted_voxel_size = voxel_size * 0.25
	
	voxelizer.voxel_size = adjusted_voxel_size
	voxelizer.detail_level = detail_level
	
	# Process the model
	var mesh_resource
	if loaded_model:
		mesh_resource = loaded_model.mesh
	else:
		# If no model is loaded, use fallback
		return _create_fallback_model_preview()
	
	status_label.text = "Generating voxels... (this may take a moment)"
	
	# Give the UI a chance to update before the potentially intensive operation
	await get_tree().process_frame
	
	var start_time = Time.get_ticks_msec()
	current_voxel_data = voxelizer.voxelize_mesh(mesh_resource, material_map)
	var end_time = Time.get_ticks_msec()
	
	# Create preview of voxels
	preview_voxels = Node3D.new()
	preview_voxels.name = "PreviewVoxels"
	preview_container.add_child(preview_voxels)
	
	# Create a visual representation for each voxel
	var voxel_count = 0
	for key in current_voxel_data:
		var voxel = current_voxel_data[key]
		var pos = voxel["position"]
		
		var voxel_preview = MeshInstance3D.new()
		var cube_mesh = BoxMesh.new()
		cube_mesh.size = Vector3.ONE * adjusted_voxel_size * 0.9  # Slightly smaller to see boundaries
		voxel_preview.mesh = cube_mesh
		
		# Position relative to model
		voxel_preview.position = Vector3(
			pos.x * adjusted_voxel_size,
			pos.y * adjusted_voxel_size,
			pos.z * adjusted_voxel_size
		) + model_aabb.position + Vector3(adjusted_voxel_size/2, adjusted_voxel_size/2, adjusted_voxel_size/2)
		
		# Apply material based on type
		var material = StandardMaterial3D.new()
		material.flags_transparent = true
		match voxel["type"]:
			"metal":
				material.albedo_color = Color(0.6, 0.6, 0.8, 0.7)
			"armor":
				material.albedo_color = Color(0.3, 0.3, 0.4, 0.7)
			"turret":
				material.albedo_color = Color(0.5, 0.5, 0.7, 0.7)
			"glass":
				material.albedo_color = Color(0.8, 0.9, 1.0, 0.5)
			"engine":
				material.albedo_color = Color(0.7, 0.3, 0.3, 0.7)
			_:
				material.albedo_color = Color(0.7, 0.7, 0.7, 0.7)
		
		voxel_preview.material_override = material
		preview_voxels.add_child(voxel_preview)
		voxel_count += 1
		
		# Only show a limited number of voxels in the preview to avoid performance issues
		if voxel_count > 10000:
			var remaining = current_voxel_data.size() - voxel_count
			status_label.text = "Preview limited: Showing 10000/" + str(current_voxel_data.size()) + " voxels"
			break
	
	status_label.text = "Voxel preview created with " + str(current_voxel_data.size()) + " voxels in " + str((end_time - start_time) / 1000.0) + " seconds"

# Create a preview of the fallback model
func _create_fallback_model_preview():
	status_label.text = "Creating fallback model preview..."
	
	# Initialize voxelizer if needed
	if not voxelizer:
		voxelizer = MeshVoxelizer.new()
		add_child(voxelizer)
	
	# Configure voxelizer
	voxelizer.voxel_size = voxel_size
	voxelizer.detail_level = detail_level
	
	# Clear any existing preview
	for child in preview_container.get_children():
		child.queue_free()
	
	# Create fallback shape
	current_voxel_data = voxelizer._create_basic_shape()
	
	# Create preview of voxels
	preview_voxels = Node3D.new()
	preview_voxels.name = "PreviewVoxels"
	preview_container.add_child(preview_voxels)
	
	# Calculate bounds for grid
	var min_pos = Vector3(1000, 1000, 1000)
	var max_pos = Vector3(-1000, -1000, -1000)
	
	for key in current_voxel_data:
		var pos = current_voxel_data[key]["position"]
		min_pos.x = min(min_pos.x, float(pos.x))
		min_pos.y = min(min_pos.y, float(pos.y))
		min_pos.z = min(min_pos.z, float(pos.z))
		max_pos.x = max(max_pos.x, float(pos.x))
		max_pos.y = max(max_pos.y, float(pos.y))
		max_pos.z = max(max_pos.z, float(pos.z))
	
	# Set model AABB based on fallback model
	model_aabb = AABB(
		Vector3(min_pos.x - 1, min_pos.y - 1, min_pos.z - 1) * voxel_size,
		(max_pos - min_pos + Vector3(2, 2, 2)) * voxel_size
	)
	
	# Create grid visualization
	_create_grid_visualization()
	
	# Create default material regions if needed
	if material_map.is_empty():
		_create_default_material_map()
	
	# Update material region visualizations
	_update_material_region_visualizations()
	
	# Update orbit center based on model
	orbit_center = Vector3.ZERO
	_update_camera_position()
	
	# Create a visual representation for each voxel
	for key in current_voxel_data:
		var voxel = current_voxel_data[key]
		var pos = voxel["position"]
		
		var voxel_preview = MeshInstance3D.new()
		var cube_mesh = BoxMesh.new()
		cube_mesh.size = Vector3.ONE * voxel_size * 0.9  # Slightly smaller to see boundaries
		voxel_preview.mesh = cube_mesh
		
		# Position relative to origin
		voxel_preview.position = Vector3(
			pos.x * voxel_size,
			pos.y * voxel_size,
			pos.z * voxel_size
		)
		
		# Apply material based on type
		var material = StandardMaterial3D.new()
		material.flags_transparent = true
		match voxel["type"]:
			"metal":
				material.albedo_color = Color(0.6, 0.6, 0.8, 0.7)
			"armor":
				material.albedo_color = Color(0.3, 0.3, 0.4, 0.7)
			"turret":
				material.albedo_color = Color(0.5, 0.5, 0.7, 0.7)
			"glass":
				material.albedo_color = Color(0.8, 0.9, 1.0, 0.5)
			"engine":
				material.albedo_color = Color(0.7, 0.3, 0.3, 0.7)
			_:
				material.albedo_color = Color(0.7, 0.7, 0.7, 0.7)
		
		voxel_preview.material_override = material
		preview_voxels.add_child(voxel_preview)
	
	status_label.text = "Fallback model preview created with " + str(preview_voxels.get_child_count()) + " voxels"

# Save the current voxel data
func save_current_voxel_data():
	if current_voxel_data.is_empty():
		status_label.text = "No voxel data to save!"
		return
	
	# Create a resource to save
	var resource = Resource.new()
	resource.set_meta("voxel_data", current_voxel_data)
	resource.set_meta("voxel_size", voxel_size)
	resource.set_meta("detail_level", detail_level)
	
	# Generate filename with detail level
	var detail_suffix = ["_low", "_medium", "_high"][detail_level]
	var filename = "tank_voxel_model" + detail_suffix + ".tres"
	if not model_path.is_empty():
		filename = model_path.get_file().get_basename() + "_voxels" + detail_suffix + ".tres"
	
	var save_path = output_path.path_join(filename)
	
	# Save the resource
	var err = ResourceSaver.save(resource, save_path)
	if err == OK:
		status_label.text = "Voxel data saved successfully to: " + save_path
	else:
		status_label.text = "Failed to save voxel data: Error " + str(err)

# Update UI from material regions map
func _update_regions_ui_from_map():
	var tabs = material_regions_dialog.get_node("Panel/VBoxContainer/RegionsTabContainer")
	
	# Update existing tabs
	for material_name in material_map:
		var tab_idx = -1
		# Find tab for this material
		for i in range(tabs.get_tab_count()):
			if tabs.get_tab_control(i).name == material_name:
				tab_idx = i
				break
		
		# Skip if tab doesn't exist
		if tab_idx == -1:
			continue
		
		var tab = tabs.get_tab_control(tab_idx)
		var region = material_map[material_name]
		
		# Update min position spinboxes
		var min_container = tab.get_node("VBoxContainer/GridContainer/MinPosContainer")
		min_container.get_node("XSpin").value = region.position.x
		min_container.get_node("YSpin").value = region.position.y
		min_container.get_node("ZSpin").value = region.position.z
		
		# Update max position spinboxes
		var max_container = tab.get_node("VBoxContainer/GridContainer/MaxPosContainer")
		max_container.get_node("XSpin").value = region.end.x
		max_container.get_node("YSpin").value = region.end.y
		max_container.get_node("ZSpin").value = region.end.z
		
		# Update color
		if region_visualizations.has(material_name):
			tab.get_node("VBoxContainer/GridContainer/ColorPickerButton").color = region_visualizations[material_name]

# Update material regions from UI values
func _update_material_map_from_ui():
	var tabs = material_regions_dialog.get_node("Panel/VBoxContainer/RegionsTabContainer")
	
	# Update material map from UI
	for tab_idx in range(tabs.get_tab_count()):
		var tab = tabs.get_tab_control(tab_idx)
		var material_name = tab.name
		
		# Get min position values
		var min_container = tab.get_node("VBoxContainer/GridContainer/MinPosContainer")
		var min_x = min_container.get_node("XSpin").value
		var min_y = min_container.get_node("YSpin").value
		var min_z = min_container.get_node("ZSpin").value
		
		# Get max position values
		var max_container = tab.get_node("VBoxContainer/GridContainer/MaxPosContainer")
		var max_x = max_container.get_node("XSpin").value
		var max_y = max_container.get_node("YSpin").value
		var max_z = max_container.get_node("ZSpin").value
		
		# Update material map
		var min_pos = Vector3(min_x, min_y, min_z)
		var size = Vector3(max_x - min_x, max_y - min_y, max_z - min_z)
		material_map[material_name] = AABB(min_pos, size)
		
		# Update color
		var color = tab.get_node("VBoxContainer/GridContainer/ColorPickerButton").color
		region_visualizations[material_name] = color

# Update 3D visualizations of material regions
func _update_material_region_visualizations():
	# Clear existing visualizations
	for child in regions_visualizer.get_children():
		child.queue_free()
	
	# Create a box for each material region
	for material_name in material_map:
		var region = material_map[material_name]
		var color = region_visualizations.get(material_name, Color(0.7, 0.7, 0.7, 0.4))
		
		# Create box mesh for the region
		var box_mesh = BoxMesh.new()
		box_mesh.size = region.size
		
		var mesh_instance = MeshInstance3D.new()
		mesh_instance.mesh = box_mesh
		mesh_instance.position = region.position + region.size/2
		
		# Apply material
		var material = StandardMaterial3D.new()
		material.albedo_color = color
		material.flags_transparent = true
		mesh_instance.material_override = material
		
		# Add to visualizer
		mesh_instance.name = material_name + "Region"
		regions_visualizer.add_child(mesh_instance)
		
		# Also add a wireframe outline
		var wireframe = _create_box(region.position, region.end, color.lightened(0.3))
		wireframe.name = material_name + "Wireframe"
		regions_visualizer.add_child(wireframe)

# Add a new material region to the dialog
func _add_new_material_region(name: String, color: Color):
	var tabs = material_regions_dialog.get_node("Panel/VBoxContainer/RegionsTabContainer")
	
	# Create a new tab for this material
	var tab = TabBar.new()
	tab.name = name
	
	# Create contents for the tab
	var vbox = VBoxContainer.new()
	tab.add_child(vbox)
	vbox.name = "VBoxContainer"
	vbox.anchors_preset = Control.PRESET_FULL_RECT
	vbox.offset_left = 10
	vbox.offset_top = 10
	vbox.offset_right = -10
	vbox.offset_bottom = -10
	
	# Title label
	var label = Label.new()
	label.text = name.capitalize() + " Region"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)
	
	# Grid container for controls
	var grid = GridContainer.new()
	grid.columns = 2
	grid.name = "GridContainer"
	vbox.add_child(grid)
	
	# Min position controls
	var min_label = Label.new()
	min_label.text = "Min Position (X, Y, Z):"
	grid.add_child(min_label)
	
	var min_container = HBoxContainer.new()
	min_container.name = "MinPosContainer"
	min_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(min_container)
	
	var min_x = SpinBox.new()
	min_x.name = "XSpin"
	min_x.min_value = -100
	min_x.max_value = 100
	min_x.step = 0.1
	min_x.value = model_aabb.position.x if model_aabb else -5
	min_x.suffix = "x"
	min_x.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	min_container.add_child(min_x)
	
	var min_y = SpinBox.new()
	min_y.name = "YSpin"
	min_y.min_value = -100
	min_y.max_value = 100
	min_y.step = 0.1
	min_y.value = model_aabb.position.y if model_aabb else -5
	min_y.suffix = "y"
	min_y.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	min_container.add_child(min_y)
	
	var min_z = SpinBox.new()
	min_z.name = "ZSpin"
	min_z.min_value = -100
	min_z.max_value = 100
	min_z.step = 0.1
	min_z.value = model_aabb.position.z if model_aabb else -5
	min_z.suffix = "z"
	min_z.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	min_container.add_child(min_z)
	
	# Max position controls
	var max_label = Label.new()
	max_label.text = "Max Position (X, Y, Z):"
	grid.add_child(max_label)
	
	var max_container = HBoxContainer.new()
	max_container.name = "MaxPosContainer"
	max_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(max_container)
	
	var max_x = SpinBox.new()
	max_x.name = "XSpin"
	max_x.min_value = -100
	max_x.max_value = 100
	max_x.step = 0.1
	max_x.value = model_aabb.end.x if model_aabb else 5
	max_x.suffix = "x"
	max_x.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	max_container.add_child(max_x)
	
	var max_y = SpinBox.new()
	max_y.name = "YSpin"
	max_y.min_value = -100
	max_y.max_value = 100
	max_y.step = 0.1
	max_y.value = model_aabb.end.y if model_aabb else 5
	max_y.suffix = "y"
	max_y.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	max_container.add_child(max_y)
	
	var max_z = SpinBox.new()
	max_z.name = "ZSpin"
	max_z.min_value = -100
	max_z.max_value = 100
	max_z.step = 0.1
	max_z.value = model_aabb.end.z if model_aabb else 5
	max_z.suffix = "z"
	max_z.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	max_container.add_child(max_z)
	
	# Color controls
	var color_label = Label.new()
	color_label.text = "Preview Color:"
	grid.add_child(color_label)
	
	var color_picker = ColorPickerButton.new()
	color_picker.name = "ColorPickerButton"
	color_picker.color = color
	grid.add_child(color_picker)
	
	# Info label
	var info_label = Label.new()
	info_label.name = "InfoLabel"
	info_label.text = "Note: This defines a custom material region. Adjust the bounds to apply this material to specific parts of the model."
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info_label)
	
	# Add the tab to the container
	tabs.add_child(tab)
	
	# Connect signals
	min_x.value_changed.connect(_on_region_value_changed.bind(name))
	min_y.value_changed.connect(_on_region_value_changed.bind(name))
	min_z.value_changed.connect(_on_region_value_changed.bind(name))
	max_x.value_changed.connect(_on_region_value_changed.bind(name))
	max_y.value_changed.connect(_on_region_value_changed.bind(name))
	max_z.value_changed.connect(_on_region_value_changed.bind(name))
	color_picker.color_changed.connect(_on_region_color_changed.bind(name))
	
	# Add to material map and region visualizations
	var min_pos = Vector3(min_x.value, min_y.value, min_z.value)
	var size = Vector3(max_x.value - min_x.value, max_y.value - min_y.value, max_z.value - min_z.value)
	material_map[name] = AABB(min_pos, size)
	region_visualizations[name] = color
	
	# Update visualizations
	_update_material_region_visualizations()
	
	# Switch to the new tab
	tabs.current_tab = tabs.get_tab_count() - 1

# Ensure required directories exist
func _ensure_directories_exist():
	var dir = DirAccess.open("res://")
	if not dir:
		print("Could not open root directory")
		return
	
	var paths = [
		"res://assets",
		"res://assets/models",
		"res://assets/models/vehicles",
	]
	
	for path in paths:
		if not DirAccess.dir_exists_absolute(path):
			print("Creating directory: ", path)
			var err = dir.make_dir_recursive(path)
			if err != OK:
				print("Failed to create directory: ", path)

# UI callback functions
func _on_voxel_size_changed(value):
	voxel_size = value
	status_label.text = "Voxel size changed to: " + str(value)
	
	# Update grid if we have a model
	if model_aabb:
		_create_grid_visualization()

func _on_detail_level_changed(index):
	detail_level = index
	status_label.text = "Detail level changed to: " + ["Low", "Medium", "High"][index]
	
	# Update grid if we have a model
	if model_aabb:
		_create_grid_visualization()

func _on_adaptive_resolution_toggled(toggled):
	adaptive_resolution = toggled
	status_label.text = "Adaptive resolution: " + ("Enabled" if toggled else "Disabled")
	
	# Update grid if we have a model
	if model_aabb:
		_create_grid_visualization()

func _on_model_path_changed(new_path):
	model_path = new_path
	status_label.text = "Model path changed to: " + new_path
	
	# Don't automatically load the model - user should press the Load button

func _on_region_value_changed(value, material_name):
	# Update material map from UI
	_update_material_map_from_ui()
	
	# Update visualizations
	_update_material_region_visualizations()
	
	status_label.text = "Updated region for material: " + material_name

func _on_region_color_changed(color, material_name):
	# Store color in visualizations map
	region_visualizations[material_name] = color
	
	# Update visualizations
	_update_material_region_visualizations()

func _on_show_model_toggled(toggled):
	model_container.visible = toggled

func _on_show_grid_toggled(toggled):
	grid_container.visible = toggled

func _on_show_preview_toggled(toggled):
	preview_container.visible = toggled

func _on_show_regions_toggled(toggled):
	regions_visualizer.visible = toggled

func _on_load_model_button_pressed():
	if model_path.is_empty():
		status_label.text = "Please specify a model path"
		return
	
	_load_model(model_path)

func _on_browse_model_button_pressed():
	file_dialog.popup_centered()

func _on_file_dialog_file_selected(path):
	model_path = path
	model_path_edit.text = path
	_load_model(path)

func _on_edit_regions_button_pressed():
	_update_regions_ui_from_map()
	material_regions_dialog.popup_centered()

func _on_regions_dialog_close():
	material_regions_dialog.hide()

func _on_regions_dialog_apply():
	_update_material_map_from_ui()
	_update_material_region_visualizations()
	status_label.text = "Material regions updated"

func _on_add_material_region():
	# Generate a unique name
	var base_name = "custom"
	var index = 1
	var name = base_name + str(index)
	
	while material_map.has(name):
		index += 1
		name = base_name + str(index)
	
	# Add the new region
	_add_new_material_region(name, Color(0.7, 0.7, 0.7, 0.4))
	status_label.text = "Added new material region: " + name

func _on_preview_button_pressed():
	if use_fallback or model_aabb != null:
		create_voxel_preview()
	else:
		status_label.text = "Please load a model first"

func _on_save_button_pressed():
	if current_voxel_data.is_empty():
		status_label.text = "Please generate a preview first"
		return
	
	save_current_voxel_data()

func _on_quit_button_pressed():
	get_tree().quit()
