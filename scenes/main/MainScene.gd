extends Node3D

@export var environment_size: Vector3 = Vector3(20, 10, 20)
@export var voxel_size: float = 1.0

@onready var environment_node = $Environment
@onready var player_vehicle = $PlayerVehicle
@onready var projectile_pool_manager = $ProjectilePoolManager
@onready var ui = $UI

func _ready() -> void:
	# Initialize location manager
	LocationManager.initialize_location(environment_node, environment_size, voxel_size)
	
	# Generate environment
	_generate_environment()
	
	# Setup camera
	_setup_follow_camera()
	
	# Initialize projectile pools
	projectile_pool_manager.initialize_pool("standard_shell", 20)
	projectile_pool_manager.initialize_pool("explosive_shell", 10)
	
	Logger.info("Main scene initialized", "MainScene")

func _process(delta: float) -> void:
	_update_ui()

func _generate_environment() -> void:
	# Create a flat ground
	_create_ground()
	
	# Create some obstacles
	_create_obstacles()
	
	Logger.info("Environment generated", "MainScene")

func _create_ground() -> void:
	# Create a flat ground plane
	var ground_mesh = PlaneMesh.new()
	ground_mesh.size = Vector2(environment_size.x, environment_size.z) * voxel_size
	
	var ground = MeshInstance3D.new()
	ground.mesh = ground_mesh
	
	var ground_material = StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.3, 0.5, 0.2)
	ground.material_override = ground_material
	
	# Add collision
	var static_body = StaticBody3D.new()
	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(ground_mesh.size.x, 0.1, ground_mesh.size.y)
	collision_shape.shape = box_shape
	static_body.add_child(collision_shape)
	ground.add_child(static_body)
	
	environment_node.add_child(ground)
	ground.position.y = -0.05  # Slightly below origin to avoid z-fighting

func _create_obstacles() -> void:
	# Create some walls and structures using voxels
	
	# Create a small fort structure
	for x in range(-5, 6):
		for z in range(-5, 6):
			# Create walls around the perimeter
			if x == -5 or x == 5 or z == -5 or z == 5:
				for y in range(0, 3):
					var position = Vector3(x, y, z) * voxel_size
					var voxel_data = {
						"type": "stone",
						"instance": null,
						"durability": 30.0
					}
					LocationManager.set_voxel(position, voxel_data)
	
	# Create some scattered blocks
	for i in range(30):
		var x = randi_range(-int(environment_size.x/2) + 2, int(environment_size.x/2) - 2)
		var z = randi_range(-int(environment_size.z/2) + 2, int(environment_size.z/2) - 2)
		
		# Skip if too close to the player start position
		if abs(x) < 3 and abs(z) < 3:
			continue
		
		var height = randi_range(1, 3)
		for y in range(0, height):
			var position = Vector3(x, y, z) * voxel_size
			var block_type = ["dirt", "stone", "metal"][randi() % 3]
			var voxel_data = {
				"type": block_type,
				"instance": null,
				"durability": ItemDatabase.get_block_data(block_type).durability
			}
			LocationManager.set_voxel(position, voxel_data)

func _setup_follow_camera() -> void:
	var camera = Camera3D.new()
	var spring_arm = SpringArm3D.new()
	
	spring_arm.spring_length = 8.0
	spring_arm.margin = 0.5
	spring_arm.position = Vector3(0, 2, 0)
	spring_arm.rotation_degrees = Vector3(-20, 0, 0)
	
	camera.far = 300.0
	camera.current = true
	
	spring_arm.add_child(camera)
	player_vehicle.add_child(spring_arm)

func _update_ui() -> void:
	# Update UI elements like ammo counter
	if player_vehicle and ui:
		var weapon_component = player_vehicle.get_component(WeaponComponent)
		var health_component = player_vehicle.get_component(HealthComponent)
		
		if weapon_component and ui.has_node("AmmoCounter"):
			ui.get_node("AmmoCounter").text = "Ammo: %d / %d" % [
				weapon_component.current_ammo,
				weapon_component.max_ammo
			]
		
		if health_component and ui.has_node("HealthBar"):
			ui.get_node("HealthBar").value = (health_component.current_health / health_component.max_health) * 100
