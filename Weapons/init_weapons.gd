@tool
class_name WeaponController
extends Node

@export var WEAPON_TYPE : weapons:
	set(value):
		WEAPON_TYPE = value
		if Engine.is_editor_hint():
			load_weapon()

@export var weapon_model_parent: Node3D

#@onready var  fire_rate: Timer = $"../FireTimer"
var current_weapoon_modle: Node3D
var current_anim_tree: AnimationTree
var internal_anim_player: AnimationPlayer
var muzzle : Node3D 
var bullet : Node3D

var current_ammo: int = 0
var total_ammo: int = 0
var can_shoot: bool = true

signal reload_finished
var is_reloading: bool = false
var reload_tween: Tween

func _ready() -> void:
	if WEAPON_TYPE:
		load_weapon()

func load_weapon() -> void:
	if current_weapoon_modle:
		current_weapoon_modle.queue_free()
		current_anim_tree = null
		internal_anim_player = null
		
	if WEAPON_TYPE and WEAPON_TYPE.modle:
		current_weapoon_modle = WEAPON_TYPE.modle.instantiate()
		weapon_model_parent.add_child(current_weapoon_modle)
		current_weapoon_modle.position = WEAPON_TYPE.position
		current_weapoon_modle.rotation_degrees = WEAPON_TYPE.rotation
		current_weapoon_modle.scale = WEAPON_TYPE.scale
		
		# Grab the tree and its player
		current_anim_tree = current_weapoon_modle.find_child("AnimationTree", true, false) as AnimationTree
		if current_anim_tree and current_anim_tree.anim_player:
			internal_anim_player = current_anim_tree.get_node_or_null(current_anim_tree.anim_player) as AnimationPlayer
		
		# Fallback search if path wasn't linked properly
		if not internal_anim_player:
			internal_anim_player = current_weapoon_modle.find_child("AnimationPlayer", true, false) as AnimationPlayer
		
		current_ammo = WEAPON_TYPE.max_ammo
		muzzle = current_weapoon_modle.find_child("Muzzle", true, false) as Node3D
		#muzzle.target_position.y = -1*WEAPON_TYPE.range
		total_ammo = WEAPON_TYPE.total_ammo
		PlayerStats.ammos = current_ammo
		PlayerStats.mag_cap = WEAPON_TYPE.max_ammo
		PlayerStats.maxammos = total_ammo

func play_animation(anim_name: StringName) -> void:
	# 1. Strict guard to prevent duplicate firing
	if not can_shoot or is_reloading or current_ammo <= 0:
		return
	
	# Lock shooting immediately
	can_shoot = false
	current_ammo -= 1
	PlayerStats.ammos = current_ammo
	
	# Play animation
	if current_anim_tree:
		current_anim_tree.set("parameters/Transition/transition_request", anim_name)
		current_anim_tree.set("parameters/OneShot_" + anim_name + "/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	
	# 2. Camera Raycast to find the exact target point
	var camera: Camera3D = weapon_model_parent as Camera3D
	var max_range: float = WEAPON_TYPE.range if "range" in WEAPON_TYPE else 1000.0
	var forward_dir: Vector3 = -camera.global_basis.z
	
	var from_pos: Vector3 = camera.global_position
	var to_pos: Vector3 = from_pos + (forward_dir * max_range)
	
	var space_state := camera.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from_pos, to_pos)
	query.collide_with_areas = true  # Must be true to hit Area3D zombies
	query.collide_with_bodies = true
	# Exclude player collision body so the ray doesn't hit yourself
	var player_body := camera.get_parent() as CollisionObject3D
	if player_body:
		query.exclude = [player_body]
		
	var hit := space_state.intersect_ray(query)
	var target_point: Vector3 = hit.position if hit else to_pos
	
	# 3. Calculate spawn position and prevent backward shooting on close targets
	var spawn_pos: Vector3 = muzzle.global_position if muzzle else camera.global_position
	var forward_dist: float = (target_point - spawn_pos).dot(forward_dir)
	var min_forward_dist: float = 1.5
	
	if forward_dist < min_forward_dist:
		target_point = spawn_pos + (forward_dir * min_forward_dist)

	# 4. Instantiate and configure ONLY ONE bullet
	var new_bullet := WEAPON_TYPE.Bullet.instantiate() as Node3D
	get_tree().current_scene.add_child(new_bullet)
	new_bullet.global_position = spawn_pos
	new_bullet.direction = (target_point - spawn_pos).normalized()
	
	if new_bullet.global_position != target_point:
		new_bullet.look_at(target_point, Vector3.UP)
	
	# 5. Cooldown before allowing the next shot
	await get_tree().create_timer(WEAPON_TYPE.fire_rate).timeout
	can_shoot = true
	if not can_shoot or is_reloading or current_ammo <= 0:
		return
	
	current_ammo -= 1
	PlayerStats.ammos = current_ammo
	can_shoot = false
	
	if current_anim_tree:
		current_anim_tree.set("parameters/Transition/transition_request", anim_name)
		current_anim_tree.set("parameters/OneShot_" + anim_name + "/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		
	#await fire_rate.start(WEAPON_TYPE.fire_rate)
	await get_tree().create_timer(WEAPON_TYPE.fire_rate).timeout
	bullet = WEAPON_TYPE.Bullet.instantiate()
	bullet.position = muzzle.global_position
	bullet.transform.basis = muzzle.global_transform.basis
	var dir:Vector3 = -weapon_model_parent.global_basis.z
	bullet.direction = (muzzle.global_position + dir.normalized() * WEAPON_TYPE.range).normalized()
	get_tree().current_scene.add_child(bullet)
	can_shoot = true

func reload() -> void:
	if is_reloading or current_ammo == WEAPON_TYPE.max_ammo or total_ammo <= 0:
		return
		
	is_reloading = true
	
	# Determine duration: read from the actual animation, otherwise fallback to resource
	var duration: float = WEAPON_TYPE.reload_time if "reload_time" in WEAPON_TYPE else 1.5
	if internal_anim_player and internal_anim_player.has_animation("Reload"):
		duration = internal_anim_player.get_animation("Reload").length
	
	if current_anim_tree:
		current_anim_tree.set("parameters/Transition/transition_request", "Reload")
		current_anim_tree.set("parameters/OneShot_Reload/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	
	if reload_tween and reload_tween.is_valid():
		reload_tween.kill()
	
	reload_tween = create_tween()
	reload_tween.tween_interval(duration)
	reload_tween.tween_callback(
		func() -> void:
			var need_ammo:int = WEAPON_TYPE.max_ammo - current_ammo
			var  ammo_to_add:int = mini(need_ammo, total_ammo)
			total_ammo -= ammo_to_add
			current_ammo += ammo_to_add
			PlayerStats.ammos = current_ammo
			PlayerStats.maxammos = total_ammo
			is_reloading = false
			reload_finished.emit()
	)

func cancel_reload() -> void:
	if not is_reloading:
		return

	if reload_tween and reload_tween.is_valid():
		reload_tween.kill()
		reload_tween = null
	
	is_reloading = false
	can_shoot = true

	if current_anim_tree:
		current_anim_tree.set("parameters/OneShot_Reload/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
		current_anim_tree.set("parameters/Transition/transition_request", "Idle")
