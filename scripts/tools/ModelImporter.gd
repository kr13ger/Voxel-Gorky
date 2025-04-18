# Create a new script scripts/tools/ModelImporter.gd

extends Node

@export var model_path: String = ""
@export var output_path: String = "res://assets/models/vehicles/"
@export var voxel_size: float = 0.5
@export var resolution: int = 32

func _ready():
	if model_path.is_empty():
		print("Please specify a model path")
		return
	
	voxelize_model()
	
func voxelize_model():
	if not ResourceLoader.exists(model_path):
		print("Model not found: ", model_path)
		return
	
	var mesh_resource = load(model_path)
	if not mesh_resource is Mesh:
		print("Resource is not a mesh: ", model_path)
		return
	
	var voxelizer = MeshVoxelizer.new()
	voxelizer.voxel_size = voxel_size
	var voxel_data = voxelizer.voxelize_mesh(mesh_resource)
	
	print("Model voxelized: ", model_path)
	print("Voxel count: ", voxel_data.size())
	
	# Save voxel data as a resource
	var voxel_resource = Resource.new()
	voxel_resource.set_meta("voxel_data", voxel_data)
	voxel_resource.set_meta("voxel_size", voxel_size)
	
	var filename = model_path.get_file().get_basename() + "_voxels.tres"
	var save_path = output_path.path_join(filename)
	
	var err = ResourceSaver.save(voxel_resource, save_path)
	if err == OK:
		print("Voxel data saved to: ", save_path)
	else:
		print("Failed to save voxel data: ", err)
