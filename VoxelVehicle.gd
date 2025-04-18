class_name VoxelVehicle
extends CharacterBody3D

@export var mesh_path: String = "res://assets/models/vehicles/tank_model.obj"
@export var voxel_size: float = 0.5

var voxel_model: VoxelModel
var health_component: HealthComponent
var weapon_component: WeaponComponent
var physics_component: VehiclePhysicsComponent
var state_machine: StateMachine

func _ready():
	# Create voxel model from mesh
	voxel_model = VoxelModel.new()
	voxel_model.voxel_size = voxel_size
	add_child(voxel_model)
	
	if not voxel_model.load_from_mesh(mesh_path):
		Logger.error("Failed to load vehicle mesh", "VoxelVehicle")
	
	# Initialize vehicle components
	_initialize_components()
	_initialize_state_machine()
	_setup_collision()
	
	# Register with GameManager if this is player vehicle
	if name == "PlayerVehicle":
		GameManager.set_player_vehicle(self)

func _initialize_components():
	# Create health component
	health_component = HealthComponent.new()
	health_component.name = "HealthComponent"
	health_component.max_health = 100.0
	add_child(health_component)
	health_component.initialize(self)
	health_component.destroyed.connect(_on_destroyed)
	
	# Create weapon component
	weapon_component = WeaponComponent.new()
	weapon_component.name = "WeaponComponent"
	weapon_component.projectile_type = "standard_shell"
	weapon_component.max_ammo = 30
	add_child(weapon_component)
	
	# Create fire point
	var fire_point = Node3D.new()
	fire_point.name = "FirePoint"
	fire_point.position = Vector3(0, 0, -2)  # Adjust based on model
	weapon_component.add_child(fire_point)
	weapon_component.fire_point_path = weapon_component.get_path_to(fire_point)
	weapon_component.initialize(self)
	
	# Create physics component
	physics_component = VehiclePhysicsComponent.new()
	physics_component.name = "PhysicsComponent"
	physics_component.max_speed = 10.0
	physics_component.turn_speed = 2.0
	add_child(physics_component)
	physics_component.initialize(self)

func _initialize_state_machine():
	state_machine = StateMachine.new()
	state_machine.name = "StateMachine"
	add_child(state_machine)
	state_machine.initialize(self)
	
	# Add states
	var idle_state = VehicleIdleState.new()
	idle_state.name = "Idle"
	state_machine.add_state("Idle", idle_state)
	
	var moving_state = VehicleMovingState.new()
	moving_state.name = "Moving"
	state_machine.add_state("Moving", moving_state)
	
	var destroyed_state = VehicleDestroyedState.new()
	destroyed_state.name = "Destroyed"
	state_machine.add_state("Destroyed", destroyed_state)
	
	# Set initial state
	state_machine.change_state("Idle")

func _setup_collision():
	# Create a collision shape based on voxel model dimensions
	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	
	# Calculate bounds from voxel data
	var min_pos = Vector3(INF, INF, INF)
	var max_pos = Vector3(-INF, -INF, -INF)
	
	for key in voxel_model.voxel_data:
		var pos = voxel_model.voxel_data[key]["position"]
		min_pos.x = min(min_pos.x, pos.x)
		min_pos.y = min(min_pos.y, pos.y)
		min_pos.z = min(min_pos.z, pos.z)
		max_pos.x = max(max_pos.x, pos.x)
		max_pos.y = max(max_pos.y, pos.y)
		max_pos.z = max(max_pos.z, pos.z)
	
	# Set collision shape size
	box_shape.size = Vector3(
		(max_pos.x - min_pos.x + 1) * voxel_size,
		(max_pos.y - min_pos.y + 1) * voxel_size,
		(max_pos.z - min_pos.z + 1) * voxel_size
	)
	
	collision_shape.shape = box_shape
	add_child(collision_shape)

func damage_voxel(global_position: Vector3, damage: float) -> void:
	# Convert global position to local model space
	var local_pos = voxel_model.global_transform.affine_inverse() * global_position
	
	# Convert to grid position
	var grid_pos = Vector3i(
		floor(local_pos.x / voxel_size),
		floor(local_pos.y / voxel_size),
		floor(local_pos.z / voxel_size)
	)
	
	var key = "%d,%d,%d" % [grid_pos.x, grid_pos.y, grid_pos.z]
	
	if voxel_model.voxel_data.has(key):
		var voxel = voxel_model.voxel_data[key]
		voxel["health"] -= damage
		
		# Update appearance
		if voxel["instance"] and voxel["health"] > 0:
			var material = voxel["instance"].material_override.duplicate()
			var damage_ratio = 1.0 - (voxel["health"] / get_initial_health(voxel["type"]))
			material.albedo_color = material.albedo_color.darkened(damage_ratio * 0.5)
			voxel["instance"].material_override = material
		
		# Destroy voxel if health depleted
		if voxel["health"] <= 0:
			destroy_voxel(key)
			
			# Apply overall damage to the vehicle
			health_component.take_damage(5.0)  # Adjust damage value as needed
	else:
		# If no direct hit on a voxel, apply general damage
		health_component.take_damage(damage * 0.5)

func destroy_voxel(key: String) -> void:
	if not voxel_model.voxel_data.has(key):
		return
	
	var voxel = voxel_model.voxel_data[key]
	
	# Handle visual destruction
	if voxel["instance"]:
		# Create destruction particle effect
		var particles = GPUParticles3D.new()
		var particle_material = ParticleProcessMaterial.new()
		particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		particle_material.emission_box_extents = Vector3(0.3, 0.3, 0.3)
		particle_material.direction = Vector3(0, 1, 0)
		particle_material.spread = 180.0
		particle_material.gravity = Vector3(0, -10, 0)
		particle_material.initial_velocity_min = 2.0
		particle_material.initial_velocity_max = 5.0
		particles.process_material = particle_material
		particles.amount = 15
		particles.one_shot = true
		particles.explosiveness = 0.9
		get_parent().add_child(particles)
		particles.global_position = voxel["instance"].global_position
		particles.emitting = true
		
		# Auto-remove particles after effect
		var timer = Timer.new()
		timer.one_shot = true
		timer.wait_time = 2.0
		particles.add_child(timer)
		timer.timeout.connect(func(): particles.queue_free())
		timer.start()
		
		# Remove voxel mesh
		voxel["instance"].queue_free()
		voxel["instance"] = null
	
	# Remove voxel data
	voxel_model.voxel_data.erase(key)
	
	# Check critical systems
	_check_vehicle_integrity()

func _check_vehicle_integrity() -> void:
	# Check if critical systems are destroyed
	# For example, we could check if engine or driver voxels are gone
	var critical_voxel_types = ["engine", "driver"]
	var has_critical = false
	
	for key in voxel_model.voxel_data:
		var voxel = voxel_model.voxel_data[key]
		if voxel["type"] in critical_voxel_types:
			has_critical = true
			break
	
	if not has_critical:
		# If no critical systems remain, destroy the vehicle
		health_component.take_damage(health_component.current_health)

func _on_destroyed() -> void:
	if state_machine:
		state_machine.change_state("Destroyed")

func get_component(component_type: GDScript) -> Node:
	if component_type == HealthComponent:
		return health_component
	elif component_type == WeaponComponent:
		return weapon_component
	elif component_type == VehiclePhysicsComponent:
		return physics_component
	return null

func get_initial_health(voxel_type: String) -> float:
	match voxel_type:
		"metal": return 50.0
		"armor": return 80.0
		"engine": return 40.0
		"turret": return 60.0
		"glass": return 20.0
		_: return 30.0
