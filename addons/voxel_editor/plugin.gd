# addons/voxel_editor/plugin.gd
@tool
extends EditorPlugin

var editor_button

func _enter_tree():
	print("Voxel Editor plugin entering tree")
	# Add a button to the editor toolbar
	editor_button = Button.new()
	editor_button.text = "Voxel Editor"
	editor_button.tooltip_text = "Open the Voxel Editor tool"
	editor_button.icon = preload("res://addons/voxel_editor/icon.svg")
	editor_button.pressed.connect(_on_button_pressed)
	
	add_control_to_container(EditorPlugin.CONTAINER_TOOLBAR, editor_button)
	
	print("Voxel Editor plugin initialized")

func _exit_tree():
	print("Voxel Editor plugin exiting tree")
	# Clean up
	if editor_button:
		remove_control_from_container(EditorPlugin.CONTAINER_TOOLBAR, editor_button)
		editor_button.queue_free()

func _on_button_pressed():
	print("Voxel Editor button pressed")
	# Open the voxel editor scene
	var editor_scene = load("res://scenes/tools/voxel_editor.tscn")
	if editor_scene:
		print("Voxel editor scene loaded successfully")
		
		# Instantiate the editor scene
		var editor_instance = editor_scene.instantiate()
		print("Editor instance created")
		
		# Force call _ready() if needed
		if not editor_instance.is_inside_tree():
			editor_instance._ready()
		
		# Create a window for the editor
		var editor_window = Window.new()
		editor_window.title = "Voxel Editor"
		editor_window.size = Vector2i(1024, 768)
		
		# Calculate center position using proper type conversions
		var viewport_size = get_editor_interface().get_base_control().get_viewport_rect().size
		var window_size = Vector2(editor_window.size)
		editor_window.position = Vector2i((viewport_size - window_size) / 2)
		
		editor_window.visible = false  # Set false initially
		
		# Add the instance to window
		editor_window.add_child(editor_instance)
		print("Editor instance added to window")
		
		# Add to interface and show
		get_editor_interface().get_base_control().add_child(editor_window)
		editor_window.popup_centered()
		
		# Force all ready calls again
		editor_window.notification(NOTIFICATION_READY)
		
		# Connect close signal
		editor_window.close_requested.connect(editor_window.queue_free)
		
		print("Opened Voxel Editor")
	else:
		printerr("Could not load Voxel Editor scene")
