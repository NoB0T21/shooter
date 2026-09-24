class_name ZombieEntity
extends Area3D

enum State {
	RUN,
	ATTACK,
	CLIMB_WALL,
	CLIMB_PYRAMID,
	DAMAGE
}

var current_state: ZombieEntity.State = State.RUN
var target_point: Vector3 = Vector3.ZERO
var velocity_vector: Vector3 = Vector3.ZERO
var health: float = 1.0

@onready var forward_ray: RayCast3D = $ForwardRay
@onready var crowd_ray: RayCast3D = $CrowdRay
@onready var down_ray: RayCast3D = $DownRay
@onready var health_bar: ProgressBar = $Sprite3D/SubViewport/Health

func _ready() -> void:
	add_to_group("swarm_zombies")
	health_bar.value = health
	if forward_ray:
		forward_ray.enabled = false
	if crowd_ray:
		crowd_ray.enabled = false

func take_damage(amount: float) -> void:
	health -= amount
	health_bar.value = health
	if health <= 0.0:
		queue_free()
