extends Node3D

@export var SPEED : float = 40.0
@export var TTL : float = 3.0
@export var DAMAGE : float = 0.15

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var ray: RayCast3D = $RayCast3D
@onready var particle: GPUParticles3D = $GPUParticles3D

var direction := Vector3.ZERO
var has_hit: bool = false

func _ready() -> void:
	get_tree().create_timer(TTL).timeout.connect(queue_free)

func _process(delta: float) -> void:
	if has_hit:
		return
		
	global_position += direction * SPEED * delta
	ray.target_position = Vector3(0, 0, -SPEED * 0.05)
	if ray.is_colliding():
		var collider := ray.get_collider()
		
		# Check if the collider is a zombie (via class type OR group)
		if collider is ZombieEntity or collider.is_in_group("swarm_zombies"):
			var zombie: ZombieEntity = collider as ZombieEntity
			if zombie.has_method("take_damage"):
				zombie.take_damage(DAMAGE)
		has_hit = true
		mesh.visible = false
		if particle:
			particle.emitting = true
		await get_tree().create_timer(1.0).timeout
		queue_free()
