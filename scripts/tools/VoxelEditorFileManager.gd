# scripts/tools/VoxelEditorFileManager.gd
class_name VoxelEditorFileManager
extends Node

signal model_loaded(voxel_data, model_path)
signal model_saved(model_path)

var editor: Node
var ui_root: Control
var current_file_path = ""

func setup_file_manager(editor_ref: Node, ui: Control):
	editor = editor_ref
	ui_root = ui

func show_load_dialog():
	var dialog = FileDialog.new()
	dialog.title = "Open Voxel Model"
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters = PackedStringArray(["*.tres ; Voxel Resources"])
	dialog.access = FileDialog.ACCESS_RESOURCES
	dialog.size = Vector2i(600, 400)
	
	dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	
	dialog.file_selected.connect(_on_load_file_selected)
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.close_requested.connect(func(): dialog.queue_free())
	
	editor.add_child(dialog)
	dialog.popup_centered()

func show_save_dialog():
	if editor.current_voxel_data.is_empty():
		editor.ui.show_status("No voxel data to save")
		return
	
	var dialog = FileDialog.new()
	dialog.title = "Save Voxel Model"
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.filters = PackedStringArray(["*.tres ; Voxel Resources"])
	dialog.access = FileDialog.ACCESS_RESOURCES
	dialog.size = Vector2i(600, 400)
	
	if not current_file_path.is_empty():
		dialog.current_file = current_file_path.get_file()
	else:
		dialog.current_file = "voxel_model.tres"
	
	dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	
	dialog.file_selected.connect(_on_save_file_selected)
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.close_requested.connect(func(): dialog.queue_free())
	
	editor.add_child(dialog)
	dialog.popup_centered()

func _on_load_file_selected(path: String):
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

func _on_save_file_selected(path: String):
	var resource = Resource.new()
	resource.set_meta("voxel_data", editor.current_voxel_data)
	resource.set_meta("voxel_size", editor.voxel_size)
	
	var err = ResourceSaver.save(resource, path)
	if err == OK:
		current_file_path = path
		model_saved.emit(path)
	else:
		editor.ui.show_status("Error saving model: " + str(err))
