extends CharacterBody3D
class_name Vehicle

@export var vehicle_type: String = "main_tank"
@export_group("Components")
@export var health_component_path: NodePath
@export var weapon_component_path: NodePath
@export var physics_component_path: NodePath
@export_group("State Machine")
@export var state_machine_path: NodePath

var _health_component: HealthComponent
var _weapon_component: WeaponComponent
var _physics_component: VehiclePhysicsComponent
var _state_machine: StateMachine

var _components: Array[Component] = []

func _ready() -> void:
	print("Vehicle _ready called")
	_initialize_components()
	_initialize_state_machine()
	
	# Setup input actions if they don't exist
	_setup_input_actions()
	
	# Register with GameManager if this is the player vehicle
	if name == "PlayerVehicle":
		print("Registering player vehicle with GameManager")
		GameManager.set_player_vehicle(self)

func _initialize_components() -> void:
	print("Initializing components...")
	# Get components from paths
	if not health_component_path.is_empty():
		_health_component = get_node(health_component_path)
		_components.append(_health_component)
		print("Health component found at path: ", health_component_path)
	else:
		print("Health component path is empty")
	
	if not weapon_component_path.is_empty():
		_weapon_component = get_node(weapon_component_path)
		_components.append(_weapon_component)
		print("Weapon component found at path: ", weapon_component_path)
	else:
		print("Weapon component path is empty")
	
	if not physics_component_path.is_empty():
		_physics_component = get_node(physics_component_path)
		_components.append(_physics_component)
		print("Physics component found at path: ", physics_component_path)
	else:
		print("Physics component path is empty")
	
	# Initialize all components
	for component in _components:
		component.initialize(self)
	
	# Setup destroyed signal
	if _health_component:
		_health_component.destroyed.connect(_on_destroyed)
	
	Logger.info("Vehicle initialized with components", "Vehicle")

func _initialize_state_machine() -> void:
	print("Initializing state machine...")
	if not state_machine_path.is_empty():
		_state_machine = get_node(state_machine_path)
		if _state_machine:
			_state_machine.initialize(self)
			
			# Add states
			var idle_state = VehicleIdleState.new()
			idle_state.name = "Idle"
			_state_machine.add_state("Idle", idle_state)
			
			var moving_state = VehicleMovingState.new()
			moving_state.name = "Moving"
			_state_machine.add_state("Moving", moving_state)
			
			var destroyed_state = VehicleDestroyedState.new()
			destroyed_state.name = "Destroyed"
			_state_machine.add_state("Destroyed", destroyed_state)
			
			# Set initial state
			_state_machine.change_state("Idle")
			
			Logger.info("Vehicle state machine initialized", "Vehicle")
			print("State machine initialized successfully")
		else:
			print("ERROR: State machine node not found at path: ", state_machine_path)
	else:
		print("ERROR: State machine path is empty")

func get_component(component_type: GDScript) -> Component:
	for component in _components:
		if component.get_script() == component_type:
			return component
	return null

func _on_destroyed() -> void:
	if _state_machine:
		_state_machine.change_state("Destroyed")

func _process(delta: float) -> void:
	# Manual state transition checks for debugging purposes
	if _state_machine and Input.is_action_pressed("move_forward") and _state_machine.current_state.name == "Idle":
		print("Manual state change check: Should change to Moving")

func _setup_input_actions() -> void:
	print("Setting up input actions...")
	
	if not InputMap.has_action("move_forward"):
		print("Adding move_forward action")
		InputMap.add_action("move_forward")
		var event = InputEventKey.new()
		event.keycode = KEY_W
		InputMap.action_add_event("move_forward", event)
	
	if not InputMap.has_action("move_backward"):
		print("Adding move_backward action")
		InputMap.add_action("move_backward")
		var event = InputEventKey.new()
		event.keycode = KEY_S
		InputMap.action_add_event("move_backward", event)
	
	if not InputMap.has_action("turn_left"):
		print("Adding turn_left action")
		InputMap.add_action("turn_left")
		var event = InputEventKey.new()
		event.keycode = KEY_A
		InputMap.action_add_event("turn_left", event)
	
	if not InputMap.has_action("turn_right"):
		print("Adding turn_right action")
		InputMap.add_action("turn_right")
		var event = InputEventKey.new()
		event.keycode = KEY_D
		InputMap.action_add_event("turn_right", event)
	
	if not InputMap.has_action("fire"):
		print("Adding fire action")
		InputMap.add_action("fire")
		var event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("fire", event)
		
	print("Input actions setup completed")

func _input(event: InputEvent) -> void:
	# Debug input events
	if event is InputEventKey:
		if event.pressed:
			print("Key pressed: ", event.keycode)
			if event.keycode == KEY_W:
				print("W key pressed")
			elif event.keycode == KEY_S: 
				print("S key pressed")
			elif event.keycode == KEY_A:
				print("A key pressed")
			elif event.keycode == KEY_D:
				print("D key pressed")
