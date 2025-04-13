extends Component
class_name VehiclePhysicsComponent

@export var max_speed: float = 10.0
@export var acceleration: float = 5.0
@export var deceleration: float = 8.0
@export var turn_speed: float = 2.0
@export var gravity: float = 20.0

var velocity: Vector3 = Vector3.ZERO
var _movement_input: Vector2 = Vector2.ZERO
var _ground_check_ray_length: float = 0.6

func _on_physics_process(delta: float) -> void:
	# Apply movement based on input
	_apply_movement(delta)
	
	# Apply gravity
	if not _is_on_ground():
		velocity.y -= gravity * delta
	elif velocity.y < 0:
		velocity.y = -0.1  # Small negative value to keep it grounded
	
	# Apply velocity to the character
	if owner_entity is CharacterBody3D:
		owner_entity.velocity = velocity
		owner_entity.move_and_slide()
		velocity = owner_entity.velocity
	else:
		Logger.error("VehiclePhysicsComponent requires a CharacterBody3D parent", "VehiclePhysicsComponent")

func set_movement_input(input: Vector2) -> void:
	_movement_input = input

func _apply_movement(delta: float) -> void:
	var direction = Vector3.ZERO
	
	# Forward/backward movement
	direction.z = _movement_input.y
	
	# Rotation (left/right)
	if _movement_input.x != 0:
		owner_entity.rotate_y(-_movement_input.x * turn_speed * delta)
	
	# Convert direction to global space
	direction = owner_entity.global_transform.basis * direction
	direction.y = 0  # Keep movement on the horizontal plane
	direction = direction.normalized()
	
	# Apply acceleration/deceleration
	var target_velocity = direction * max_speed
	var horizontal_velocity = Vector3(velocity.x, 0, velocity.z)
	
	if direction.length() > 0:
		horizontal_velocity = horizontal_velocity.move_toward(target_velocity, acceleration * delta)
	else:
		horizontal_velocity = horizontal_velocity.move_toward(Vector3.ZERO, deceleration * delta)
	
	# Update velocity
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

func _is_on_ground() -> bool:
	if not owner_entity:
		return false
	
	var space_state = owner_entity.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.new()
	query.from = owner_entity.global_position
	query.to = owner_entity.global_position - Vector3(0, _ground_check_ray_length, 0)
	query.collision_mask = 1  # Adjust based on your collision layers
	
	var result = space_state.intersect_ray(query)
	
	return not result.is_empty()
