class_name  IdelPlayerState
extends PlayerMovementState

@export var SPEED: float = 4.0
@export var ACCLERATION: float = 0.1
@export var DECELERATION: float =  0.25
@export var animationTree : AnimationTree

func enter()-> void:
	animationTree.set("parameters/Movement/transition_request", "idle")
	
func update(delta: float) -> void:
	PLAYER.update_gravity(delta)
	PLAYER.update_input(SPEED, ACCLERATION, DECELERATION)
	PLAYER.update_velocity()
	
	#if Input.is_action_just_pressed("shoot"):
		#sketchfab_scene_2.shoot()
		#animation_tree.set("parameters/shot_play/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		
	#if Input.is_action_just_pressed("crouch") and PLAYER.is_on_floor():
		#transition.emit("crouchPlayerState")
	if PLAYER.velocity.length() > 0.0 and PLAYER.is_on_floor():
		transition.emit("WalkPlayerState")
	if Input.is_action_just_pressed("jump") and PLAYER.is_on_floor():
		transition.emit("JumpPlayerState")
	if Input.is_action_just_pressed("reload") and PLAYER.is_on_floor():
		if  PlayerStats.maxammos > 0 or PlayerStats.ammos < PlayerStats.mag_cap:
			transition.emit("ReloadPlayerState")
