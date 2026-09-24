class_name ReloadPlayerState
extends PlayerMovementState

@export var SPEED: float = 10.0
@export var ACCLERATION: float = 0.1
@export var DECELERATION: float =  0.25

@export var MIN_RELOAD_SPEED: float = 2.5 # Speed threshold where reload ends
@export var MAX_RELOAD_TIME: float = 1.0 # Maximum time the reload can last
@export var weaponController : Node

var reload_timer: float = 0.0
var is_reloading: bool = false

func enter() -> void:
	if weaponController:
		# Connect to completion signal if not already connected
		if not weaponController.reload_finished.is_connected(_on_reload_finished):
			weaponController.reload_finished.connect(_on_reload_finished)
		weaponController.reload()

func exit() -> void:
	# Clean up signal connection when leaving the state
	if weaponController and weaponController.reload_finished.is_connected(_on_reload_finished):
		weaponController.reload_finished.disconnect(_on_reload_finished)

func update(delta: float) -> void:
	PLAYER.update_gravity(delta)
	PLAYER.update_input(SPEED, ACCLERATION, DECELERATION)
	PLAYER.update_velocity()
	
	# Interruptions (Canceling reload)
	if Input.is_action_just_pressed("jump") and PLAYER.is_on_floor():
		weaponController.cancel_reload()
		transition.emit("JumpPlayerState")
		return

func _on_reload_finished() -> void:
	transition.emit("IdelPlayerState")
