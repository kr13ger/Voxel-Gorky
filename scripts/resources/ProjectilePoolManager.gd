extends Node
class_name ProjectilePoolManager

var _projectile_pools: Dictionary = {}
var _default_pool_size: int = 10

func _ready() -> void:
	SignalBus.vehicle_fired.connect(_on_vehicle_fired)

func initialize_pool(projectile_type: String, pool_size: int = -1) -> void:
	if _projectile_pools.has(projectile_type):
		Logger.debug("Projectile pool already exists: %s" % projectile_type, "ProjectilePoolManager")
		return
	
	var size = pool_size if pool_size > 0 else _default_pool_size
	var projectile_data = ItemDatabase.get_projectile_data(projectile_type)
	
	if projectile_data.empty() or not projectile_data.has("model_path"):
		Logger.error("Failed to initialize pool: Invalid projectile type", "ProjectilePoolManager")
		return
	
	var model_path = projectile_data.model_path
	var prefab = load(model_path)
	
	if not prefab:
		Logger.error("Failed to load projectile prefab: %s" % model_path, "ProjectilePoolManager")
		return
	
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
