class_name VoxelModel
extends Node3D

var voxel_data: Dictionary = {}
var voxel_size: float = 0.5
var voxel_parent: Node3D

func _init():
	voxel_parent = Node3D.new()
	voxel_parent.name = "VoxelMeshes"
	add_child(voxel_parent)

func load_from_mesh(mesh_path: String) -> bool:
	if not ResourceLoader.exists(mesh_path):
		Logger.error("Mesh not found: %s" % mesh_path, "VoxelModel")
		return false
	
	var mesh_resource = load(mesh_path) as Mesh
	if not mesh_resource:
		Logger.error("Failed to load mesh: %s" % mesh_path, "VoxelModel")
		return false
	
	# Material mappings - define regions and their material types
	var material_map = {
		"metal": AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2)), # Default body
		"armor": AABB(Vector3(-1, -1, -2), Vector3(2, 0.5, 4)), # Front armor
		"turret": AABB(Vector3(-0.5, 0.5, -0.5), Vector3(1, 1, 1)), # Turret
		"glass": AABB(Vector3(-0.3, 0.3, 0.5), Vector3(0.6, 0.6, 0.3)) # Windows
	}
	
	# Voxelize the mesh
	var voxelizer = MeshVoxelizer.new()
	voxelizer.voxel_size = voxel_size
	voxel_data = voxelizer.voxelize_mesh(mesh_resource, material_map)
	
	# Create voxel meshes
	create_voxel_meshes()
	
	Logger.info("Loaded mesh as voxel model: %s with %d voxels" % [mesh_path, voxel_data.size()], "VoxelModel")
	return true

func create_voxel_meshes() -> void:
	# Clear existing meshes
	for child in voxel_parent.get_children():
		child.queue_free()
	
	# Create new meshes
	for key in voxel_data:
		var voxel = voxel_data[key]
		var pos = voxel["position"]
		
		var mesh_instance = MeshInstance3D.new()
		var cube_mesh = BoxMesh.new()
		cube_mesh.size = Vector3.ONE * voxel_size
		mesh_instance.mesh = cube_mesh
		
		# Position relative to center
		mesh_instance.position = Vector3(
			pos.x * voxel_size,
			pos.y * voxel_size,
			pos.z * voxel_size
		)
		
		# Apply material based on type
		var material = StandardMaterial3D.new()
		match voxel["type"]:
			"metal":
				material.albedo_color = Color(0.6, 0.6, 0.8)
			"armor":
				material.albedo_color = Color(0.3, 0.3, 0.4)
			"turret":
				material.albedo_color = Color(0.5, 0.5, 0.7)
			"glass":
				material.albedo_color = Color(0.8, 0.9, 1.0, 0.7)
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_:
				material.albedo_color = Color(0.7, 0.7, 0.7)
		
		mesh_instance.material_override = material
		voxel_parent.add_child(mesh_instance)
		
		# Store reference to mesh instance
		voxel["instance"] = mesh_instance
