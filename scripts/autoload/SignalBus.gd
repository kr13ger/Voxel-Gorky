extends Node

# Vehicle signals
signal vehicle_fired(projectile_data)
signal vehicle_hit(hit_data)
signal vehicle_destroyed(vehicle_data)

# Environment signals
signal block_destroyed(block_data)
signal explosion_occurred(explosion_data)

# Game state signals
signal game_paused
signal game_resumed
signal game_reset

func emit_vehicle_fired(projectile_data: Dictionary) -> void:
	Logger.debug("Vehicle fired projectile", "SignalBus")
	vehicle_fired.emit(projectile_data)

func emit_vehicle_hit(hit_data: Dictionary) -> void:
	Logger.debug("Vehicle hit", "SignalBus")
	vehicle_hit.emit(hit_data)

func emit_block_destroyed(block_data: Dictionary) -> void:
	Logger.debug("Block destroyed", "SignalBus")
	block_destroyed.emit(block_data)

func emit_explosion_occurred(explosion_data: Dictionary) -> void:
	Logger.debug("Explosion occurred", "SignalBus")
	explosion_occurred.emit(explosion_data)
