extends Node
class_name Component

var owner_entity: Node3D = null
var _is_initialized: bool = false

func initialize(entity: Node3D) -> void:
	if _is_initialized:
		return
	
	owner_entity = entity
	_on_initialize()
	_is_initialized = true

func _on_initialize() -> void:
	# Virtual method to be overridden by child components
	pass

func _process(delta: float) -> void:
	if _is_initialized:
		_on_process(delta)

func _physics_process(delta: float) -> void:
	if _is_initialized:
		_on_physics_process(delta)

func _on_process(delta: float) -> void:
	# Virtual method to be overridden by child components
	pass

func _on_physics_process(delta: float) -> void:
	# Virtual method to be overridden by child components
	pass

func get_component(component_type) -> Node:
	if not _is_initialized or not owner_entity:
		Logger.error("Cannot get component: Component not initialized", "Component")
		return null
		
	for child in owner_entity.get_children():
		if child is component_type:
			return child
	
	Logger.warning("Component not found: %s" % component_type, "Component")
	return null
