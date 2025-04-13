extends Control

@onready var ammo_counter = $AmmoCounter
@onready var health_bar = $HealthBar

func _ready() -> void:
	# Setup UI elements
	_setup_ammo_counter()
	_setup_health_bar()
	
	Logger.debug("UI initialized", "UI")

func _setup_ammo_counter() -> void:
	if not ammo_counter:
		ammo_counter = Label.new()
		ammo_counter.name = "AmmoCounter"
		add_child(ammo_counter)
	
	ammo_counter.text = "Ammo: 0 / 0"
	ammo_counter.position = Vector2(20, 20)
	ammo_counter.add_theme_color_override("font_color", Color(1, 1, 1))
	ammo_counter.add_theme_font_size_override("font_size", 20)

func _setup_health_bar() -> void:
	if not health_bar:
		health_bar = ProgressBar.new()
		health_bar.name = "HealthBar"
		add_child(health_bar)
	
	health_bar.min_value = 0
	health_bar.max_value = 100
	health_bar.value = 100
	health_bar.size = Vector2(200, 20)
	health_bar.position = Vector2(20, 50)
	
	# Style the progress bar
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.8, 0.2, 0.2)
	style_box.corner_radius_top_left = 5
	style_box.corner_radius_top_right = 5
	style_box.corner_radius_bottom_left = 5
	style_box.corner_radius_bottom_right = 5
	
	health_bar.add_theme_stylebox_override("fill", style_box)
