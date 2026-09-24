class_name JumpPlayerState
extends PlayerMovementState

@export var SPEED: float = 5.0
@export var ACCLERATION: float = 0.1
@export var DECELERATION: float =  0.02
const JUMP_VELOCITY = 10
#@onready var animation_tree: AnimationTree = $"../../CollisionShape3D/AnimationTree"

func enter()-> void:
	if PlayerStats._stamina <= 0.0:
		transition.emit("IdelPlayerState")
	else:
		PLAYER.velocity.y = JUMP_VELOCITY
		PlayerStats.cost = 0.11
		#animation_tree.set("parameters/movement/transition_request", "jump")

func update(delta: float) -> void:
	PlayerStats._is_sliding = true
	if PlayerStats._stamina <= 0.0:
		if PLAYER.is_on_floor():
			transition.emit("IdelPlayerState")
	PLAYER.update_gravity(delta)
	PLAYER.update_velocity()
	
	if PLAYER.is_on_floor():
		transition.emit("IdelPlayerState")
