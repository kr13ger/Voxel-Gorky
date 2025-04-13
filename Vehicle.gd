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
	_initialize_components()
	_initialize_state_machine()
	
	# Setup input actions if they don't exist
	_setup_input_actions()
	
	# Register with GameManager if this is the player vehicle
	if name == "PlayerVehicle":
		GameManager.set_player_vehicle(self)

func _initialize_components() -> void:
	# Get components from paths
	if not health_component_path.is_empty():
		_health_component = get_node(health_component_path)
		_components.append(_health_component)
	
	if not weapon_component_path.is_empty():
		_weapon_component = get_node(weapon_component_path)
		_components.append(_weapon_component)
	
	if not physics_component_path.is_empty():
		_physics_component = get_node(physics_component_path)
		_components.append(_physics_component)
	
	# Initialize all components
	for component in _components:
		component.initialize(self)
	
	# Setup destroyed signal
	if _health_component:
		_health_component.destroyed.connect(_on_destroyed)
	
	Logger.info("Vehicle initialized with components", "Vehicle")

func _initialize_state_machine() -> void:
	if not state_machine_path.is_empty():
		_state_machine = get_node(state_machine_path)
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

func get_component(component_type) -> Component:
	for component in _components:
		if component is component_type:
			return component
	return null

func _on_destroyed() -> void:
	if _state_machine:
		_state_machine.change_state("Destroyed")

func _setup_input_actions() -> void:
	if not InputMap.has_action("move_forward"):
		InputMap.add_action("move_forward")
		var event = InputEventKey.new()
		event.keycode = KEY_W
		InputMap.action_add_event("move_forward", event)
	
	if not InputMap.has_action("move_backward"):
		InputMap.add_action("move_backward")
		var event = InputEventKey.new()
		event.keycode = KEY_S
		InputMap.action_add_event("move_backward", event)
	
	if not InputMap.has_action("turn_left"):
		InputMap.add_action("turn_left")
		var event = InputEventKey.new()
		event.keycode = KEY_A
		InputMap.action_add_event("turn_left", event)
	
	if not InputMap.has_action("turn_right"):
		InputMap.add_action("turn_right")
		var event = InputEventKey.new()
		event.keycode = KEY_D
		InputMap.action_add_event("turn_right", event)
	
	if not InputMap.has_action("fire"):
		InputMap.add_action("fire")
		var event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("fire", event)
