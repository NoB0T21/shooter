class_name SlidePlayerState
extends PlayerMovementState

@export var SLIDE_SPEED: float = 19.0
@export var FRICTION: float = 8.0 # Higher values stop the slide faster
@export var MIN_SLIDE_SPEED: float = 2.5 # Speed threshold where slide ends
@export var MAX_SLIDE_TIME: float = 1.0 # Maximum time the slide can last
@export var animationTree: AnimationTree

var slide_timer: float = 0.0
var slide_direction: Vector3 = Vector3.ZERO

func enter() -> void:
	slide_timer = 0.
	if PlayerStats._stamina <= 0.0:
		_exit_slide()
	PlayerStats.cost = 0.13
	# 1. Convert the 2D input into a 3D direction relative to where the player is currently facing
	var input_vector := PLAYER.player_direction
	var move_dir: Vector3 = (PLAYER.global_transform.basis * Vector3(input_vector.x, 0.0, input_vector.y)).normalized()
	
	# 2. If moving forward or pressing keys, use that direction; otherwise default straight forward
	if move_dir == Vector3.ZERO:
		slide_direction = -PLAYER.global_transform.basis.z.normalized()
	else:
		slide_direction = move_dir

	# 3. Apply the burst in that global direction
	PLAYER.velocity.x = slide_direction.x * SLIDE_SPEED
	PLAYER.velocity.z = slide_direction.z * SLIDE_SPEED

	if animationTree:
		animationTree.set("parameters/Movement/transition_request", "Slide")
		animationTree.set("parameters/SlideTimeScale/scale", 1.0)
		animationTree.set("parameters/OneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func update(delta: float) -> void:
	PlayerStats._is_sliding = true
	if PlayerStats._stamina <= 0.0:
		_exit_slide()
	slide_timer += delta
	PLAYER.update_gravity(delta)

	# Apply friction to gradually bring the player to a halt
	PLAYER.velocity.x = move_toward(PLAYER.velocity.x, 0.0, FRICTION * delta)
	PLAYER.velocity.z = move_toward(PLAYER.velocity.z, 0.0, FRICTION * delta)
	
	PLAYER.update_velocity()

	# If player falls off an edge or ledge during a slide
	#if not PLAYER.is_on_floor():
		#transition.emit("FallPlayerState")
		#return

	# Allow early jump cancel out of slide
	if Input.is_action_just_pressed("jump"):
		transition.emit("JumpPlayerState")
		return

	# End slide when velocity drops below minimum threshold OR duration expires
	var horizontal_speed := Vector2(PLAYER.velocity.x, PLAYER.velocity.z).length()
	if horizontal_speed < MIN_SLIDE_SPEED or slide_timer >= MAX_SLIDE_TIME:
		_exit_slide()

func _exit_slide() -> void:
	# Check whether to transition to walking/sprinting or idle based on input
	var input_vector := Vector2(PLAYER.player_direction.x, PLAYER.player_direction.y)
	if animationTree:
		animationTree.set("parameters/Movement/transition_request", "Slide")
		animationTree.set("parameters/SlideTimeScale/scale", -1.0)
		animationTree.set("parameters/OneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	PlayerStats._is_sliding = false
	PlayerStats.cost = 0.0
	if input_vector != Vector2.ZERO:
		transition.emit("WalkPlayerState")
	else:
		transition.emit("IdelPlayerState")
