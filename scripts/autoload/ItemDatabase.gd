extends Node

var _projectiles: Dictionary = {}
var _vehicles: Dictionary = {}
var _blocks: Dictionary = {}

func _ready() -> void:
	_initialize_database()

func _initialize_database() -> void:
	# Register projectile types
	_register_projectile("standard_shell", {
		"damage": 20.0,
		"speed": 50.0,
		"explosive": false,
		"model_path": "res://assets/models/projectiles/standard_shell.tscn"
	})
	
	_register_projectile("explosive_shell", {
		"damage": 15.0,
		"speed": 40.0,
		"explosive": true,
		"explosion_radius": 3.0,
		"model_path": "res://assets/models/projectiles/explosive_shell.tscn"
	})
	
	# Register vehicle types
	_register_vehicle("main_tank", {
		"health": 100.0,
		"speed": 10.0,
		"turn_speed": 2.0,
		"weapon": {
			"reload_time": 1.5,
			"projectile_type": "standard_shell",
			"max_ammo": 30
		},
		"model_path": "res://assets/models/vehicles/main_tank.tscn"
	})
	
	# Register block types
	_register_block("dirt", {
		"durability": 10.0,
		"destructible": true,
		"texture_path": "res://assets/textures/blocks/dirt.png"
	})
	
	_register_block("stone", {
		"durability": 30.0,
		"destructible": true,
		"texture_path": "res://assets/textures/blocks/stone.png"
	})
	
	_register_block("metal", {
		"durability": 50.0,
		"destructible": true,
		"texture_path": "res://assets/textures/blocks/metal.png"
	})

func _register_projectile(id: String, data: Dictionary) -> void:
	_projectiles[id] = data
	Logger.debug("Registered projectile: %s" % id, "ItemDatabase")

func _register_vehicle(id: String, data: Dictionary) -> void:
	_vehicles[id] = data
	Logger.debug("Registered vehicle: %s" % id, "ItemDatabase")

func _register_block(id: String, data: Dictionary) -> void:
	_blocks[id] = data
	Logger.debug("Registered block: %s" % id, "ItemDatabase")

func get_projectile_data(id: String) -> Dictionary:
	if not _projectiles.has(id):
		Logger.error("Projectile not found: %s" % id, "ItemDatabase")
		return {}
	return _projectiles[id]

func get_vehicle_data(id: String) -> Dictionary:
	if not _vehicles.has(id):
		Logger.error("Vehicle not found: %s" % id, "ItemDatabase")
		return {}
	return _vehicles[id]

func get_block_data(id: String) -> Dictionary:
	if not _blocks.has(id):
		Logger.error("Block not found: %s" % id, "ItemDatabase")
		return {}
	return _blocks[id]
