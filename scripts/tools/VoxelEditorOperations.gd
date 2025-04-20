# scripts/tools/VoxelEditorOperations.gd
class_name VoxelEditorOperations
extends Node

signal voxel_added(operation_data)
signal voxel_deleted(operation_data)
signal voxel_modified(operation_data)
signal voxels_moved(operation_data)

var voxel_container: Node3D
var editor: Node

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
	
	# Make it selectable with input
	var area = Area3D.new()
	area.name = "SelectionArea"
	
	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3.ONE * editor.voxel_size
	collision_shape.shape = box_shape
	
	area.add_child(collision_shape)
	mesh_instance.add_child(area)
	
	area.input_event.connect(_on_voxel_input_event.bind(mesh_instance))
	
	return mesh_instance

func _on_voxel_input_event(camera, event, clicked_pos, normal, shape_idx, voxel_mesh):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			editor.selection.select_voxel(voxel_mesh)

func create_voxel_meshes(voxel_data: Dictionary):
	for child in voxel_container.get_children():
		child.queue_free()
	
	for key in voxel_data:
		var voxel_mesh = create_voxel_mesh(key, voxel_data[key])
		voxel_container.add_child(voxel_mesh)

func recreate_voxels(voxel_data: Dictionary):
	for child in voxel_container.get_children():
		child.queue_free()
	
	for key in voxel_data:
		var voxel_mesh = create_voxel_mesh(key, voxel_data[key])
		voxel_container.add_child(voxel_mesh)

func add_voxel(position: Vector3i):
	var key = "%d,%d,%d" % [position.x, position.y, position.z]
	
	if editor.current_voxel_data.has(key):
		return
	
	var new_voxel = {
		"type": editor.current_material_type,
		"position": position,
		"health": get_voxel_health(editor.current_material_type),
		"instance": null
	}
	
	editor.current_voxel_data[key] = new_voxel
	
	var new_mesh = create_voxel_mesh(key, new_voxel)
	voxel_container.add_child(new_mesh)
	
	voxel_added.emit({"type": "add", "key": key, "data": new_voxel})

func delete_selected():
	if editor.selection.selected_voxels.is_empty():
		return
	
	var deleted_keys = []
	
	for voxel_mesh in editor.selection.selected_voxels:
		var voxel_key = voxel_mesh.get_meta("voxel_key")
		deleted_keys.append(voxel_key)
		
		if editor.current_voxel_data.has(voxel_key):
			editor.current_voxel_data.erase(voxel_key)
		
		voxel_mesh.queue_free()
	
	editor.selection.clear_selection()
	voxel_deleted.emit({"type": "delete", "keys": deleted_keys})

func apply_to_selected():
	if editor.selection.selected_voxels.is_empty():
		return
	
	var modified_keys = []
	
	for voxel_mesh in editor.selection.selected_voxels:
		var voxel_key = voxel_mesh.get_meta("voxel_key")
		modified_keys.append(voxel_key)
		
		if editor.current_voxel_data.has(voxel_key):
			editor.current_voxel_data[voxel_key]["type"] = editor.current_material_type
			
			var mat = voxel_mesh.material_override.duplicate()
			mat.albedo_color = editor.current_color
			
			if editor.current_material_type == "glass":
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			else:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			
			voxel_mesh.material_override = mat
	
	voxel_modified.emit({"type": "modify", "keys": modified_keys})

func move_voxels(move_data: Dictionary):
	var moved_voxels = {}
	var keys_to_remove = []
	
	for voxel_mesh in move_data.voxels:
		var old_key = voxel_mesh.get_meta("voxel_key")
		
		if editor.current_voxel_data.has(old_key):
			var voxel_data = editor.current_voxel_data[old_key]
			var old_pos = voxel_data["position"]
			var new_pos = old_pos + move_data.offset
			var new_key = "%d,%d,%d" % [new_pos.x, new_pos.y, new_pos.z]
			
			# Skip if destination already has a voxel (that's not being moved)
			if editor.current_voxel_data.has(new_key) and not (new_key in keys_to_remove):
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
		editor.current_voxel_data.erase(key)
	
	for key in moved_voxels:
		editor.current_voxel_data[key] = moved_voxels[key]
	
	voxels_moved.emit({"type": "move", "old_keys": keys_to_remove, "new_keys": moved_voxels.keys()})

func duplicate_selected():
	if editor.selection.selected_voxels.is_empty():
		return
	
	var new_voxels = []
	var offset = Vector3i(1, 0, 0)
	
	for voxel_mesh in editor.selection.selected_voxels:
		var voxel_key = voxel_mesh.get_meta("voxel_key")
		
		if editor.current_voxel_data.has(voxel_key):
			var original_voxel = editor.current_voxel_data[voxel_key]
			var original_pos = original_voxel["position"]
			
			var new_pos = Vector3i(original_pos.x, original_pos.y, original_pos.z) + offset
			var new_key = "%d,%d,%d" % [new_pos.x, new_pos.y, new_pos.z]
			
			if editor.current_voxel_data.has(new_key):
				continue
			
			var new_voxel = {
				"type": original_voxel["type"],
				"position": new_pos,
				"health": original_voxel["health"],
				"instance": null
			}
			
			editor.current_voxel_data[new_key] = new_voxel
			
			var new_mesh = create_voxel_mesh(new_key, new_voxel)
			voxel_container.add_child(new_mesh)
			new_voxels.append(new_mesh)
	
	editor.selection.clear_selection()
	
	for voxel in new_voxels:
		editor.selection.select_voxel(voxel)

func set_wireframe(enabled: bool):
	for voxel in voxel_container.get_children():
		if voxel is MeshInstance3D:
			var mat = voxel.material_override
			if mat:
				mat = mat.duplicate()
				mat.wireframe = enabled
				voxel.material_override = mat

func get_voxel_health(voxel_type: String) -> float:
	match voxel_type:
		"metal": return 50.0
		"armor": return 80.0
		"engine": return 40.0
		"turret": return 60.0
		"glass": return 20.0
		_: return 30.0
