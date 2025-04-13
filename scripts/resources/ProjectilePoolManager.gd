extends Node
class_name ProjectilePoolManager

var _projectile_pools: Dictionary = {}
var _default_pool_size: int = 10
var _projectile_scene = preload("res://scripts/Projectile.gd")

func _ready() -> void:
	SignalBus.vehicle_fired.connect(_on_vehicle_fired)

func initialize_pool(projectile_type: String, pool_size: int = -1) -> void:
	if _projectile_pools.has(projectile_type):
		Logger.debug("Projectile pool already exists: %s" % projectile_type, "ProjectilePoolManager")
		return
	
	var size = pool_size if pool_size > 0 else _default_pool_size
	var projectile_data = ItemDatabase.get_projectile_data(projectile_type)
	
	if projectile_data.is_empty():
		Logger.error("Failed to initialize pool: Invalid projectile type", "ProjectilePoolManager")
		return
	
	var prefab = null
	
	# Try to load the specified model
	if projectile_data.has("model_path") and ResourceLoader.exists(projectile_data.model_path):
		prefab = load(projectile_data.model_path)
	
	# If no model is available, create a generic projectile
	if not prefab:
		Logger.warning("Failed to load projectile prefab: %s. Using generic projectile." % projectile_data.get("model_path", "NONE"), "ProjectilePoolManager")
		prefab = _create_generic_projectile_prefab(projectile_type)
	
	var pool = ObjectPool.new(prefab, size)
	add_child(pool)
	_projectile_pools[projectile_type] = pool
	
	Logger.info("Initialized projectile pool for type: %s with size %d" % [projectile_type, size], "ProjectilePoolManager")

func get_projectile(projectile_type: String) -> Node:
	if not _projectile_pools.has(projectile_type):
		initialize_pool(projectile_type)
	
	if not _projectile_pools.has(projectile_type):
		Logger.error("Failed to get projectile: Pool not initialized", "ProjectilePoolManager")
		return null
	
	var pool = _projectile_pools[projectile_type]
	var projectile = pool.get_object()
	
	Logger.debug("Obtained projectile of type: %s from pool" % projectile_type, "ProjectilePoolManager")
	return projectile

func return_projectile(projectile: Node) -> void:
	var projectile_type = projectile.get_meta("projectile_type", "")
	
	if projectile_type.is_empty() or not _projectile_pools.has(projectile_type):
		Logger.warning("Cannot return projectile: Unknown type or pool", "ProjectilePoolManager")
		projectile.queue_free()
		return
	
	_projectile_pools[projectile_type].return_object(projectile)
	Logger.debug("Returned projectile of type: %s to pool" % projectile_type, "ProjectilePoolManager")

func _on_vehicle_fired(projectile_data: Dictionary) -> void:
	if not projectile_data.has("projectile_type") or not projectile_data.has("position") or not projectile_data.has("direction"):
		Logger.error("Invalid projectile data", "ProjectilePoolManager")
		return
	
	var projectile_type = projectile_data.projectile_type
	var position = projectile_data.position
	var direction = projectile_data.direction
	var owner = projectile_data.get("owner", null)
	
	var projectile = get_projectile(projectile_type)
	
	if not projectile:
		return
	
	if projectile is Projectile:
		projectile.initialize(projectile_type, position, direction, owner)

# Creates a generic projectile prefab to use when the specified model can't be loaded
func _create_generic_projectile_prefab(projectile_type: String) -> PackedScene:
	var scene = PackedScene.new()
	var projectile = Area3D.new()
	
	# Add projectile script
	projectile.set_script(_projectile_scene)
	
	# Create collision shape
	var collision_shape = CollisionShape3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = 0.2
	collision_shape.shape = sphere_shape
	projectile.add_child(collision_shape)
	
	# Add a simple mesh
	var mesh_instance = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.2
	sphere_mesh.height = 0.4
	mesh_instance.mesh = sphere_mesh
	
	# Apply material to identify projectile type
	var material = StandardMaterial3D.new()
	if projectile_type == "explosive_shell":
		material.albedo_color = Color(1.0, 0.2, 0.2) # Red for explosive
	else:
		material.albedo_color = Color(0.7, 0.7, 0.9) # Blue-ish for standard
	
	mesh_instance.material_override = material
	projectile.add_child(mesh_instance)
	
	# Pack the scene
	var result = scene.pack(projectile)
	if result == OK:
		return scene
	else:
		Logger.error("Failed to pack generic projectile scene", "ProjectilePoolManager")
		return null
