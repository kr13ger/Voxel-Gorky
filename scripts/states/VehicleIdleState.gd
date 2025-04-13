extends State
class_name VehicleIdleState

func enter() -> void:
	if owner_node is Vehicle:
		var physics_component_script = load("res://scripts/components/VehiclePhysicsComponent.gd")
		var physics_component = owner_node.get_component(physics_component_script)
		if physics_component:
			physics_component.set_movement_input(Vector2.ZERO)
	
	Logger.debug("Vehicle entered Idle state", "VehicleIdleState")

func handle_input(event: InputEvent):
	# Check for movement inputs
	if Input.is_action_pressed("move_forward") or \
	   Input.is_action_pressed("move_backward") or \
	   Input.is_action_pressed("turn_left") or \
	   Input.is_action_pressed("turn_right"):
		return "Moving"
	
	# Check for fire input
	if Input.is_action_just_pressed("fire"):
		if owner_node is Vehicle:
			var weapon_component_script = load("res://scripts/components/WeaponComponent.gd")
			var weapon_component = owner_node.get_component(weapon_component_script)
			if weapon_component:
				weapon_component.fire()

func physics_update(delta: float) -> void:
	# We're idle, so no movement
	pass

func get_transition() -> String:
	# Check if we should transition to Moving state
	if Input.is_action_pressed("move_forward") or \
	   Input.is_action_pressed("move_backward") or \
	   Input.is_action_pressed("turn_left") or \
	   Input.is_action_pressed("turn_right"):
		return "Moving"
	
	return ""
