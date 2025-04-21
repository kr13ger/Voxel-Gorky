# scripts/tools/VoxelEditor.gd
@tool
extends Node3D

# References to sub-components
var ui: VoxelEditorUI
var camera_controller: VoxelEditorCamera
var selection: VoxelEditorSelection
var operations: VoxelEditorOperations
var history: VoxelEditorHistory
var grid: VoxelEditorGrid
var ghost_voxel: VoxelEditorGhostVoxel
var file_manager: VoxelEditorFileManager

# Node references
var voxel_container: Node3D
var grid_visualizer: Node3D

# Shared state
var current_voxel_data = {}
var voxel_size = 1.0
var current_color = Color(1, 1, 1)
var current_material_type = "metal"

func _ready():
	print("VoxelEditor initializing...")
	
	# Initialize node references
	voxel_container = get_node_or_null("VoxelContainer")
	if not voxel_container:
		print("ERROR: VoxelContainer not found!")
		return
	
	grid_visualizer = get_node_or_null("GridVisualizer")
	if not grid_visualizer:
		print("ERROR: GridVisualizer not found!")
		return
	
	# Initialize sub-components
	_initialize_components()
	
	# Connect signals between components
	_connect_component_signals()
	
	print("VoxelEditor ready")

func _initialize_components():
	# UI Component
	ui = VoxelEditorUI.new()
	ui.name = "UI"
	add_child(ui)
	ui.setup_ui(get_node("UI"))
	
	# Camera Component
	camera_controller = VoxelEditorCamera.new()
	camera_controller.name = "CameraController"
	add_child(camera_controller)
	camera_controller.setup_camera(get_node("EditorCamera"))
	
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
	file_manager.setup_file_manager(self, ui.ui_root)

func _connect_component_signals():
	# Connect UI signals
	ui.color_changed.connect(_on_color_changed)
	ui.material_type_changed.connect(_on_material_type_changed)
	ui.apply_to_selected.connect(operations.apply_to_selected)
	ui.delete_selected.connect(operations.delete_selected)
	ui.duplicate_selected.connect(operations.duplicate_selected)
	ui.move_toggled.connect(selection.set_move_mode)
	ui.add_voxel_toggled.connect(ghost_voxel.set_add_mode)
	ui.undo_pressed.connect(history.undo)
	ui.redo_pressed.connect(history.redo)
	ui.load_model_pressed.connect(file_manager.show_load_dialog)
	ui.save_model_pressed.connect(file_manager.show_save_dialog)
	ui.show_grid_toggled.connect(grid.set_visible)
	ui.show_wireframe_toggled.connect(operations.set_wireframe)
	
	# Connect selection signals
	selection.voxel_selected.connect(_on_voxel_selected)
	selection.selection_cleared.connect(_on_selection_cleared)
	selection.voxels_moved.connect(operations.move_voxels)
	
	# Connect operations signals
	operations.voxel_added.connect(history.add_operation)
	operations.voxel_deleted.connect(history.add_operation)
	operations.voxel_modified.connect(history.add_operation)
	operations.voxels_moved.connect(history.add_operation)
	
	# Connect history signals
	history.state_restored.connect(_restore_state)
	
	# Connect ghost voxel signals
	ghost_voxel.voxel_placement_requested.connect(operations.add_voxel)
	
	# Connect file manager signals
	file_manager.model_loaded.connect(_on_model_loaded)
	file_manager.model_saved.connect(_on_model_saved)

func _on_color_changed(color: Color):
	current_color = color
	ghost_voxel.update_color(color)

func _on_material_type_changed(type: String):
	current_material_type = type

func _on_voxel_selected(voxel_mesh):
	ui.update_selection_count(selection.selected_voxels.size())
	ui.set_buttons_enabled(true)

func _on_selection_cleared():
	ui.update_selection_count(0)
	ui.set_buttons_enabled(false)

func _on_model_loaded(voxel_data: Dictionary, model_path: String):
	current_voxel_data = voxel_data
	operations.create_voxel_meshes(voxel_data)
	grid.update_grid(voxel_size)
	ghost_voxel.update_size(voxel_size)
	selection.voxel_size = voxel_size
	history.clear()
	ui.show_status("Loaded model with " + str(voxel_data.size()) + " voxels")

func _on_model_saved(model_path: String):
	ui.show_status("Model saved to " + model_path)

func _restore_state(state: Dictionary):
	current_voxel_data = state.voxel_data.duplicate(true)
	selection.clear_selection()
	operations.recreate_voxels(current_voxel_data)
	
	# Restore selection if needed
	for key in state.selected_keys:
		for child in voxel_container.get_children():
			if child.has_meta("voxel_key") and child.get_meta("voxel_key") == key:
				selection.select_voxel(child)
