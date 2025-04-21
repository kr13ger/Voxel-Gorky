# scripts/tools/VoxelEditorFileManager.gd
class_name VoxelEditorFileManager
extends Node

signal model_loaded(voxel_data, model_path)
signal model_saved(model_path)

var editor: Node
var ui_root: Control
var file_dialog: FileDialog
var current_file_path = ""
var dialog_mode = "" # "load" or "save"

func setup_file_manager(editor_ref: Node, ui: Control):
	editor = editor_ref
	ui_root = ui
	
	# Get reference to the existing FileDialog in the scene
	file_dialog = ui_root.get_node("FileDialog")
	if file_dialog:
		# Disconnect any existing connections to avoid duplicates
		if file_dialog.file_selected.is_connected(_on_file_selected):
			file_dialog.file_selected.disconnect(_on_file_selected)
		
		# Connect signals to our handlers
		file_dialog.file_selected.connect(_on_file_selected)
		file_dialog.canceled.connect(_on_dialog_canceled)
	else:
		push_error("FileDialog not found in UI")

func show_load_dialog():
	if not file_dialog:
		editor.ui.show_status("Error: FileDialog not available")
		return
		
	dialog_mode = "load"
	file_dialog.title = "Open Voxel Model"
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.filters = PackedStringArray(["*.tres ; Voxel Resources"])
	file_dialog.access = FileDialog.ACCESS_RESOURCES
	file_dialog.popup_centered()

func show_save_dialog():
	if editor.current_voxel_data.is_empty():
		editor.ui.show_status("No voxel data to save")
		return
		
	if not file_dialog:
		editor.ui.show_status("Error: FileDialog not available")
		return
	
	dialog_mode = "save"
	file_dialog.title = "Save Voxel Model"
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.filters = PackedStringArray(["*.tres ; Voxel Resources"])
	file_dialog.access = FileDialog.ACCESS_RESOURCES
	
	if not current_file_path.is_empty():
		file_dialog.current_path = current_file_path
	else:
		file_dialog.current_path = "res://assets/models/vehicles/voxel_model.tres"
	
	file_dialog.popup_centered()

func _on_file_selected(path: String):
	if dialog_mode == "load":
		_load_file(path)
	elif dialog_mode == "save":
		_save_file(path)
	
	dialog_mode = ""

func _on_dialog_canceled():
	dialog_mode = ""

func _load_file(path: String):
	if not ResourceLoader.exists(path):
		editor.ui.show_status("Voxel model not found: " + path)
		return
	
	var resource = ResourceLoader.load(path)
	if not resource or not resource.has_meta("voxel_data"):
		editor.ui.show_status("Invalid voxel resource - missing 'voxel_data' meta")
		return
	
	var voxel_data = resource.get_meta("voxel_data")
	if resource.has_meta("voxel_size"):
		editor.voxel_size = resource.get_meta("voxel_size")
	
	current_file_path = path
	model_loaded.emit(voxel_data, path)

func _save_file(path: String):
	var resource = Resource.new()
	resource.set_meta("voxel_data", editor.current_voxel_data)
	resource.set_meta("voxel_size", editor.voxel_size)
	
	var err = ResourceSaver.save(resource, path)
	if err == OK:
		current_file_path = path
		model_saved.emit(path)
	else:
		editor.ui.show_status("Error saving model: " + str(err))
