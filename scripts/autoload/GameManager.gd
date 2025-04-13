extends Node

enum GameState {
	INITIALIZING,
	RUNNING,
	PAUSED,
	GAME_OVER
}

var current_state: int = GameState.INITIALIZING
var _player_vehicle: Node3D = null

func _ready() -> void:
	Logger.info("Game Manager initialized", "GameManager")
	current_state = GameState.RUNNING

func _process(delta: float) -> void:
	match current_state:
		GameState.INITIALIZING:
			pass
		GameState.RUNNING:
			pass
		GameState.PAUSED:
			pass
		GameState.GAME_OVER:
			pass

func set_player_vehicle(vehicle: Node3D) -> void:
	_player_vehicle = vehicle
	Logger.info("Player vehicle set", "GameManager")
	DependencyContainer.register("player_vehicle", vehicle)

func get_player_vehicle() -> Node3D:
	return _player_vehicle

func pause_game() -> void:
	if current_state == GameState.RUNNING:
		current_state = GameState.PAUSED
		get_tree().paused = true
		SignalBus.game_paused.emit()
		Logger.info("Game paused", "GameManager")

func resume_game() -> void:
	if current_state == GameState.PAUSED:
		current_state = GameState.RUNNING
		get_tree().paused = false
		SignalBus.game_resumed.emit()
		Logger.info("Game resumed", "GameManager")

func toggle_pause() -> void:
	if current_state == GameState.RUNNING:
		pause_game()
	elif current_state == GameState.PAUSED:
		resume_game()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()
