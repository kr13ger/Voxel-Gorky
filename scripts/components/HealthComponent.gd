extends Component
class_name HealthComponent

signal health_changed(current_health, max_health)
signal damage_taken(amount)
signal destroyed

@export var max_health: float = 100.0
var current_health: float = max_health
var is_destroyed: bool = false

func _on_initialize() -> void:
	current_health = max_health
	Logger.debug("Health component initialized with max health: %f" % max_health, "HealthComponent")

func take_damage(amount: float) -> void:
	if is_destroyed:
		return
		
	current_health = max(0.0, current_health - amount)
	Logger.debug("Entity took %f damage, health now: %f" % [amount, current_health], "HealthComponent")
	
	damage_taken.emit(amount)
	health_changed.emit(current_health, max_health)
	
	if current_health <= 0 and not is_destroyed:
		_destroy()

func heal(amount: float) -> void:
	if is_destroyed:
		return
		
	current_health = min(max_health, current_health + amount)
	Logger.debug("Entity healed for %f, health now: %f" % [amount, current_health], "HealthComponent")
	
	health_changed.emit(current_health, max_health)

func _destroy() -> void:
	is_destroyed = true
	Logger.info("Entity destroyed", "HealthComponent")
	
	destroyed.emit()
	
	if owner_entity is Vehicle:
		var vehicle_data = {
			"vehicle": owner_entity,
			"position": owner_entity.global_position
		}
		SignalBus.emit_vehicle_destroyed(vehicle_data)
