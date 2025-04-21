# scripts/tools/VoxelEditorOperations.gd
class_name VoxelEditorOperations
extends Node

signal voxel_added(operation_data)
signal voxel_deleted(operation_data)
signal voxel_modified(operation_data)
signal voxels_moved(operation_data)

var voxel_container: Node3D
var editor: Node
var debug_mode = true

func setup_operations(container: Node3D, editor_ref: Node):
	voxel_container = container
	editor = editor_ref

func create_voxel_mesh(key: String, voxel_data: Dictionary) -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()
	var cube_mesh = BoxMesh.new()
	cube_mesh.size = Vector3.ONE * editor.voxel_size * 0.95
	mesh_instance.mesh = cube_mesh
	
	var pos = voxel_data["position"]
	mesh_instance.position = Vector3(
		pos.x * editor.voxel_size,
		pos.y * editor.voxel_size,
		pos.z * editor.voxel_size
	)
	
	# Create material based on type
	var material = StandardMaterial3D.new()
	match voxel_data["type"]:
		"metal":
			material.albedo_color = Color(0.6, 0.6, 0.8)
		"armor":
			material.albedo_color = Color(0.3, 0.3, 0.4)
		"turret":
			material.albedo_color = Color(0.5, 0.5, 0.7)
		"glass":
			material.albedo_color = Color(0.8, 0.9, 1.0, 0.7)
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		"engine":
			material.albedo_color = Color(0.7, 0.3, 0.3)
		_:
			material.albedo_color = Color(0.7, 0.7, 0.7)
	
	mesh_instance.material_override = material
	mesh_instance.set_meta("voxel_key", key)
	
	# Add a selection area to make it selectable
	var area = Area3D.new()
	area.name = "SelectionArea"
	
	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3.ONE * editor.voxel_size
	collision_shape.shape = box_shape
	
	area.add_child(collision_shape)
	mesh_instance.add_child(area)
	
	# Configure input detection
	area.input_ray_pickable = true
	area.monitoring = true
	area.monitorable = true
	
	return mesh_instance

# FIXED: Now properly connects input events for voxel selection
func create_voxel_meshes(voxel_data: Dictionary):
	if debug_mode:
		print("Creating voxel meshes from data with ", voxel_data.size(), " voxels")
		
	# Clear existing voxels
	for child in voxel_container.get_children():
		child.queue_free()
	
	# Create new voxel meshes for each voxel in the data
	for key in voxel_data:
		var voxel_mesh = create_voxel_mesh(key, voxel_data[key])
		voxel_container.add_child(voxel_mesh)
		
		# FIX: Call the editor's setup_voxel_selection function to properly set up input events
		if editor and editor.has_method("_setup_voxel_selection"):
			editor.call("_setup_voxel_selection", voxel_mesh)
			if debug_mode:
				print("Set up selection for voxel: ", key)

func recreate_voxels(voxel_data: Dictionary):
	# Same as create_voxel_meshes, but with a different name for clarity in context
	create_voxel_meshes(voxel_data)

func add_voxel(position: Vector3i):
	var key = "%d,%d,%d" % [position.x, position.y, position.z]
	
	# Check if voxel already exists at this position
	if editor.current_voxel_data.has(key):
		editor.ui.show_status("Cannot add voxel: Position already occupied")
		return
	
	if debug_mode:
		print("Adding voxel at position: ", position)
		
	# Create new voxel data
	var new_voxel = {
		"type": editor.current_material_type,
		"position": position,
		"health": get_voxel_health(editor.current_material_type),
		"instance": null
	}
	
	# Add to data dictionary
	editor.current_voxel_data[key] = new_voxel
	
	# Create visual representation
	var new_mesh = create_voxel_mesh(key, new_voxel)
	voxel_container.add_child(new_mesh)
	
	# FIX: Set up selection for the new voxel
	if editor and editor.has_method("_setup_voxel_selection"):
		editor.call("_setup_voxel_selection", new_mesh)
	
	# Emit signal for history
	voxel_added.emit({"type": "add", "key": key, "data": new_voxel})
	editor.ui.show_status("Added new voxel at " + key)

func apply_to_selected():
	# This is implemented by the editor to correctly apply changes
	# The default operation here serves as a fallback
	if editor.selection.selected_voxels.is_empty():
		editor.ui.show_status("No voxels selected")
		return
	
	var modified_keys = []
	
	for voxel_mesh in editor.selection.selected_voxels:
		var voxel_key = voxel_mesh.get_meta("voxel_key")
		modified_keys.append(voxel_key)
		
		# Apply material type and color
		if editor.current_voxel_data.has(voxel_key):
			editor.current_voxel_data[voxel_key]["type"] = editor.current_material_type
			
			# Update visual representation
			var mat = StandardMaterial3D.new()
			mat.albedo_color = editor.current_color
			
			# Add emission for selected effect
			mat.emission_enabled = true
			mat.emission = Color(0.3, 0.3, 0.3)
			mat.emission_energy_multiplier = 0.5
			
			if editor.current_material_type == "glass":
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mat.albedo_color.a = 0.7
			else:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			
			voxel_mesh.material_override = mat
	
	voxel_modified.emit({"type": "modify", "keys": modified_keys})
	editor.ui.show_status("Applied changes to " + str(modified_keys.size()) + " voxels")

func delete_selected():
	# This is implemented by the editor to correctly handle selection updates
	# The default operation here serves as a fallback
	if editor.selection.selected_voxels.is_empty():
		editor.ui.show_status("No voxels selected")
		return
	
	var deleted_keys = []
	var deleted_count = 0
	
	# Create a copy of the array since we'll be modifying it
	var selected_copy = editor.selection.selected_voxels.duplicate()
	
	for voxel_mesh in selected_copy:
		if voxel_mesh.has_meta("voxel_key"):
			var voxel_key = voxel_mesh.get_meta("voxel_key")
			deleted_keys.append(voxel_key)
			
			if editor.current_voxel_data.has(voxel_key):
				editor.current_voxel_data.erase(voxel_key)
				deleted_count += 1
			
			# Remove from selection first
			editor.selection.selected_voxels.erase(voxel_mesh)
			
			# Delete the mesh
			voxel_mesh.queue_free()
	
	voxel_deleted.emit({"type": "delete", "keys": deleted_keys})
	editor.ui.update_selection_count(editor.selection.selected_voxels.size())
	editor.ui.show_status("Deleted " + str(deleted_count) + " voxels")

func duplicate_selected():
	# This is implemented by the editor to correctly handle selection
	# The default operation here serves as a fallback
	if editor.selection.selected_voxels.is_empty():
		editor.ui.show_status("No voxels selected")
		return
	
	var new_voxels = []
	var offset = Vector3i(1, 0, 0)  # Offset in x direction
	
	for voxel_mesh in editor.selection.selected_voxels:
		if voxel_mesh.has_meta("voxel_key"):
			var voxel_key = voxel_mesh.get_meta("voxel_key")
			
			if editor.current_voxel_data.has(voxel_key):
				var original_voxel = editor.current_voxel_data[voxel_key]
				var original_pos = original_voxel["position"]
				
				var new_pos = Vector3i(original_pos.x, original_pos.y, original_pos.z) + offset
				var new_key = "%d,%d,%d" % [new_pos.x, new_pos.y, new_pos.z]
				
				# Skip if destination already has a voxel
				if editor.current_voxel_data.has(new_key):
					continue
				
				# Create new voxel data
				var new_voxel = {
					"type": original_voxel["type"],
					"position": new_pos,
					"health": original_voxel.get("health", 50.0),
					"instance": null
				}
				
				# Add to data
				editor.current_voxel_data[new_key] = new_voxel
				
				# Create visual representation
				var new_mesh = create_voxel_mesh(new_key, new_voxel)
				voxel_container.add_child(new_mesh)
				
				# FIX: Set up selection for the new voxel
				if editor and editor.has_method("_setup_voxel_selection"):
					editor.call("_setup_voxel_selection", new_mesh)
				
				new_voxels.append(new_mesh)
	
	# Clear selection and select only the new voxels
	editor.selection.clear_selection()
	for voxel in new_voxels:
		editor.selection.select_voxel(voxel)
	
	editor.ui.show_status("Duplicated " + str(new_voxels.size()) + " voxels")
	voxel_added.emit({"type": "duplicate", "count": new_voxels.size()})

# FIXED: Improved move_voxels implementation
func move_voxels(move_data: Dictionary):
	if debug_mode:
		print("Moving voxels with offset: ", move_data.offset if move_data.has("offset") else "Unknown")
		
	var moved_keys = []
	var original_positions = {}
	var new_positions = {}
	
	# Store the original voxel data before moving
	for voxel_mesh in move_data.voxels:
		if voxel_mesh.has_meta("voxel_key"):
			var old_key = voxel_mesh.get_meta("voxel_key")
			
			if editor.current_voxel_data.has(old_key):
				var voxel_data = editor.current_voxel_data[old_key]
				var old_pos = voxel_data["position"]
				var new_pos = Vector3i(old_pos.x, old_pos.y, old_pos.z) + move_data.offset
				
				moved_keys.append(old_key)
				original_positions[old_key] = old_pos
				new_positions[old_key] = new_pos
	
	# Apply the moves
	var new_voxel_data = editor.current_voxel_data.duplicate()
	
	# Remove the old keys and add with new positions
	for old_key in moved_keys:
		if new_voxel_data.has(old_key):
			var voxel_data = new_voxel_data[old_key].duplicate()
			var new_pos = new_positions[old_key]
			var new_key = "%d,%d,%d" % [new_pos.x, new_pos.y, new_pos.z]
			
			# Skip if destination already has a voxel (that we're not moving)
			if new_voxel_data.has(new_key) and not moved_keys.has(new_key):
				if debug_mode:
					print("Destination already has a voxel: ", new_key)
				continue
			
			# Update position
			voxel_data["position"] = new_pos
			
			# Remove the old voxel and add the new one
			new_voxel_data.erase(old_key)
			new_voxel_data[new_key] = voxel_data
			
			if debug_mode:
				print("Moving voxel from ", old_key, " to ", new_key)
				
			# Update the mesh reference
			for voxel_mesh in editor.selection.selected_voxels:
				if voxel_mesh.has_meta("voxel_key") and voxel_mesh.get_meta("voxel_key") == old_key:
					voxel_mesh.set_meta("voxel_key", new_key)
					voxel_mesh.position = Vector3(new_pos.x * editor.voxel_size, new_pos.y * editor.voxel_size, new_pos.z * editor.voxel_size)
	
	# Update the editor's data
	editor.current_voxel_data = new_voxel_data
	
	# Emit moved signal for history
	voxels_moved.emit({"type": "move", "keys": moved_keys, "original_positions": original_positions, "new_positions": new_positions})
	editor.ui.show_status("Moved " + str(moved_keys.size()) + " voxels")

func set_wireframe(enabled: bool):
	for voxel in voxel_container.get_children():
		if voxel is MeshInstance3D and voxel.material_override:
			var mat = voxel.material_override.duplicate()
			mat.wireframe = enabled
			voxel.material_override = mat
	
	editor.ui.show_status("Wireframe mode " + ("enabled" if enabled else "disabled"))

func get_voxel_health(voxel_type: String) -> float:
	match voxel_type:
		"metal": return 50.0
		"armor": return 80.0
		"engine": return 40.0
		"turret": return 60.0
		"glass": return 20.0
		_: return 30.0
