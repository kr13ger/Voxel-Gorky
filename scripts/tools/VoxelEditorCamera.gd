# scripts/tools/VoxelEditorCamera.gd
class_name VoxelEditorCamera
extends Node

var camera_node: Camera3D
var orbit_speed = 0.005
var camera_distance = 15.0
var camera_height = 10.0
var orbit_angle = 0.0
var is_orbiting = false
var orbit_center = Vector3.ZERO

func setup_camera(camera: Camera3D):
	camera_node = camera
	update_camera_position()

func _input(event):
	# Handle camera controls
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			is_orbiting = event.pressed
		
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_distance -= 1.0
			camera_distance = max(5.0, camera_distance)
			update_camera_position()
		
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance += 1.0
			camera_distance = min(50.0, camera_distance)
			update_camera_position()
	
	if event is InputEventMouseMotion:
		if is_orbiting:
			orbit_angle += event.relative.x * orbit_speed
			camera_height += event.relative.y * orbit_speed * 5.0
			camera_height = clamp(camera_height, 5.0, 30.0)
			update_camera_position()

func update_camera_position():
	var x = cos(orbit_angle) * camera_distance
	var z = sin(orbit_angle) * camera_distance
	camera_node.position = Vector3(x, camera_height, z) + orbit_center
	camera_node.look_at(orbit_center)

func set_orbit_center(center: Vector3):
	orbit_center = center
	update_camera_position()

func auto_rotate(delta: float):
	orbit_angle += orbit_speed * delta * 20
	update_camera_position()
