extends Node3D

@export var environment_size: Vector3 = Vector3(20, 10, 20)
@export var voxel_size: float = 1.0

@onready var environment_node = $Environment
@onready var player_vehicle = $PlayerVehicle
@onready var projectile_pool_manager = $ProjectilePoolManager
@onready var ui = $UI

func _ready() -> void:
	print("MainScene _ready starting")
	
	# Check if nodes exist
	print("Environment node exists: ", environment_node != null)
	print("Player vehicle exists: ", player_vehicle != null)
	print("ProjectilePoolManager exists: ", projectile_pool_manager != null)
	
	# Initialize location manager
	if environment_node:
		print("Initializing location manager...")
		LocationManager.initialize_location(environment_node, environment_size, voxel_size)
		print("Location manager initialized")
		
		# Generate environment
		print("Starting environment generation...")
		_generate_environment()
		print("Environment generation completed")
	else:
		print("ERROR: Environment node not found!")
		
		# Create a temporary environment node
		print("Creating temporary environment node")
		environment_node = Node3D.new()
		environment_node.name = "Environment"
		add_child(environment_node)
		
		# Try again
		print("Retrying location initialization...")
		LocationManager.initialize_location(environment_node, environment_size, voxel_size)
		_generate_environment()
	
	# Setup camera if needed
	if player_vehicle:
		print("Setting up camera...")
		_setup_follow_camera()
		print("Camera setup completed")
	
	# Initialize projectile pools
	if projectile_pool_manager:
		print("Initializing projectile pools...")
		projectile_pool_manager.initialize_pool("standard_shell", 20)
		projectile_pool_manager.initialize_pool("explosive_shell", 10)
		print("Projectile pools initialized")
	else:
		print("ERROR: ProjectilePoolManager not found!")
	
	Logger.info("Main scene initialized", "MainScene")

func _process(delta: float) -> void:
	_update_ui()

func _generate_environment() -> void:
	print("Generating environment...")
	
	# Create a flat ground
	_create_ground()

	
	# Create some obstacles
	_create_obstacles()
	
	Logger.info("Environment generated", "MainScene")

func _create_ground() -> void:
	print("Creating ground...")
	# Create a flat ground plane
	var ground_mesh = PlaneMesh.new()
	ground_mesh.size = Vector2(environment_size.x, environment_size.z) * voxel_size
	
	var ground = MeshInstance3D.new()
	ground.mesh = ground_mesh
	
	# Create a grid material to better visualize movement
	var ground_material = StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.2, 0.5, 0.2)
	
	# Create a texture with proper size first
	var img = Image.create(64, 64, false, Image.FORMAT_RGB8)
	img.fill(Color(0.2, 0.5, 0.2))
	
	# Draw grid lines
	for i in range(64):
		if i % 8 == 0:
			for j in range(64):
				img.set_pixel(i, j, Color(0.1, 0.3, 0.1))
				img.set_pixel(j, i, Color(0.1, 0.3, 0.1))
	
	var checker = ImageTexture.create_from_image(img)
	ground_material.albedo_texture = checker
	ground_material.uv1_scale = Vector3(environment_size.x, environment_size.z, 1)
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
	print("Ground created")

func _create_obstacles() -> void:
	print("Creating obstacles...")
	
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
	
	# Create some pillars for reference
	for i in range(4):
		var x = 10 * cos(i * PI/2)
		var z = 10 * sin(i * PI/2)
		
		# Create a tall pillar
		for y in range(0, 6):
			var position = Vector3(x, y, z) * voxel_size
			var voxel_data = {
				"type": "metal",
				"instance": null,
				"durability": 50.0
			}
			LocationManager.set_voxel(position, voxel_data)
	
	# Create a ramp to test vertical movement
	for x in range(0, 10):
		var y = floor(x / 3) # Creates a stepped ramp
		var position = Vector3(x - 5, y, 10) * voxel_size
		var voxel_data = {
			"type": "dirt",
			"instance": null,
			"durability": 10.0
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
	
	print("Obstacles created")

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
		var weapon_component_script = load("res://scripts/components/WeaponComponent.gd")
		var health_component_script = load("res://scripts/components/HealthComponent.gd")
		var weapon_component = player_vehicle.get_component(weapon_component_script)
		var health_component = player_vehicle.get_component(health_component_script)
		
		if weapon_component and ui.has_node("AmmoCounter"):
			ui.get_node("AmmoCounter").text = "Ammo: %d / %d" % [
				weapon_component.current_ammo,
				weapon_component.max_ammo
			]
		
		if health_component and ui.has_node("HealthBar"):
			ui.get_node("HealthBar").value = (health_component.current_health / health_component.max_health) * 100
