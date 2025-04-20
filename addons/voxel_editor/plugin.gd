# addons/voxel_editor/plugin.gd
@tool
extends EditorPlugin

var editor_button

func _enter_tree():
	# Add a button to the editor toolbar
	editor_button = Button.new()
	editor_button.text = "Voxel Editor"
	editor_button.tooltip_text = "Open the Voxel Editor tool"
	editor_button.icon = preload("res://addons/voxel_editor/icon.svg")
	editor_button.pressed.connect(_on_button_pressed)
	
	add_control_to_container(EditorPlugin.CONTAINER_TOOLBAR, editor_button)
	
	print("Voxel Editor plugin initialized")

func _exit_tree():
	# Clean up
	if editor_button:
		remove_control_from_container(EditorPlugin.CONTAINER_TOOLBAR, editor_button)
		editor_button.queue_free()

func _on_button_pressed():
	# Open the voxel editor scene
	var editor_scene = load("res://scenes/tools/voxel_editor.tscn")
	if editor_scene:
		var editor_instance = editor_scene.instantiate()
		get_editor_interface().get_base_control().add_child(editor_instance)
		
		# Make it modal
		editor_instance.position = get_editor_interface().get_base_control().size / 2 - editor_instance.size / 2
		
		print("Opened Voxel Editor")
	else:
		printerr("Could not load Voxel Editor scene")
