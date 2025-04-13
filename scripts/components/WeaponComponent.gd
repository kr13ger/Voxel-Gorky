extends Component
class_name WeaponComponent

signal ammo_changed(current_ammo, max_ammo)
signal weapon_fired(projectile_data)
signal reload_started
signal reload_completed

@export var projectile_type: String = "standard_shell"
@export var max_ammo: int = 30
@export var reload_time: float = 1.5
@export var fire_point_path: NodePath

var current_ammo: int = max_ammo
var _can_fire: bool = true
var _reload_timer: float = 0.0
var _is_reloading: bool = false
var _fire_point: Node3D = null

func _on_initialize() -> void:
	current_ammo = max_ammo
	
	if not fire_point_path.is_empty():
		_fire_point = owner_entity.get_node(fire_point_path)
	
	if not _fire_point:
		Logger.error("Fire point not found", "WeaponComponent")
	
	Logger.debug("Weapon component initialized with projectile type: %s" % projectile_type, "WeaponComponent")

func _on_process(delta: float) -> void:
	if _is_reloading:
		_reload_timer -= delta
		if _reload_timer <= 0:
			_complete_reload()

func fire() -> bool:
	if not _can_fire or _is_reloading or current_ammo <= 0:
		return false
	
	current_ammo -= 1
	_can_fire = false
	
	var projectile_data = ItemDatabase.get_projectile_data(projectile_type)
	
	if projectile_data.empty():
		Logger.error("Failed to fire: Projectile type not found", "WeaponComponent")
		return false
	
	var fire_data = {
		"projectile_type": projectile_type,
		"position": _fire_point.global_position if _fire_point else owner_entity.global_position,
		"direction": _fire_point.global_transform.basis.z if _fire_point else owner_entity.global_transform.basis.z,
		"owner": owner_entity
	}
	
	Logger.debug("Weapon fired: %s" % projectile_type, "WeaponComponent")
	weapon_fired.emit(fire_data)
	SignalBus.emit_vehicle_fired(fire_data)
	
	# Use timer to control fire rate
	await owner_entity.get_tree().create_timer(0.2).timeout
	_can_fire = true
	
	ammo_changed.emit(current_ammo, max_ammo)
	
	# Auto-reload if out of ammo
	if current_ammo <= 0:
		start_reload()
	
	return true

func start_reload() -> void:
	if _is_reloading or current_ammo >= max_ammo:
		return
	
	_is_reloading = true
	_reload_timer = reload_time
	
	Logger.debug("Reload started, time: %f" % reload_time, "WeaponComponent")
	reload_started.emit()

func _complete_reload() -> void:
	_is_reloading = false
	current_ammo = max_ammo
	
	Logger.debug("Reload completed, ammo: %d" % current_ammo, "WeaponComponent")
	reload_completed.emit()
	ammo_changed.emit(current_ammo, max_ammo)

func get_ammo_percentage() -> float:
	return float(current_ammo) / float(max_ammo)
