extends State
class_name VehicleDestroyedState

func enter() -> void:
	if owner_node is Vehicle:
		var physics_component = owner_node.get_component(VehiclePhysicsComponent)
		if physics_component:
			physics_component.set_movement_input(Vector2.ZERO)
			
		# Disable input
		owner_node.set_process_input(false)
		
		# Play destruction effects
		_play_destruction_effects()
	
	Logger.debug("Vehicle entered Destroyed state", "VehicleDestroyedState")

func _play_destruction_effects() -> void:
	# Add smoke particles or fire effects
	var particles = GPUParticles3D.new()
	var particle_material = ParticleProcessMaterial.new()
	
	# Configure particle material for smoke
	particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	particle_material.emission_box_extents = Vector3(1, 0.5, 1)
	particle_material.direction = Vector3(0, 1, 0)
	particle_material.spread = 15.0
	particle_material.gravity = Vector3(0, -0.5, 0)
	particle_material.initial_velocity_min = 1.0
	particle_material.initial_velocity_max = 2.0
	particle_material.color = Color(0.3, 0.3, 0.3, 0.7)
	
	particles.process_material = particle_material
	particles.amount = 20
	particles.lifetime = 3.0
	particles.explosiveness = 0.1
	particles.randomness = 0.5
	particles.local_coords = false
	
	# Add to vehicle
	owner_node.add_child(particles)
	particles.emitting = true
	
	# Change material of the vehicle to look damaged
	if owner_node is Vehicle:
		for mesh_instance in owner_node.get_children():
			if mesh_instance is MeshInstance3D:
				var material = mesh_instance.get_surface_override_material(0)
				if material:
					var new_material = material.duplicate()
					new_material.albedo_color = Color(0.3, 0.3, 0.3)
					mesh_instance.set_surface_override_material(0, new_material)
