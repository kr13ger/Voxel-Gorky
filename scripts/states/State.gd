extends Node
class_name State

var state_machine: StateMachine = null
var owner_node: Node = null

func enter() -> void:
	pass

func exit() -> void:
	pass

func update(delta: float) -> void:
	pass

func physics_update(delta: float) -> void:
	pass

func handle_input(event: InputEvent) -> String:
	# Return an empty string to indicate no state change,
	# or the name of the state to transition to
	return ""

func get_transition() -> String:
	# Return an empty string to indicate no state change,
	# or the name of the state to transition to
	return ""
