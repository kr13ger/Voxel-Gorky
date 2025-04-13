extends State
class_name VehicleMovingState

var _physics_component: VehiclePhysicsComponent = null

func enter() -> void:
	if owner_node is Vehicle:
		var physics_component_script = load("res://scripts/components/VehiclePhysicsComponent.gd")
		_physics_component = owner_node.get_component(physics_component_script)
	
	Logger.debug("Vehicle entered Moving state", "VehicleMovingState")

func handle_input(event: InputEvent) -> void:
	# Still handle firing while moving
	if Input.is_action_just_pressed("fire") and owner_node is Vehicle:
		var weapon_component_script = load("res://scripts/components/WeaponComponent.gd")
		var weapon_component = owner_node.get_component(weapon_component_script)
		if weapon_component:
			weapon_component.fire()

func physics_update(delta: float) -> void:
	if not _physics_component:
		return
	
	var input_vector = Vector2.ZERO
	
	# Get movement input
	if Input.is_action_pressed("move_forward"):
		input_vector.y -= 1
	if Input.is_action_pressed("move_backward"):
		input_vector.y += 1
	if Input.is_action_pressed("turn_left"):
		input_vector.x -= 1
	if Input.is_action_pressed("turn_right"):
		input_vector.x += 1
	
	# Normalize input
	if input_vector.length() > 1:
		input_vector = input_vector.normalized()
	
	# Apply to physics component
	_physics_component.set_movement_input(input_vector)

func get_transition() -> String:
	# Check if we should transition to Idle state
	if not Input.is_action_pressed("move_forward") and \
	   not Input.is_action_pressed("move_backward") and \
	   not Input.is_action_pressed("turn_left") and \
	   not Input.is_action_pressed("turn_right"):
		return "Idle"
	
	return ""
