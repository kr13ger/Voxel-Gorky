extends Node

var _dependencies: Dictionary = {}

func register(key: String, dependency) -> void:
	if _dependencies.has(key):
		Logger.warning("Dependency already registered: %s" % key, "DependencyContainer")
	_dependencies[key] = dependency
	Logger.debug("Registered dependency: %s" % key, "DependencyContainer")

func resolve(key: String):
	if not _dependencies.has(key):
		Logger.error("Dependency not found: %s" % key, "DependencyContainer")
		return null
	return _dependencies[key]

func has_dependency(key: String) -> bool:
	return _dependencies.has(key)

func clear() -> void:
	_dependencies.clear()
	Logger.debug("All dependencies cleared", "DependencyContainer")
