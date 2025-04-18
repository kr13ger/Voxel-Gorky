class_name VoxelVehicle
extends CharacterBody3D

@export var voxel_model_path: String = "res://assets/models/vehicles/tank_voxel_model.tres"
@export var voxel_size: float = 0.5

var voxel_model: Node3D
var voxel_data: Dictionary = {}
var health_component: HealthComponent
var weapon_component: WeaponComponent
var physics_component: VehiclePhysicsComponent
var state_machine: StateMachine

func _ready():
	print("VoxelVehicle: Initializing...")
	
	# Create model container
	voxel_model = Node3D.new()
	voxel_model.name = "VoxelModel"
	add_child(voxel_model)
	
	# Load voxel data, or create default if not found
	if not _load_voxel_model():
		_create_default_voxel_model()
	
	# Initialize vehicle components
	_initialize_components()
	_initialize_state_machine()
	_setup_collision()
	
	# Register with GameManager if this is player vehicle
	if name == "PlayerVehicle":
		GameManager.set_player_vehicle(self)
		print("Player vehicle registered with GameManager")
	
	print("VoxelVehicle initialization complete!")

func _load_voxel_model() -> bool:
	print("Attempting to load voxel model from: ", voxel_model_path)
	
	if not ResourceLoader.exists(voxel_model_path):
		print("Voxel model resource not found!")
		return false
	
	var resource = ResourceLoader.load(voxel_model_path)
	if not resource or not resource.has_meta("voxel_data"):
		print("Invalid voxel resource - missing 'voxel_data' meta")
		return false
	
	voxel_data = resource.get_meta("voxel_data")
	
	if voxel_data.size() == 0:
		print("Voxel data is empty!")
		return false
	
	# Override voxel size if stored in resource
	if resource.has_meta("voxel_size"):
		voxel_size = resource.get_meta("voxel_size")
	
	_create_voxel_meshes()
	print("Successfully loaded voxel model with ", voxel_data.size(), " voxels")
	return true

func _create_default_voxel_model() -> void:
	print("Creating default voxel model...")
	
	# Define a simple tank shape
	var x_size = 3
	var y_size = 2
	var z_size = 4
	
	for x in range(-x_size, x_size + 1):
		for y in range(0, y_size):
			for z in range(-z_size, z_size + 1):
				var key = "%d,%d,%d" % [x, y, z]
				var type = "metal"
				
				# Define special areas
				if y == 1 and abs(x) <= 1 and abs(z) <= 1:
					type = "turret"  # Turret on top
				elif z < -2 and abs(x) < 2:
					type = "armor"   # Front armor
				elif y == 0 and abs(z) < 2 and abs(x) > 1:
					type = "engine"  # Engine on sides
				
				voxel_data[key] = {
					"type": type,
					"position": Vector3i(x, y, z),
					"health": _get_voxel_health(type),
					"instance": null
				}
	
	# Add gun barrel
	for z in range(-z_size - 2, -z_size):
		var key = "0,1,%d" % z
		voxel_data[key] = {
			"type": "metal",
			"position": Vector3i(0, 1, z),
			"health": _get_voxel_health("metal"),
			"instance": null
		}
	
	_create_voxel_meshes()
	print("Created default voxel model with ", voxel_data.size(), " voxels")

func _create_voxel_meshes() -> void:
	print("Creating voxel meshes...")
	
	# Clear any existing meshes
	for child in voxel_model.get_children():
		child.queue_free()
	
	# Create each voxel mesh
	for key in voxel_data:
		var voxel = voxel_data[key]
		var pos = voxel["position"]
		
		var mesh_instance = MeshInstance3D.new()
		var cube_mesh = BoxMesh.new()
		cube_mesh.size = Vector3.ONE * voxel_size * 0.95  # Slightly smaller to avoid z-fighting
		mesh_instance.mesh = cube_mesh
		
		# Position voxel
		mesh_instance.position = Vector3(
			pos.x * voxel_size,
			pos.y * voxel_size,
			pos.z * voxel_size
		)
		
		# Create material based on type
		var material = StandardMaterial3D.new()
		match voxel["type"]:
			"metal":
				material.albedo_color = Color(0.6, 0.6, 0.8)
			"armor":
				material.albedo_color = Color(0.3, 0.3, 0.4)
			"turret":
				material.albedo_color = Color(0.5, 0.5, 0.7)
			"glass":
				material.albedo_color = Color(0.8, 0.9, 1.0, 0.7)
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			"engine":
				material.albedo_color = Color(0.7, 0.3, 0.3)
			_:
				material.albedo_color = Color(0.7, 0.7, 0.7)
		
		mesh_instance.material_override = material
		voxel_model.add_child(mesh_instance)
		
		# Store reference in voxel data
		voxel["instance"] = mesh_instance
	
	print("Created ", voxel_model.get_child_count(), " voxel meshes")

func _initialize_components() -> void:
	print("Initializing vehicle components...")
	
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
	
	# Calculate the front of the vehicle based on voxel data
	var min_z = 0
	for key in voxel_data:
		var pos = voxel_data[key]["position"]
		min_z = min(min_z, pos.z)
	
	fire_point.position = Vector3(0, voxel_size, (min_z - 0.5) * voxel_size)
	weapon_component.add_child(fire_point)
	weapon_component.fire_point_path = weapon_component.get_path_to(fire_point)
	weapon_component.initialize(self)
	
	# Create physics component
	physics_component = VehiclePhysicsComponent.new()
	physics_component.name = "PhysicsComponent"
	physics_component.max_speed = 10.0
	physics_component.turn_speed = 2.0
	physics_component.debug_mode = false
	add_child(physics_component)
	physics_component.initialize(self)
	
	print("Components initialized")

func _initialize_state_machine() -> void:
	print("Initializing state machine...")
	
	state_machine = StateMachine.new()
	state_machine.name = "StateMachine"
	state_machine.debug_mode = false
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
	
	print("State machine initialized")

func _setup_collision() -> void:
	print("Setting up collision shape...")
	
	# Create a collision shape based on voxel model extents
	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	
	# Calculate bounds from voxel data
	var min_pos = Vector3i(1000, 1000, 1000)
	var max_pos = Vector3i(-1000, -1000, -1000)
	
	for key in voxel_data:
		var pos = voxel_data[key]["position"]
		min_pos.x = min(min_pos.x, pos.x)
		min_pos.y = min(min_pos.y, pos.y)
		min_pos.z = min(min_pos.z, pos.z)
		max_pos.x = max(max_pos.x, pos.x)
		max_pos.y = max(max_pos.y, pos.y)
		max_pos.z = max(max_pos.z, pos.z)
	
	# Calculate center point and size
	var center = Vector3(
		(min_pos.x + max_pos.x) * 0.5 * voxel_size,
		(min_pos.y + max_pos.y) * 0.5 * voxel_size,
		(min_pos.z + max_pos.z) * 0.5 * voxel_size
	)
	
	var size = Vector3(
		(max_pos.x - min_pos.x + 1) * voxel_size,
		(max_pos.y - min_pos.y + 1) * voxel_size,
		(max_pos.z - min_pos.z + 1) * voxel_size
	)
	
	box_shape.size = size
	collision_shape.shape = box_shape
	collision_shape.position = center
	add_child(collision_shape)
	
	print("Collision setup complete with size: ", size)

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
	
	if voxel_data.has(key):
		var voxel = voxel_data[key]
		voxel["health"] -= damage
		
		print("Voxel at ", key, " took damage. Health now: ", voxel["health"])
		
		# Update appearance for damage
		if voxel["instance"] and voxel["health"] > 0:
			var material = voxel["instance"].material_override.duplicate()
			var damage_ratio = 1.0 - (voxel["health"] / _get_voxel_health(voxel["type"]))
			material.albedo_color = material.albedo_color.darkened(damage_ratio * 0.5)
			voxel["instance"].material_override = material
		
		# Destroy voxel if health depleted
		if voxel["health"] <= 0:
			destroy_voxel(key)
			
			# Apply overall damage to the vehicle
			health_component.take_damage(5.0)  # Adjust as needed
	else:
		# If no direct hit on a voxel, apply general damage
		health_component.take_damage(damage * 0.5)
		print("General vehicle damage: ", damage * 0.5)

func destroy_voxel(key: String) -> void:
	if not voxel_data.has(key):
		return
	
	print("Destroying voxel at ", key)
	var voxel = voxel_data[key]
	
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
	voxel_data.erase(key)
	
	# Check critical systems
	_check_vehicle_integrity()

func _check_vehicle_integrity() -> void:
	# Check if critical systems are destroyed
	# For example, check if engine or driver voxels are gone
	var critical_voxel_types = ["engine", "turret"]
	var has_critical = false
	
	for key in voxel_data:
		var voxel = voxel_data[key]
		if voxel["type"] in critical_voxel_types:
			has_critical = true
			break
	
	if not has_critical and voxel_data.size() > 0:
		print("Critical systems destroyed! Vehicle will be destroyed.")
		# If no critical systems remain but we still have some voxels, destroy the vehicle
		health_component.take_damage(health_component.current_health)
	
	# Also destroy if too few voxels remain
	if voxel_data.size() < 5:
		print("Too few voxels remain! Vehicle structurally unsound.")
		health_component.take_damage(health_component.current_health)

func _on_destroyed() -> void:
	print("Vehicle destroyed - changing to destroyed state")
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

func _get_voxel_health(voxel_type: String) -> float:
	match voxel_type:
		"metal": return 50.0
		"armor": return 80.0
		"engine": return 40.0
		"turret": return 60.0
		"glass": return 20.0
		_: return 30.0
