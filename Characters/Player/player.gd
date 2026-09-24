class_name Player
extends CharacterBody3D

@export var MOUSE_SENSITUIVE:float = 0.5
@export var TILT_LOWER_LIMIT := deg_to_rad(-90.0)
@export var TILT_UPPER_LIMIT := deg_to_rad(90.0)
@export var CAMERA :Node3D
@export var weaponController : Node
@onready var swarm_manager: SwarmManager = %SwarmManager

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

var _mouse_rotation :Vector3
var _rotation_input :float
var _tilt_input :float
var _player_rotation :Vector3
var _camera_rotation :Vector3
var player_direction : Vector2
var player_stamina : float = 1.0
func _ready() -> void:
	GlobalVariableScript.player = self
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("exit"):
		get_tree().quit()
	if event.is_action_pressed("spawn"):
		swarm_manager.spawn_wave(3, Vector3(0, 2, -10))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_rotation_input = -event.relative.x * MOUSE_SENSITUIVE
		_tilt_input = -event.relative.y * MOUSE_SENSITUIVE

func _update_camera(delta: float) -> void:
	_mouse_rotation.x += _tilt_input * delta
	_mouse_rotation.x = clamp(_mouse_rotation.x, TILT_LOWER_LIMIT, TILT_UPPER_LIMIT)
	_mouse_rotation.y += _rotation_input * delta
	
	_player_rotation = Vector3(0.0, _mouse_rotation.y, 0.0)
	_camera_rotation = Vector3(_mouse_rotation.x, 0.0, 0.0)
	
	
	CAMERA.transform.basis = Basis.from_euler(_camera_rotation)
	CAMERA.rotation.z = 0.0
	#if _mouse_rotation.x != 0.0:
		#CAMERA.position.y = head_placeholder.position.y - 1.0
	
	transform.basis = Basis.from_euler(_player_rotation)
	#update_pitch_animation()
	
	_rotation_input = 0.0
	_tilt_input = 0.0

func _physics_process(delta: float) -> void:
	_update_camera(delta)
	if Input.is_action_pressed("shoot"):
		weaponController.play_animation("Fire")
	if DebugPanel.visible:
		var fps := "%.2f" % Engine.get_frames_per_second()
		DebugPanel.add_debug_property("FPS", fps)
		var speed := "%.2f" % velocity.length()
		DebugPanel.add_debug_property("speed", speed)

func update_gravity(delta: float) -> void:
	velocity.y += get_gravity().y * delta

func update_input(speed: float, accleration: float, deceleration:float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_froward", "move_backward")
	player_direction = input_dir
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = lerp(velocity.x, direction.x * speed, accleration)
		velocity.z = lerp(velocity.z, direction.z * speed, accleration)
	else:
		velocity.x = move_toward(velocity.x, 0, deceleration)
		velocity.z = move_toward(velocity.z, 0, deceleration)

#func update_pitch_animation() -> void:
	#var normalized_blend: float = remap(_mouse_rotation.x, TILT_LOWER_LIMIT, TILT_UPPER_LIMIT, -1.0, 1.0)
	#anim_tree.set(BLEND_PATH, normalized_blend)

func update_velocity() -> void:
	move_and_slide()
