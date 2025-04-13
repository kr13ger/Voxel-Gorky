extends Node

# This script should be run once to create placeholder assets
# Attach this to a node in a temporary scene and run it

func _ready():
	create_placeholder_assets()
	print("Placeholder assets created successfully!")
	get_tree().quit()

func create_placeholder_assets():
	# Create directories
	create_directories()
	
	# Create placeholder textures
	create_texture("res://assets/textures/blocks/dirt.png", Color(0.5, 0.35, 0.05))
	create_texture("res://assets/textures/blocks/stone.png", Color(0.7, 0.7, 0.7))
	create_texture("res://assets/textures/blocks/metal.png", Color(0.6, 0.6, 0.8))
	
	# Create projectile scenes
	create_projectile_scene("res://assets/models/projectiles/standard_shell.tscn", "standard_shell")
	create_projectile_scene("res://assets/models/projectiles/explosive_shell.tscn", "explosive_shell")

func create_directories():
	var dir = DirAccess.open("res://")
	if not dir:
		print("Failed to open root directory")
		return
		
	# Create asset directory structure
	create_directory("res://assets")
	create_directory("res://assets/textures")
	create_directory("res://assets/textures/blocks")
	create_directory("res://assets/models")
	create_directory("res://assets/models/projectiles")
	create_directory("res://assets/models/vehicles")

func create_directory(path):
	if not DirAccess.dir_exists_absolute(path):
		var err = DirAccess.make_dir_recursive_absolute(path)
		if err != OK:
			print("Failed to create directory: %s (Error: %d)" % [path, err])
		else:
			print("Created directory: %s" % path)

func create_texture(path, color):
	# Create a simple 64x64 texture with the given color
	var image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(color)
	
	# Add some texture details
	for i in range(64):
		for j in range(64):
			if (i + j) % 8 == 0 or i % 16 == 0 or j % 16 == 0:
				var new_color = color.darkened(0.2)
				image.set_pixel(i, j, new_color)
	
	# Save the image
	var err = image.save_png(path)
	if err != OK:
		print("Failed to save texture: %s (Error: %d)" % [path, err])
	else:
		print("Created texture: %s" % path)

func create_projectile_scene(path, type):
	var scene = PackedScene.new()
	var projectile = Area3D.new()
	
	# Add projectile script
	var script = load("res://scripts/Projectile.gd")
	projectile.set_script(script)
	projectile.name = "Projectile"
	
	# Create collision shape
	var collision_shape = CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = 0.2
	collision_shape.shape = sphere_shape
	projectile.add_child(collision_shape)
	
	# Add a simple mesh
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.2
	sphere_mesh.height = 0.4
	mesh_instance.mesh = sphere_mesh
	
	# Apply material to identify projectile type
	var material = StandardMaterial3D.new()
	if type == "explosive_shell":
		material.albedo_color = Color(1.0, 0.2, 0.2) # Red for explosive
	else:
		material.albedo_color = Color(0.7, 0.7, 0.9) # Blue-ish for standard
	
	mesh_instance.material_override = material
	projectile.add_child(mesh_instance)
	
	# Pack the scene
	var result = scene.pack(projectile)
	if result == OK:
		# Save the scene
		var err = ResourceSaver.save(scene, path)
		if err != OK:
			print("Failed to save scene: %s (Error: %d)" % [path, err])
		else:
			print("Created projectile scene: %s" % path)
	else:
		print("Failed to pack scene for %s" % path)
