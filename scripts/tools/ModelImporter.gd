extends Node

@export var model_path: String = ""
@export var output_path: String = "res://assets/models/vehicles/"
@export var voxel_size: float = 0.5
@export var use_fallback: bool = false

func _ready():
	print("ModelImporter starting...")
	
	# Create directories if they don't exist
	_ensure_directories_exist()
	
	if use_fallback or model_path.is_empty():
		print("Using fallback shape generation")
		_create_fallback_model()
	else:
		print("Attempting to voxelize model: ", model_path)
		voxelize_model()
	
func voxelize_model():
	# Check if model exists
	if not ResourceLoader.exists(model_path):
		print("Model not found: ", model_path)
		print("Creating fallback model instead")
		_create_fallback_model()
		return
	
	# Try to load the mesh
	var mesh_resource = load(model_path)
	if not mesh_resource is Mesh:
		print("Resource is not a mesh: ", model_path)
		print("Creating fallback model instead")
		_create_fallback_model()
		return
	
	print("Successfully loaded mesh: ", model_path)
	
	# Create voxelizer and process mesh
	var voxelizer = MeshVoxelizer.new()
	voxelizer.voxel_size = voxel_size
	
	# Material mappings - define regions and their material types
	var material_map = {
		"metal": AABB(Vector3(-10, -10, -10), Vector3(20, 20, 20)), # Default body
		"armor": AABB(Vector3(-10, -1, -10), Vector3(20, 2, 20)), # Bottom armor
		"turret": AABB(Vector3(-5, 2, -5), Vector3(10, 6, 10)), # Turret area
	}
	
	# Process the mesh with a timeout
	print("Starting voxelization...")
	var start_time = Time.get_ticks_msec()
	var voxel_data = voxelizer.voxelize_mesh(mesh_resource, material_map)
	var end_time = Time.get_ticks_msec()
	print("Voxelization completed in ", (end_time - start_time) / 1000.0, " seconds")
	print("Voxel count: ", voxel_data.size())
	
	# Save voxel data
	_save_voxel_data(voxel_data)
	
	# Clean up
	voxelizer.queue_free()
	
	print("Voxelization process complete!")
	get_tree().quit()

# Create a basic tank shape model if we can't load a real one
func _create_fallback_model():
	print("Creating fallback tank model...")
	
	var voxelizer = MeshVoxelizer.new()
	voxelizer.voxel_size = voxel_size
	var voxel_data = voxelizer._create_basic_shape()
	
	_save_voxel_data(voxel_data)
	
	# Clean up
	voxelizer.queue_free()
	
	print("Fallback model creation complete!")
	get_tree().quit()

# Helper to save the voxel data
func _save_voxel_data(voxel_data: Dictionary):
	# Create a resource to save
	var resource = Resource.new()
	resource.set_meta("voxel_data", voxel_data)
	resource.set_meta("voxel_size", voxel_size)
	
	# Generate filename
	var filename = "tank_voxel_model.tres"
	if not model_path.is_empty():
		filename = model_path.get_file().get_basename() + "_voxels.tres"
	
	var save_path = output_path.path_join(filename)
	
	# Make sure directory exists
	var dir = DirAccess.open("res://")
	if not dir:
		print("Could not open root directory")
		return
	
	if not DirAccess.dir_exists_absolute(output_path):
		print("Creating output directory: ", output_path)
		var err = dir.make_dir_recursive(output_path)
		if err != OK:
			print("Failed to create output directory: ", err)
			return
	
	# Save the resource
	print("Saving voxel data to: ", save_path)
	var err = ResourceSaver.save(resource, save_path)
	if err == OK:
		print("Voxel data saved successfully!")
	else:
		print("Failed to save voxel data: Error ", err)

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
