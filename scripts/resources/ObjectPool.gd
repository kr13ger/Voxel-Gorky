extends Node
class_name ObjectPool

var _prefab: PackedScene
var _pool: Array[Node] = []
var _active_objects: Array[Node] = []
var _pool_size: int

func _init(prefab: PackedScene, initial_size: int = 10) -> void:
	_prefab = prefab
	_pool_size = initial_size
	_initialize_pool()

func _initialize_pool() -> void:
	for i in range(_pool_size):
		var object = _prefab.instantiate()
		object.set_process(false)
		object.set_physics_process(false)
		object.visible = false
		_pool.append(object)
		add_child(object)

func get_object() -> Node:
	var object: Node = null
	
	if _pool.size() > 0:
		object = _pool.pop_back()
	else:
		Logger.warning("Object pool depleted, instantiating new object", "ObjectPool")
		object = _prefab.instantiate()
		add_child(object)
	
	_active_objects.append(object)
	object.set_process(true)
	object.set_physics_process(true)
	object.visible = true
	
	return object

func return_object(object: Node) -> void:
	if not object in _active_objects:
		Logger.warning("Trying to return an object that is not from this pool", "ObjectPool")
		return
	
	_active_objects.erase(object)
	_pool.append(object)
	
	object.set_process(false)
	object.set_physics_process(false)
	object.visible = false

func clear() -> void:
	for object in _active_objects:
		object.queue_free()
	
	for object in _pool:
		object.queue_free()
	
	_active_objects.clear()
	_pool.clear()
