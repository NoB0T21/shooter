extends PanelContainer

@export var Stamina : ProgressBar
@export var Health : ProgressBar
#@export var Ammo : Label
@export var MAX_STAMINA_TIMER: float = 5.0

signal ammo_update(current:int, reserved:int)

var ammos: int = 0:
	set(val):
		ammos= val
		ammo_update.emit(ammos, maxammos)

var maxammos: int = 0:
	set(val):
		maxammos = val
		ammo_update.emit(ammos,maxammos)
		
var _stamina: float
var _health: float
var _is_sliding: bool = false
var _is_damaging: bool = false
var stamina_timer: float = 0.0
var health_timer: float = 0.0
var cost: float = 0.0
var hcost: float = 0.0
var mag_cap : int = 0
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_stamina = 1.0
	stamina_timer= 0.0
	Stamina.value = _stamina
	
	_health = 1.0
	health_timer= 0.0
	Health.value = _health

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if _is_sliding and _stamina > 0:
		stamina_timer = 0.0
		_stamina -= delta*cost
		Stamina.value = _stamina
	if _is_damaging and _health > 0:
		health_timer = 0.0
		_health -= delta*hcost
		Health.value = _health
		
func _physics_process(delta: float) -> void:
	if _stamina < 1.0:
		stamina_timer += delta
	if stamina_timer >= MAX_STAMINA_TIMER:
		regenerateStamina()
	
	if _health < 1.0:
		health_timer += delta
	if health_timer >= MAX_STAMINA_TIMER:
		regenerateHealth()
	
func regenerateStamina() -> void:
	_stamina += 0.001
	Stamina.value = _stamina
	if Stamina.value == 1.0:
		stamina_timer = 0.0

func regenerateHealth() -> void:
	_health += 0.001
	Health.value = _health
	if Health.value == 1.0:
		health_timer = 0.0
