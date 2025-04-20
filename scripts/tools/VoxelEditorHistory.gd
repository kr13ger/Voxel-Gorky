# scripts/tools/VoxelEditorHistory.gd
class_name VoxelEditorHistory
extends Node

signal state_restored(state)

var editor: Node
var history = []
var history_index = -1
var max_history = 30

func setup_history(editor_ref: Node):
	editor = editor_ref

func add_operation(operation_data: Dictionary):
	# Truncate forward history if we're in the middle
	if history_index < history.size() - 1:
		history.resize(history_index + 1)
	
	# Store the current state
	var history_state = {
		"operation": operation_data.type,
		"voxel_data": editor.current_voxel_data.duplicate(true),
		"selected_keys": []
	}
	
	# Store selected voxel keys
	for voxel in editor.selection.selected_voxels:
		if voxel.has_meta("voxel_key"):
			history_state.selected_keys.append(voxel.get_meta("voxel_key"))
	
	history.append(history_state)
	history_index = history.size() - 1
	
	# Limit history size
	if history.size() > max_history:
		history.remove_at(0)
		history_index = max(0, history_index - 1)
	
	_update_button_states()

func undo():
	if history_index <= 0:
		return
	
	history_index -= 1
	_restore_state(history_index)
	editor.ui.show_status("Undo operation")

func redo():
	if history_index >= history.size() - 1:
		return
	
	history_index += 1
	_restore_state(history_index)
	editor.ui.show_status("Redo operation")

func _restore_state(index: int):
	var state = history[index]
	state_restored.emit(state)
	_update_button_states()

func _update_button_states():
	var undo_button = editor.ui.ui_root.get_node("PropertyPanel/VBoxContainer/UndoButton")
	var redo_button = editor.ui.ui_root.get_node("PropertyPanel/VBoxContainer/RedoButton")
	
	if undo_button:
		undo_button.disabled = history_index <= 0
	if redo_button:
		redo_button.disabled = history_index >= history.size() - 1

func clear():
	history.clear()
	history_index = -1
	_update_button_states()
