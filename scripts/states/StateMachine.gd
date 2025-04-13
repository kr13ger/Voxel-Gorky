extends Node
class_name StateMachine

signal state_changed(previous_state, new_state)

var current_state: State = null
var states: Dictionary = {}
var _owner: Node = null
var debug_mode: bool = true

func initialize(owner_node: Node) -> void:
	_owner = owner_node
	print("StateMachine initialized with owner: ", owner_node.name)

func add_state(state_name: String, state: State) -> void:
	states[state_name] = state
	state.state_machine = self
	state.owner_node = _owner
	add_child(state)
	if debug_mode:
		print("Added state: %s" % state_name)

func change_state(new_state_name: String) -> void:
	if not states.has(new_state_name):
		Logger.error("State not found: %s" % new_state_name, "StateMachine")
		return
		
	if current_state:
		if debug_mode:
			print("Exiting state: %s" % current_state.name)
		current_state.exit()
	
	var previous_state = current_state
	current_state = states[new_state_name]
	
	if debug_mode:
		print("Entering state: %s" % new_state_name)
	current_state.enter()
	
	state_changed.emit(previous_state, current_state)

func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)
		
		var new_state_name = current_state.get_transition()
		if new_state_name and new_state_name != "":
			if debug_mode:
				print("State transition detected: " + current_state.name + " -> " + new_state_name)
			change_state(new_state_name)

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

func _input(event: InputEvent) -> void:
	if current_state:
		var result = current_state.handle_input(event)
		if result is String and result != "":
			if debug_mode:
				print("State transition from input: " + current_state.name + " -> " + result)
			change_state(result)

func get_current_state_name() -> String:
	return current_state.name if current_state else "None"
