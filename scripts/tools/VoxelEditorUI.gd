# scripts/tools/VoxelEditorUI.gd
class_name VoxelEditorUI
extends Node

signal color_changed(color)
signal material_type_changed(type)
signal apply_to_selected()
signal delete_selected()
signal duplicate_selected()
signal move_toggled(enabled)
signal add_voxel_toggled(enabled)
signal undo_pressed()
signal redo_pressed()
signal load_model_pressed()
signal save_model_pressed()
signal show_grid_toggled(enabled)
signal show_wireframe_toggled(enabled)

var ui_root: Control
var selection_box: Panel
var status_label: Label
var color_picker: ColorPickerButton
var material_dropdown: OptionButton

var material_types = ["metal", "armor", "turret", "glass", "engine"]

func setup_ui(ui_node: Control):
	ui_root = ui_node
	
	# Get UI element references
	selection_box = ui_root.get_node("SelectionBox")
	status_label = ui_root.get_node("StatusPanel/StatusLabel")
	color_picker = ui_root.get_node("PropertyPanel/VBoxContainer/ColorPicker")
	material_dropdown = ui_root.get_node("PropertyPanel/VBoxContainer/MaterialType")
	
	# Setup material dropdown
	for mat_type in material_types:
		material_dropdown.add_item(mat_type.capitalize())
	
	# Connect UI signals
	color_picker.color_changed.connect(_on_color_picker_changed)
	material_dropdown.item_selected.connect(_on_material_selected)
	
	# Connect buttons
	_connect_button("PropertyPanel/VBoxContainer/ApplyButton", apply_to_selected)
	_connect_button("PropertyPanel/VBoxContainer/DeleteButton", delete_selected)
	_connect_button("PropertyPanel/VBoxContainer/DuplicateButton", duplicate_selected)
	_connect_button_toggle("PropertyPanel/VBoxContainer/MoveButton", move_toggled)
	_connect_button_toggle("PropertyPanel/VBoxContainer/AddVoxelButton", add_voxel_toggled)
	_connect_button("PropertyPanel/VBoxContainer/UndoButton", undo_pressed)
	_connect_button("PropertyPanel/VBoxContainer/RedoButton", redo_pressed)
	_connect_button("PropertyPanel/VBoxContainer/LoadModelButton", load_model_pressed)
	_connect_button("PropertyPanel/VBoxContainer/SaveModelButton", save_model_pressed)
	
	# Connect view controls
	_connect_checkbox("ViewControls/VBoxContainer/ShowGridCheck", show_grid_toggled)
	_connect_checkbox("ViewControls/VBoxContainer/ShowWireframeCheck", show_wireframe_toggled)
	
	# Setup selection box style
	_setup_selection_box()

func _connect_button(path: String, signal_to_emit: Signal):
	var button = ui_root.get_node_or_null(path)
	if button:
		button.pressed.connect(signal_to_emit.emit)

func _connect_button_toggle(path: String, signal_to_emit: Signal):
	var button = ui_root.get_node_or_null(path)
	if button:
		button.toggled.connect(signal_to_emit.emit)

func _connect_checkbox(path: String, signal_to_emit: Signal):
	var checkbox = ui_root.get_node_or_null(path)
	if checkbox:
		checkbox.toggled.connect(signal_to_emit.emit)

func _setup_selection_box():
	selection_box.visible = false
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.6, 1.0, 0.2)
	style.border_color = Color(0.3, 0.6, 1.0, 0.8)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	selection_box.add_theme_stylebox_override("panel", style)

func _on_color_picker_changed(color: Color):
	color_changed.emit(color)

func _on_material_selected(index: int):
	material_type_changed.emit(material_types[index])

func update_selection_count(count: int):
	if count == 0:
		status_label.text = "No voxels selected"
	else:
		status_label.text = str(count) + " voxels selected"

func set_buttons_enabled(enabled: bool):
	_set_button_enabled("PropertyPanel/VBoxContainer/ApplyButton", enabled)
	_set_button_enabled("PropertyPanel/VBoxContainer/DeleteButton", enabled)
	_set_button_enabled("PropertyPanel/VBoxContainer/DuplicateButton", enabled)
	_set_button_enabled("PropertyPanel/VBoxContainer/MoveButton", enabled)

func _set_button_enabled(path: String, enabled: bool):
	var button = ui_root.get_node_or_null(path)
	if button:
		button.disabled = !enabled

func show_status(message: String):
	status_label.text = message

func show_selection_box(start_pos: Vector2, end_pos: Vector2):
	selection_box.visible = true
	selection_box.position = Vector2(min(start_pos.x, end_pos.x), min(start_pos.y, end_pos.y))
	selection_box.size = Vector2(abs(end_pos.x - start_pos.x), abs(end_pos.y - start_pos.y))

func hide_selection_box():
	selection_box.visible = false
