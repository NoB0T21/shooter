class_name SwarmManager
extends Node3D

@export var player: CharacterBody3D
@export var zombie_scene: PackedScene

const ATTACK_DISTANCE: float = 3.6
const SPRINT_SPEED: float = 7.0
const CLIMB_SPEED: float = 5.0
const GRAVITY: float = 20.0
const ZOMBIE_HALF_HEIGHT: float = 1.0

# Separation & Crowd Stacking parameters
const ZOMBIE_RADIUS: float = 0.65       # Minimum space between zombies
const SEPARATION_FORCE: float = 12.0     # How strongly they push away from each other

var zombies: Array[Node] = []
var nav_map_rid: RID

var path_update_timer: float = 0.0
const PATH_INTERVAL: float = 0.25

var ray_stagger_index: int = 0

func _ready() -> void:
	nav_map_rid = get_world_3d().get_navigation_map()

func _physics_process(delta: float) -> void:
	if not player:
		return

	zombies = get_tree().get_nodes_in_group("swarm_zombies")
	if zombies.is_empty():
		return

	path_update_timer -= delta
	var should_refresh_paths: bool = (path_update_timer <= 0.0)
	if should_refresh_paths:
		path_update_timer = PATH_INTERVAL

	var player_pos: Vector3 = player.global_position
	var total_count: int = zombies.size()

	for i in range(total_count):
		var z: ZombieEntity = zombies[i] as ZombieEntity
		if not is_instance_valid(z):
			continue

		# --- A. Navigation Refresh ---
		if should_refresh_paths:
			var path: PackedVector3Array = NavigationServer3D.map_get_path(
				nav_map_rid,
				z.global_position,
				player_pos,
				true
			)
			if path.size() > 1:
				z.target_point = path[1]
			else:
				z.target_point = player_pos

		# --- B. Separation Force (Push away from neighbors) ---
		var separation: Vector3 = _compute_separation(z, i, total_count)

		# --- C. Staggered Raycast / Pyramid Probing ---
		if i % 3 == ray_stagger_index:
			_check_climb_conditions(z, player_pos)

		# --- D. Movement Application ---
		_apply_zombie_motion(z, player_pos, separation, delta)

	ray_stagger_index = (ray_stagger_index + 1) % 3

# Fast separation loop to prevent blending into each other
func _compute_separation(z: ZombieEntity, current_idx: int, total_count: int) -> Vector3:
	var push: Vector3 = Vector3.ZERO
	var z_pos: Vector3 = z.global_position
	var min_dist_sq: float = ZOMBIE_RADIUS * ZOMBIE_RADIUS

	# Check against nearby zombies (limit window to 15 neighbors for CPU performance)
	var check_start: int = maxi(0, current_idx - 8)
	var check_end: int = mini(total_count, current_idx + 8)

	for j in range(check_start, check_end):
		if j == current_idx:
			continue
		var other: ZombieEntity = zombies[j] as ZombieEntity
		if not is_instance_valid(other):
			continue

		var diff: Vector3 = z_pos - other.global_position
		diff.y = 0.0 # Only repel horizontally
		var dist_sq: float = diff.length_squared()

		# If overlapping or closer than minimum radius
		if dist_sq < min_dist_sq and dist_sq > 0.001:
			var dist: float = sqrt(dist_sq)
			var strength: float = (ZOMBIE_RADIUS - dist) / ZOMBIE_RADIUS
			push += (diff / dist) * strength

	return push

func _check_climb_conditions(z: ZombieEntity, player_pos: Vector3) -> void:
	var dist_to_player: float = z.global_position.distance_to(player_pos)

	# 1. Stop and attack if within melee range
	if dist_to_player <= ATTACK_DISTANCE:
		z.current_state = ZombieEntity.State.ATTACK
		PlayerStats.hcost = 0.2
		PlayerStats._is_damaging = true
		return
	if dist_to_player > ATTACK_DISTANCE:
		PlayerStats.hcost = 0.0
		PlayerStats._is_damaging = false
	# Only check climbing if the player is elevated above the zombie
	var player_above: bool = (player_pos.y - z.global_position.y) > 1.5

	# 2. Wall Climbing
	if z.forward_ray:
		z.forward_ray.force_raycast_update()
		if z.forward_ray.is_colliding() and player_above:
			var wall_collider: Object = z.forward_ray.get_collider()
			if wall_collider and wall_collider.is_in_group("climbable_wall"):
				z.current_state = ZombieEntity.State.CLIMB_WALL
				return

	# 3. Zombie-only Pyramid Climbing
	if z.crowd_ray:
		z.crowd_ray.force_raycast_update()
		if z.crowd_ray.is_colliding() and player_above:
			var crowd_hit: Object = z.crowd_ray.get_collider()
			
			# Ensure the hit object is strictly another zombie and NOT the player
			var is_other_zombie: bool = (
				crowd_hit and 
				(crowd_hit.is_in_group("swarm_zombies") or crowd_hit.get_parent().is_in_group("swarm_zombies")) and
				not crowd_hit.is_in_group("player") and
				crowd_hit != player
			)
			
			if is_other_zombie:
				z.current_state = ZombieEntity.State.CLIMB_PYRAMID
				return

	# Default back to running if out of range and not climbing
	if z.current_state != ZombieEntity.State.RUN:
		z.current_state = ZombieEntity.State.RUN
	
	# Wall check
	if z.forward_ray:
		z.forward_ray.force_raycast_update()
		if z.forward_ray.is_colliding() and player_above:
			var collider: Object = z.forward_ray.get_collider()
			if collider and collider.is_in_group("climbable_wall"):
				z.current_state = ZombieEntity.State.CLIMB_WALL
				return

	# Crowd / Pyramid check
	if z.crowd_ray:
		z.crowd_ray.force_raycast_update()
		if z.crowd_ray.is_colliding() and player_above:
			var crowd_hit: Object = z.crowd_ray.get_collider()
			if crowd_hit and (crowd_hit.is_in_group("swarm_zombies") or crowd_hit.get_parent().is_in_group("swarm_zombies")):
				z.current_state = ZombieEntity.State.CLIMB_PYRAMID
				return

	if z.current_state != ZombieEntity.State.RUN:
		z.current_state = ZombieEntity.State.RUN

func _apply_zombie_motion(z: ZombieEntity, player_pos: Vector3, separation: Vector3, delta: float) -> void:
	match z.current_state:
		ZombieEntity.State.ATTACK:
			# Stop horizontal movement completely
			z.velocity_vector.x = 0.0
			z.velocity_vector.z = 0.0

			# Face the player horizontally while attacking
			var look_dir: Vector3 = (player_pos - z.global_position)
			look_dir.y = 0.0
			if look_dir.length_squared() > 0.01:
				var look_target: Vector3 = z.global_position + look_dir.normalized()
				z.look_at(Vector3(look_target.x, z.global_position.y, look_target.z), Vector3.UP)

			# Apply gravity so they stay anchored to the floor while swinging
			z.velocity_vector.y -= GRAVITY * delta

		ZombieEntity.State.RUN:
			var to_target: Vector3 = z.target_point - z.global_position
			to_target.y = 0.0
			
			if to_target.length_squared() < 0.25:
				to_target = player_pos - z.global_position
				to_target.y = 0.0

			if to_target.length_squared() > 0.04:
				var move_dir: Vector3 = to_target.normalized()
				var final_dir: Vector3 = (move_dir + separation * (SEPARATION_FORCE / SPRINT_SPEED)).normalized()
				z.velocity_vector.x = final_dir.x * SPRINT_SPEED
				z.velocity_vector.z = final_dir.z * SPRINT_SPEED
				
				var look_target: Vector3 = z.global_position + move_dir
				z.look_at(Vector3(look_target.x, z.global_position.y, look_target.z), Vector3.UP)
			else:
				z.velocity_vector.x = separation.x * SEPARATION_FORCE
				z.velocity_vector.z = separation.z * SEPARATION_FORCE

			z.velocity_vector.y -= GRAVITY * delta

		ZombieEntity.State.CLIMB_WALL:
			z.velocity_vector.y = CLIMB_SPEED
			if z.forward_ray and z.forward_ray.is_colliding():
				var normal: Vector3 = z.forward_ray.get_collision_normal()
				z.velocity_vector.x = -normal.x * 1.5
				z.velocity_vector.z = -normal.z * 1.5

		ZombieEntity.State.CLIMB_PYRAMID:
			var to_player: Vector3 = (player_pos - z.global_position)
			var h_dir: Vector3 = Vector3(to_player.x, 0.0, to_player.z).normalized()
			z.velocity_vector.x = h_dir.x * (SPRINT_SPEED * 0.6)
			z.velocity_vector.z = h_dir.z * (SPRINT_SPEED * 0.6)
			z.velocity_vector.y = CLIMB_SPEED

	# 1. Apply translation
	z.global_position += z.velocity_vector * delta

	# 2. Ground Snapping (Run and Attack states stay snapped to the floor)
	if z.current_state == ZombieEntity.State.RUN or z.current_state == ZombieEntity.State.ATTACK:
		var space_state := get_world_3d().direct_space_state
		var ray_start: Vector3 = z.global_position + Vector3(0.0, ZOMBIE_HALF_HEIGHT + 0.5, 0.0)
		var ray_end: Vector3 = z.global_position + Vector3(0.0, -ZOMBIE_HALF_HEIGHT - 0.5, 0.0)
		
		var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end)
		query.collision_mask = 1
		query.collide_with_areas = false
		query.collide_with_bodies = true
		
		var hit := space_state.intersect_ray(query)
		if hit:
			var floor_y: float = hit.position.y
			if z.global_position.y <= floor_y + ZOMBIE_HALF_HEIGHT + 0.05:
				z.global_position.y = floor_y + ZOMBIE_HALF_HEIGHT
				z.velocity_vector.y = 0.0
	match z.current_state:
		ZombieEntity.State.RUN:
			var to_target: Vector3 = z.target_point - z.global_position
			to_target.y = 0.0
			
			if to_target.length_squared() < 0.25:
				to_target = player_pos - z.global_position
				to_target.y = 0.0

			if to_target.length_squared() > 0.04:
				var move_dir: Vector3 = to_target.normalized()
				
				# Combine path navigation with crowd repulsion
				var final_dir: Vector3 = (move_dir + separation * (SEPARATION_FORCE / SPRINT_SPEED)).normalized()
				z.velocity_vector.x = final_dir.x * SPRINT_SPEED
				z.velocity_vector.z = final_dir.z * SPRINT_SPEED
				
				var look_target: Vector3 = z.global_position + move_dir
				z.look_at(Vector3(look_target.x, z.global_position.y, look_target.z), Vector3.UP)
			else:
				z.velocity_vector.x = separation.x * SEPARATION_FORCE
				z.velocity_vector.z = separation.z * SEPARATION_FORCE

			# Gravity
			z.velocity_vector.y -= GRAVITY * delta

		ZombieEntity.State.CLIMB_WALL:
			z.velocity_vector.y = CLIMB_SPEED
			if z.forward_ray and z.forward_ray.is_colliding():
				var normal: Vector3 = z.forward_ray.get_collision_normal()
				z.velocity_vector.x = -normal.x * 1.5
				z.velocity_vector.z = -normal.z * 1.5

		ZombieEntity.State.CLIMB_PYRAMID:
			var to_player: Vector3 = (player_pos - z.global_position)
			var h_dir: Vector3 = Vector3(to_player.x, 0.0, to_player.z).normalized()
			# Push diagonally upward over the shoulders of other zombies
			z.velocity_vector.x = h_dir.x * (SPRINT_SPEED * 0.6)
			z.velocity_vector.z = h_dir.z * (SPRINT_SPEED * 0.6)
			z.velocity_vector.y = CLIMB_SPEED

	# 1. Apply translation
	z.global_position += z.velocity_vector * delta

	# 2. Ground Snapping (Only in RUN state; in CLIMB states, let them rise)
	if z.current_state == ZombieEntity.State.RUN:
		var space_state := get_world_3d().direct_space_state
		var ray_start: Vector3 = z.global_position + Vector3(0.0, ZOMBIE_HALF_HEIGHT + 0.5, 0.0)
		var ray_end: Vector3 = z.global_position + Vector3(0.0, -ZOMBIE_HALF_HEIGHT - 0.5, 0.0)
		
		var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end)
		query.collision_mask = 1
		query.collide_with_areas = false
		query.collide_with_bodies = true
		
		var hit := space_state.intersect_ray(query)
		if hit:
			var floor_y: float = hit.position.y
			if z.global_position.y <= floor_y + ZOMBIE_HALF_HEIGHT + 0.05:
				z.global_position.y = floor_y + ZOMBIE_HALF_HEIGHT
				z.velocity_vector.y = 0.0

func spawn_wave(count: int, spawn_area_origin: Vector3) -> void:
	if not zombie_scene:
		push_error("SwarmManager: zombie_scene is not assigned in the Inspector!")
		return
	
	for i in range(count):
		var zombie_inst := zombie_scene.instantiate() as ZombieEntity
		zombie_inst.name = "Zombie_%d" % [Time.get_ticks_msec() + i]
		get_tree().current_scene.add_child(zombie_inst)
		var offset := Vector3(randf_range(-4, 4), 0.5, randf_range(-4, 4))
		zombie_inst.global_position = spawn_area_origin + offset
