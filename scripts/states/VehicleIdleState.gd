extends State
class_name VehicleIdleState

func enter() -> void:
	print("VehicleIdleState: Entered")
	if owner_node is Vehicle:
		var physics_component = owner_node.get_component(VehiclePhysicsComponent)
		if physics_component:
			physics_component.set_movement_input(Vector2.ZERO)
			print("VehicleIdleState: Reset movement input to zero")
		else:
			print("VehicleIdleState: Could not find physics component")
	
	Logger.debug("Vehicle entered Idle state", "VehicleIdleState")

func handle_input(event: InputEvent) -> String:
	# Check for movement inputs beginning
	if event.is_action_pressed("move_forward") or \
	   event.is_action_pressed("move_backward") or \
	   event.is_action_pressed("turn_left") or \
	   event.is_action_pressed("turn_right"):
		print("VehicleIdleState: Detected movement input, transitioning to Moving state")
		return "Moving"
	
	# Check for fire input
	if event.is_action_pressed("fire"):
		print("VehicleIdleState: Detected fire input")
		if owner_node is Vehicle:
			var weapon_component = owner_node.get_component(WeaponComponent)
			if weapon_component:
				weapon_component.fire()
	
	return ""

func update(delta: float) -> void:
	# Also check inputs continuously for transitions
	# This helps catch inputs that might be missed by the event system
	if Input.is_action_pressed("move_forward") or \
	   Input.is_action_pressed("move_backward") or \
	   Input.is_action_pressed("turn_left") or \
	   Input.is_action_pressed("turn_right"):
		print("VehicleIdleState update: Detected movement input")

func physics_update(delta: float) -> void:
	# We're idle, so no movement
	pass

func get_transition() -> String:
	# Check if we should transition to Moving state
	if Input.is_action_pressed("move_forward") or \
	   Input.is_action_pressed("move_backward") or \
	   Input.is_action_pressed("turn_left") or \
	   Input.is_action_pressed("turn_right"):
		print("VehicleIdleState transition: Detected movement input, returning Moving state")
		return "Moving"
	
	return ""

func exit() -> void:
	print("VehicleIdleState: Exited")
