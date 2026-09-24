class_name  WalkPlayerState
extends PlayerMovementState

@export var SPEED: float = 10.0
@export var ACCLERATION: float = 0.1
@export var DECELERATION: float =  0.25
#@export var animation_tree: AnimationTree
#@export var sketchfab_scene_2 : Node3D
#@export var JUMP_SHAPECAST : ShapeCast3D 

#func enter()-> void:
	#animation_tree.set("parameters/Transition/transition_request", "walk")

func update(delta: float) -> void:
	PLAYER.update_gravity(delta)
	PLAYER.update_input(SPEED, ACCLERATION, DECELERATION)
	PLAYER.update_velocity()
	
	#if not PLAYER.is_on_floor():
		#if JUMP_SHAPECAST.is_colliding() == false:
			#transition.emit("FallPlayerState")
	#if Input.is_action_just_pressed("shoot"):
		#sketchfab_scene_2.shoot()
		#animation_tree.set("parameters/shot_play/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	if Input.is_action_just_pressed("reload") and PLAYER.is_on_floor():
		if  PlayerStats.maxammos > 0 or PlayerStats.ammos < PlayerStats.mag_cap:
			transition.emit("ReloadPlayerState")
	if Input.is_action_just_pressed("sprint") or Input.is_action_pressed("sprint") and PLAYER.is_on_floor():
		transition.emit("SprintPlayerState")
	if Input.is_action_just_pressed("jump") and PLAYER.is_on_floor():
		transition.emit("JumpPlayerState")
	if PLAYER.velocity.length() == 0.0:
		transition.emit("IdelPlayerState")
	
	#update_walk_locomotion()

#func update_walk_locomotion() -> void:
	#var input_dir :Vector2 =GlobalVariableScript.player.player_direction
	#animation_tree.set("parameters/Walk_Locomotion/blend_position", input_dir)
