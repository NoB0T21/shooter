class_name  SprintPlayerState
extends PlayerMovementState

@export var SPEED: float = 14.0
@export var ACCLERATION: float = 0.1
@export var DECELERATION: float =  0.25
#@export var animation_tree: AnimationTree
#@export var sketchfab_scene_2 : Node3D
#@export var JUMP_SHAPECAST : ShapeCast3D 

func enter()-> void:
	if PlayerStats._stamina <= 0.0:
		if PLAYER.velocity.length() == 0.0:
			transition.emit("IdelPlayerState")
		else:
			transition.emit("WalkPlayerState")
	else:
		PlayerStats.cost = 0.02
	#animation_tree.set("parameters/Transition/transition_request", "walk")

func update(delta: float) -> void:
	PlayerStats._is_sliding = true
	if PlayerStats._stamina <= 0.0:
		if PLAYER.velocity.length() == 0.0:
			transition.emit("IdelPlayerState")
		else:
			transition.emit("WalkPlayerState")
	else:
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
		if Input.is_action_just_released("sprint") and PLAYER.is_on_floor():
			transition.emit("WalkPlayerState")
		if Input.is_action_just_pressed("slide") and PLAYER.is_on_floor():
			transition.emit("SlidePlayerState")
		if Input.is_action_just_pressed("jump") and PLAYER.is_on_floor():
			transition.emit("JumpPlayerState")
		if PLAYER.velocity.length() == 0.0:
			transition.emit("IdelPlayerState")
		
		#update_walk_locomotion()

#func update_walk_locomotion() -> void:
	#var input_dir :Vector2 =GlobalVariableScript.player.player_direction
	#animation_tree.set("parameters/Walk_Locomotion/blend_position", input_dir)
