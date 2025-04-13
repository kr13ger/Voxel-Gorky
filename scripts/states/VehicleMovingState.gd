extends State
class_name VehicleMovingState

var _physics_component: VehiclePhysicsComponent = null

func enter() -> void:
	print("VehicleMovingState: Entered")
	if owner_node is Vehicle:
		# Get physics component directly instead of loading script
		_physics_component = owner_node.get_component(VehiclePhysicsComponent)
		if _physics_component:
			print("VehicleMovingState: Got physics component successfully")
			# Immediately apply initial input to start moving
			_handle_movement_input() 
		else:
			print("VehicleMovingState: FAILED to get physics component")
			# Try alternative method by direct node reference
			if owner_node.has_node("PhysicsComponent"):
				var phys = owner_node.get_node("PhysicsComponent")
				if phys is VehiclePhysicsComponent:
					_physics_component = phys
					print("VehicleMovingState: Retrieved physics component via direct node reference")
					_handle_movement_input()
	
	Logger.debug("Vehicle entered Moving state", "VehicleMovingState")

func handle_input(event: InputEvent) -> String:
	# Handle firing while moving
	if event.is_action_pressed("fire") and owner_node is Vehicle:
		var weapon_component = owner_node.get_component(WeaponComponent)
		if weapon_component:
			weapon_component.fire()
	
	# Check for movement input release to transition to idle
	if event.is_action_released("move_forward") or event.is_action_released("move_backward") or \
	   event.is_action_released("turn_left") or event.is_action_released("turn_right"):
		# Only return to idle if no movement keys are pressed
		if not Input.is_action_pressed("move_forward") and \
		   not Input.is_action_pressed("move_backward") and \
		   not Input.is_action_pressed("turn_left") and \
		   not Input.is_action_pressed("turn_right"):
			print("VehicleMovingState: No movement detected, returning to Idle")
			return "Idle"
	
	return ""

func update(delta: float) -> void:
	# Check for input constantly to handle physics movement
	_handle_movement_input()

func physics_update(delta: float) -> void:
	_handle_movement_input()

func _handle_movement_input() -> void:
	if not _physics_component:
		print("VehicleMovingState: No physics component available")
		return
	
	var input_vector = Vector2.ZERO
	
	# Get movement input
	if Input.is_action_pressed("move_forward"):
		input_vector.y -= 1
		print("Moving forward")
	if Input.is_action_pressed("move_backward"):
		input_vector.y += 1
		print("Moving backward")
	if Input.is_action_pressed("turn_left"):
		input_vector.x -= 1
		print("Turning left")
	if Input.is_action_pressed("turn_right"):
		input_vector.x += 1
		print("Turning right")
	
	# Normalize input
	if input_vector.length() > 1:
		input_vector = input_vector.normalized()
	
	# Apply to physics component
	_physics_component.set_movement_input(input_vector)
	print("Applied input vector: ", input_vector)

func get_transition() -> String:
	# Check if we should transition to Idle state
	if not Input.is_action_pressed("move_forward") and \
	   not Input.is_action_pressed("move_backward") and \
	   not Input.is_action_pressed("turn_left") and \
	   not Input.is_action_pressed("turn_right"):
		print("VehicleMovingState transition: No movement detected, returning to Idle")
		return "Idle"
	
	return ""

func exit() -> void:
	print("VehicleMovingState: Exited")
	if _physics_component:
		_physics_component.set_movement_input(Vector2.ZERO)
