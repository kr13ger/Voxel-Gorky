extends Area3D
class_name Projectile

var projectile_type: String = ""
var speed: float = 50.0
var damage: float = 20.0
var explosive: bool = false
var explosion_radius: float = 3.0
var owner_node: Node = null

var _direction: Vector3 = Vector3.ZERO
var _lifetime: float = 5.0  # Seconds before auto-destruction
var _time_alive: float = 0.0
var _initialized: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	# Create simple collision shape if none exists
	if get_child_count() == 0:
		var collision_shape = CollisionShape3D.new()
		var sphere_shape = SphereShape3D.new()
		sphere_shape.radius = 0.2
		collision_shape.shape = sphere_shape
		add_child(collision_shape)
		
		# Add a simple mesh
		var mesh_instance = MeshInstance3D.new()
		var sphere_mesh = SphereMesh.new()
		sphere_mesh.radius = 0.2
		sphere_mesh.height = 0.4
		mesh_instance.mesh = sphere_mesh
		add_child(mesh_instance)
	
	Logger.debug("Projectile created", "Projectile")

func initialize(p_type: String, position: Vector3, direction: Vector3, p_owner: Node = null) -> void:
	projectile_type = p_type
	global_position = position
	_direction = direction.normalized()
	owner_node = p_owner
	
	# Load projectile data
	var projectile_data = ItemDatabase.get_projectile_data(projectile_type)
	
	if not projectile_data.empty():
		speed = projectile_data.get("speed", speed)
		damage = projectile_data.get("damage", damage)
		explosive = projectile_data.get("explosive", explosive)
		explosion_radius = projectile_data.get("explosion_radius", explosion_radius) if explosive else 0.0
	
	# Store type for pool manager
	set_meta("projectile_type", projectile_type)
	
	# Reset timer
	_time_alive = 0.0
	_initialized = true
	
	# Rotate to face direction
	look_at(global_position + _direction)
	
	Logger.debug("Projectile initialized: %s" % projectile_type, "Projectile")

func _process(delta: float) -> void:
	if not _initialized:
		return
	
	# Move in direction
	global_position += _direction * speed * delta
	
	# Check lifetime
	_time_alive += delta
	if _time_alive >= _lifetime:
		_destroy()

func _on_body_entered(body: Node3D) -> void:
	if not _initialized:
		return
	
	if body == owner_node:
		return  # Don't hit owner
	
	_handle_collision(body)

func _on_area_entered(area: Area3D) -> void:
	if not _initialized:
		return
	
	if area == owner_node:
		return  # Don't hit owner
	
	_handle_collision(area)

func _handle_collision(collider: Node3D) -> void:
	Logger.debug("Projectile hit: %s" % collider.name, "Projectile")
	
	# Apply damage
	if explosive:
		_explode()
	else:
		_apply_damage(collider)
	
	# Destroy projectile
	_destroy()

func _apply_damage(target: Node3D) -> void:
	var health_component = null
	
	# Try to find HealthComponent in the target
	if target.has_method("get_component"):
		health_component = target.get_component(HealthComponent)
	else:
		# Look for HealthComponent in children
		for child in target.get_children():
			if child is HealthComponent:
				health_component = child
				break
	
	if health_component:
		health_component.take_damage(damage)
		
		# Emit hit signal
		var hit_data = {
			"target": target,
			"projectile_type": projectile_type,
			"damage": damage,
			"position": global_position
		}
		SignalBus.emit_vehicle_hit(hit_data)
	
	# If target is a voxel/block
	if target.has_meta("voxel_type"):
		var voxel_type = target.get_meta("voxel_type")
		var grid_pos = target.get_meta("grid_position")
		
		if voxel_type and LocationManager.is_position_in_bounds(global_position):
			LocationManager.destroy_voxel(global_position)

func _explode() -> void:
	Logger.debug("Projectile exploding with radius: %f" % explosion_radius, "Projectile")
	
	# Get all bodies in explosion radius
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	var shape = SphereShape3D.new()
	shape.radius = explosion_radius
	query.shape = shape
	query.transform = global_transform
	query.collision_mask = 0xFFFFFFFF  # All layers
	
	var results = space_state.intersect_shape(query)
	
	for result in results:
		var collider = result.collider
		
		if collider == owner_node:
			continue  # Skip owner
		
		# Calculate distance-based damage
		var distance = global_position.distance_to(collider.global_position)
		var falloff = 1.0 - min(distance / explosion_radius, 1.0)
		var applied_damage = damage * falloff
		
		# Apply damage to the collider
		_apply_damage(collider)
	
	# Create explosion effect
	_create_explosion_effect()
	
	# Emit explosion signal
	var explosion_data = {
		"position": global_position,
		"radius": explosion_radius,
		"damage": damage
	}
	SignalBus.emit_explosion_occurred(explosion_data)

func _create_explosion_effect() -> void:
	# Create explosion particles
	var particles = GPUParticles3D.new()
	var particle_material = ParticleProcessMaterial.new()
	
	# Configure particle material for explosion
	particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	particle_material.emission_sphere_radius = 0.5
	particle_material.direction = Vector3(0, 1, 0)
	particle_material.spread = 180.0
	particle_material.gravity = Vector3(0, -0.5, 0)
	particle_material.initial_velocity_min = 3.0
	particle_material.initial_velocity_max = 5.0
	particle_material.scale_min = 0.5
	particle_material.scale_max = 1.0
	particle_material.color = Color(1.0, 0.7, 0.2, 0.8)
	
	particles.process_material = particle_material
	particles.amount = 32
	particles.lifetime = 1.0
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.local_coords = false
	
	# Add to scene at explosion position
	get_tree().root.add_child(particles)
	particles.global_position = global_position
	particles.emitting = true
	
	# Auto-remove when done
	var timer = Timer.new()
	timer.wait_time = 2.0
	timer.one_shot = true
	particles.add_child(timer)
	timer.timeout.connect(func(): particles.queue_free())
	timer.start()

func _destroy() -> void:
	_initialized = false
	
	# Return to pool instead of destroying
	var projectile_pool_manager = get_node_or_null("/root/ProjectilePoolManager")
	if projectile_pool_manager:
		call_deferred("_return_to_pool", projectile_pool_manager)
	else:
		queue_free()

func _return_to_pool(pool_manager: ProjectilePoolManager) -> void:
	pool_manager.return_projectile(self)
